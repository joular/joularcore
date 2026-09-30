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

    -- Time powermetrics waits between two samples, in milliseconds
    Sample_Interval : constant String := "1000";

    -- Enough for one whole sample; older output is discarded
    Output_Buffer_Size : constant := 8192;

    -- How long to wait for the first sample, in milliseconds (one interval, plus margin)
    First_Sample_Timeout : constant := 3000;

    -- How long a reading waits for a sample powermetrics already wrote, in milliseconds
    -- GNAT.Expect documents a timeout of zero as unpredictable, hence this small value instead
    Drain_Timeout : constant := 10;

    -- e.g. "CPU Power: 1234 mW", anchored so "Combined Power (CPU + GPU + ANE)" and "ANE Power" never match
    -- The unit is captured too, as some versions of powermetrics report watts
    Power_Line : constant Pattern_Matcher :=
        Compile ("^ *(CPU|GPU) Power: +([0-9.]+) +(m?W)", Multiple_Lines);

    -- No new sample for this long means powermetrics stopped
    Stale_After : constant Time_Span := Milliseconds (3_500);

    -- Time between two readings that justifies using the old one
    Reuse_Within : constant Time_Span := Milliseconds (100);

    Process : Process_Descriptor;

    Running : Boolean := False;

    -- Sources still using the process
    In_Use : Source_List := (others => False);

    -- Power of the last whole sample, in watts, and the moment it was put together
    Watts : array (Source) of Long_Float := (others => 0.0);
    Sample_Time : Time := Time_First;

    Pending_CPU : Long_Float := 0.0;
    Pending_CPU_Seen : Boolean := False;

    -- When the output was last drained, so reading the two sources one after the other does not drain it twice
    Last_Drain : Time := Time_First;

    --------------------------------------------------

    -- Only Apple Silicon is supported: Mac Intel report their power in another form, and have no power model here
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
        Sample_Time := Time_First;

        Pending_CPU := 0.0;
        Pending_CPU_Seen := False;

        Last_Drain := Time_First;
    end Stop;

    --------------------------------------------------

    -- Stores one matched power line; False when its value is not a number
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

        -- Publish only a CPU line followed by its GPU line, so both values come from one sample
        if Name = "CPU" then
            Pending_CPU := Value;
            Pending_CPU_Seen := True;
        elsif Pending_CPU_Seen then
            Watts := (CPU => Pending_CPU, GPU => Value);
            Sample_Time := Clock;

            Pending_CPU_Seen := False;
        end if;

        return True;
    exception
        when others =>
            return False;
    end Store;

    --------------------------------------------------

    function Sample_Is_Fresh return Boolean is
    begin
        return Running
               and then Sample_Time /= Time_First
               and then Clock - Sample_Time <= Stale_After;
    end Sample_Is_Fresh;

    --------------------------------------------------

    -- Spawns powermetrics and waits for its first sample
    -- False when it cannot run or gives nothing in time
    function Start return Boolean is
        Arguments : GNAT.OS_Lib.Argument_List :=
            (new String'("--samplers"), new String'("cpu_power,gpu_power"),
             new String'("-i"), new String'(Sample_Interval),
             -- Unbuffered, so a reading gets the sample of the moment
             new String'("-b"), new String'("0"),
             -- Shorter output to read through
             new String'("--hide-cpu-duty-cycle"));

        Result : Expect_Match;
        Matched : Match_Array (0 .. 3);
        Deadline : Time;

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

        -- One window back, so the first Update drains rather than reuses, and Clock - Time_First (which overflows) is never computed
        Last_Drain := Clock - Reuse_Within;

        -- The sources are only reported available once powermetrics answers for both
        Deadline := Clock + Milliseconds (First_Sample_Timeout);

        while Clock < Deadline loop
            Expect (Process, Result, Power_Line, Matched,
                    Timeout => Integer'Max (1, Integer (Float (To_Duration (Deadline - Clock)) * 1000.0)));

            exit when Result = Expect_Timeout or else Matched (0) = No_Match;

            if not Store (Expect_Out (Process), Matched) then
                Stop;
                return False;
            end if;

            if Sample_Time /= Time_First then
                return True;
            end if;
        end loop;

        Stop;
        return False;
    exception
        when others =>
            Free_Arguments;
            Stop;
            return False;
    end Start;

    --------------------------------------------------

    -- Drains what powermetrics wrote since the last call, keeping the last whole sample
    procedure Update is
        Result : Expect_Match;
        Matched : Match_Array (0 .. 3);
        Ignored : Boolean;
    begin
        if not Running then
            return;
        end if;

        if Clock - Last_Drain < Reuse_Within then
            return;
        end if;

        -- After a long gap the pipe filled and powermetrics stalled on it, so restart for a fresh sample
        if Clock - Last_Drain > Stale_After then
            Stop;

            if not Start then
                return;
            end if;
        end if;

        Last_Drain := Clock;

        loop
            Expect (Process, Result, Power_Line, Matched, Timeout => Drain_Timeout);

            exit when Result = Expect_Timeout or else Matched (0) = No_Match;

            Ignored := Store (Expect_Out (Process), Matched);
        end loop;
    exception
        when others =>
            -- The process died or its pipe broke; its sources read zero from now on
            Stop;
    end Update;

    --------------------------------------------------

    function Open (Item : in Source) return Boolean is
    begin
        if not Running then
            if not Is_Apple_Silicon or else not Is_Root or else not Start then
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

        if not Sample_Is_Fresh then
            return 0.0;
        end if;

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
