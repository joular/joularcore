--
--  Copyright (c) 2026, Adel Noureddine.
--  All rights reserved. This program and the accompanying materials
--  are made available under the terms of the
--  GNU Lesser General Public License v3.0 only (LGPL-3.0-only)
--  which accompanies this distribution, and is available at:
--  https://www.gnu.org/licenses/lgpl-3.0.en.html
--
--  Author : Adel Noureddine
--

with Ada.Real_Time; use Ada.Real_Time;

with Interfaces.C; use Interfaces.C;

with GNAT.Expect; use GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.Regpat; use GNAT.Regpat;

with System;

package body Joular_Core.Powermetrics is

    -- The macOS tool reporting the power of the chip, given by its full path so that PATH cannot point at another program
    Tool : constant String := "/usr/bin/powermetrics";

    -- Enough for one whole sample; older output is discarded
    Output_Buffer_Size : constant := 8192;

    -- "take an immediate sample": each reading asks powermetrics for one, instead of it sampling on its own
    SIGINFO : constant := 29;

    -- powermetrics still samples on its own this often, in milliseconds: that write is what ends an orphaned one (SIGPIPE) once its reader is gone
    Own_Interval : constant String := "600000";

    -- How long a reading waits for the sample it asked for, in milliseconds (powermetrics answers within a few)
    Sample_Timeout : constant := 1000;

    -- A request made before powermetrics is ready is dropped, so Start asks again this often, in milliseconds
    Ask_Again : constant := 250;
    First_Sample_Tries : constant := 12;

    -- How long a reading looks for output already written before asking for its sample, in milliseconds
    -- GNAT.Expect documents a timeout of zero as unpredictable, hence this small value instead
    Drain_Timeout : constant := 10;

    -- After a failure, how long before powermetrics is started again, so a broken one does not hold up every reading
    Retry_After : constant Time_Span := Seconds (10);

    -- Time between two readings that share one sample: the CPU and the GPU are read one after the other
    Reuse_Within : constant Time_Span := Milliseconds (100);

    -- e.g. "CPU Power: 1234 mW", anchored so "Combined Power (CPU + GPU + ANE)" and "ANE Power" never match
    -- The unit is captured too, as some versions of powermetrics report watts
    Power_Line : constant Pattern_Matcher :=
        Compile ("^ *(CPU|GPU) Power: +([0-9.]+) +(m?W)", Multiple_Lines);

    -- Mac Intel, e.g. "Intel energy model derived package power (CPUs+GT+SA): 2.48W": the whole chip, like the RAPL package domain
    -- Same three groups as above, so one Store reads both
    Intel_Power_Line : constant Pattern_Matcher :=
        Compile ("^ *(Intel) energy model derived package power \(CPUs\+GT\+SA\): +([0-9.]+) *(m?W)", Multiple_Lines);

    Process : Process_Descriptor;

    Running : Boolean := False;

    -- Sources still using the process
    In_Use : Source_List := (others => False);

    -- Power of the last whole sample, in watts, and when it arrived
    Watts : array (Source) of Long_Float := (others => 0.0);
    Asked : Time := Time_First;

    Pending_CPU : Long_Float := 0.0;
    Pending_CPU_Seen : Boolean := False;

    -- Readings do not start powermetrics again before this moment after a failure (Open always tries)
    Retry_At : Time := Time_First;

    --------------------------------------------------

    -- Apple Silicon report the CPU and the GPU each on a line; Mac Intel report the whole chip on one line, and no GPU
    function Is_Apple_Silicon return Boolean is
        function Sysctl_By_Name
           (Name : in char_array;
            Oldp : in System.Address;
            Oldlenp : in System.Address;
            Newp : in System.Address;
            Newlen : in size_t) return int
            with Import, Convention => C, External_Name => "sysctlbyname";

        Is_ARM : aliased int := 0;
        Length : aliased size_t := int'Size / System.Storage_Unit;
    begin
        return Sysctl_By_Name (To_C ("hw.optional.arm64"), Is_ARM'Address, Length'Address, System.Null_Address, 0) = 0
               and then Is_ARM = 1;
    end Is_Apple_Silicon;

    Apple_Silicon : constant Boolean := Is_Apple_Silicon;

    -- The power line of this chip
    Chip_Line : constant Pattern_Matcher := (if Apple_Silicon then Power_Line else Intel_Power_Line);

    --------------------------------------------------

    -- powermetrics only runs as root, so check it before spawning it for nothing
    function Is_Root return Boolean is
        function Get_Effective_UID return unsigned
            with Import, Convention => C, External_Name => "geteuid";
    begin
        return Get_Effective_UID = 0;
    end Is_Root;

    --------------------------------------------------

    -- GNAT.Expect.Close kills and reaps the process, so nothing is left behind
    procedure Stop is
    begin
        if Running then
            begin
                GNAT.Expect.Close (Process);
            exception
                when others =>
                    null;
            end;
        end if;

        Running := False;

        Watts := (others => 0.0);
        Pending_CPU_Seen := False;
    end Stop;

    --------------------------------------------------

    -- Gives up on powermetrics for a while: its sources read zero until it is started again
    procedure Give_Up is
    begin
        Stop;
        Retry_At := Clock + Retry_After;
    end Give_Up;

    --------------------------------------------------

    -- Stores one matched power line; True when it completes a whole sample
    -- Only a CPU line followed by its GPU line counts, so both values come from one sample; Mac Intel have one line
    function Store (Output : in String; Matched : in Match_Array) return Boolean is
        Name : constant String := Output (Matched (1).First .. Matched (1).Last);
        Unit : constant String := Output (Matched (3).First .. Matched (3).Last);
        Value : Long_Float;
    begin
        -- Assigned in the body so the handler catches a bad number
        Value := Long_Float'Value (Output (Matched (2).First .. Matched (2).Last));

        if Unit = "mW" then
            Value := Value / 1000.0;
        end if;

        if Name = "Intel" then
            Watts := (CPU => Value, GPU => 0.0);
            return True;
        elsif Name = "CPU" then
            Pending_CPU := Value;
            Pending_CPU_Seen := True;
        elsif Pending_CPU_Seen then
            Watts := (CPU => Pending_CPU, GPU => Value);
            Pending_CPU_Seen := False;
            return True;
        end if;

        return False;
    exception
        when others =>
            -- Not a number: the line is skipped
            return False;
    end Store;

    --------------------------------------------------

    -- Asks powermetrics for a sample and waits for it, whole, until Deadline
    -- What it already wrote (a sample of its own, a late answer) is read first, so the sample kept is the one asked for
    function Ask (Deadline : in Time) return Boolean is
        Result : Expect_Match;
        Matched : Match_Array (0 .. 3);
        Ignored : Boolean;
    begin
        loop
            Expect (Process, Result, Chip_Line, Matched, Timeout => Drain_Timeout);

            exit when Result = Expect_Timeout;

            Ignored := Store (Expect_Out (Process), Matched);
        end loop;

        Send_Signal (Process, SIGINFO);

        loop
            Expect (Process, Result, Chip_Line, Matched,
                    Timeout => Integer'Max (1, Integer (Float (To_Duration (Deadline - Clock)) * 1000.0)));

            if Result = Expect_Timeout then
                -- GNAT's Expect gives up early once less than half a second is left, so wait on until Deadline
                exit when Clock >= Deadline;
            elsif Store (Expect_Out (Process), Matched) then
                return True;
            end if;
        end loop;

        return False;
    end Ask;

    --------------------------------------------------

    -- Spawns powermetrics and waits for its first sample.
    -- Running says whether it answered
    procedure Start is
        Arguments : GNAT.OS_Lib.Argument_List :=
            (new String'("--samplers"), new String'(if Apple_Silicon then "cpu_power,gpu_power" else "cpu_power"),
             -- Each reading asks for a sample, which then covers the time since the previous one
             new String'("-i"), new String'(Own_Interval),
             -- Unbuffered, so a reading gets the sample it asked for
             new String'("-b"), new String'("0"),
             -- Shorter output to read through
             new String'("--hide-cpu-duty-cycle"));

        -- Free sets a String to null and freeing null does nothing, so calling this twice is harmless
        procedure Free_Arguments is
        begin
            for Argument of Arguments loop
                GNAT.OS_Lib.Free (Argument);
            end loop;
        end Free_Arguments;
    begin
        -- Keep powermetrics' stderr out of the host terminal
        Non_Blocking_Spawn (Descriptor => Process,
                            Command => Tool,
                            Args => Arguments,
                            Buffer_Size => Output_Buffer_Size,
                            Err_To_Out => True);

        Free_Arguments;

        Running := True;

        for Try in 1 .. First_Sample_Tries loop
            if Ask (Clock + Milliseconds (Ask_Again)) then
                Asked := Clock;
                return;
            end if;
        end loop;

        Give_Up;
    exception
        when others =>
            Free_Arguments;
            Give_Up;
    end Start;

    --------------------------------------------------

    -- Gets the sample of this reading, unless the one just asked for serves it
    -- After a failure, starts powermetrics again once Retry_At has passed
    procedure Update is
    begin
        if Running then
            -- abs: Ada.Real_Time.Clock follows the wall clock on macOS, which may be set back
            if abs (Clock - Asked) < Reuse_Within then
                return;
            end if;

            if Ask (Clock + Milliseconds (Sample_Timeout)) then
                Asked := Clock;
            else
                Give_Up;
            end if;
        elsif Clock >= Retry_At then
            -- Its first sample serves this reading
            Start;
        end if;
    exception
        when others =>
            -- The process died or its pipe broke
            Give_Up;
    end Update;

    --------------------------------------------------

    function Open (Item : in Source) return Boolean is
    begin
        -- powermetrics gives no GPU power on Mac Intel
        if Item = GPU and then not Apple_Silicon then
            return False;
        end if;

        if not Running then
            if not Is_Root then
                return False;
            end if;

            Start;

            if not Running then
                return False;
            end if;
        end if;

        In_Use (Item) := True;
        return True;
    end Open;

    --------------------------------------------------

    function Get_Power (Item : in Source) return Long_Float is
    begin
        Update;

        -- Zero once Stop gave up on the process
        return Watts (Item);
    end Get_Power;

    --------------------------------------------------

    procedure Close (Item : in Source) is
    begin
        In_Use (Item) := False;

        if not In_Use (CPU) and then not In_Use (GPU) then
            Stop;
        end if;
    end Close;

end Joular_Core.Powermetrics;
