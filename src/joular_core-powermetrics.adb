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

#if PJ_MACOS then
with Interfaces.C; use Interfaces.C;

with GNAT.Expect; use GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.Regpat; use GNAT.Regpat;

with Joular_Core.OS_Utils; use Joular_Core.OS_Utils;
#end if;

package body Joular_Core.Powermetrics is

#if PJ_MACOS then

    -- The macOS tool reporting the power of the chip, given by its full path so that PATH cannot point at another program
    Tool : constant String := "/usr/bin/powermetrics";

    -- Time powermetrics waits between two samples, in milliseconds
    Sample_Interval : constant String := "1000";

    -- Characters kept of what powermetrics wrote, enough to hold one whole sample (older ones are discarded, and only the last sample is used)
    Output_Buffer_Size : constant := 8192;

    -- How long to wait for the first sample, in milliseconds (one interval, plus margin)
    First_Sample_Timeout : constant := 3000;

    -- How long a reading waits for a sample powermetrics already wrote, in milliseconds
    -- GNAT.Expect documents a timeout of zero as unpredictable, hence this small value instead
    Drain_Timeout : constant := 10;

    -- The lines powermetrics writes for the CPU and for the GPU, for example "CPU Power: 1234 mW"
    -- Anchored at the start of a line, so the "Combined Power (CPU + GPU + ANE)" and "ANE Power" lines never match
    -- The value is read with its unit, so a version of powermetrics reporting watts rather than milliwatts is read correctly too
    Power_Line : constant Pattern_Matcher :=
        Compile ("^ *(CPU|GPU) Power: +([0-9.]+) +(m?W)", Multiple_Lines);

    -- The powermetrics process being read
    Process : Process_Descriptor;

    -- True while the process runs and answers
    Running : Boolean := False;

    -- Number of hardware sources using the process (the CPU and the GPU share the one process)
    Users : Natural := 0;

    -- Power of the last sample, in watts
    CPU_Watts : Long_Float := 0.0;
    GPU_Watts : Long_Float := 0.0;

    --------------------------------------------------

    -- powermetrics only runs as root, so check it before spawning it for nothing
    function Is_Root return Boolean is
        function Get_Effective_UID return unsigned
            with Import, Convention => C, External_Name => "geteuid";
    begin
        return Get_Effective_UID = 0;
    exception
        when others =>
            return False;
    end Is_Root;

    --------------------------------------------------

    -- Kill the process and forget the values it gave
    -- Killing it also reaps it, so it leaves nothing behind
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
        CPU_Watts := 0.0;
        GPU_Watts := 0.0;
    end Stop;

    --------------------------------------------------

    -- Keep the value of one power line just matched in the output of powermetrics
    -- The three parenthesized parts of the line are the hardware source, the value, and its unit
    procedure Store (Output : in String; Matched : in Match_Array) is
        Source : constant String := Output (Matched (1).First .. Matched (1).Last);
        Unit : constant String := Output (Matched (3).First .. Matched (3).Last);
        Watts : Long_Float := Long_Float'Value (Output (Matched (2).First .. Matched (2).Last));
    begin
        -- powermetrics reports milliwatts on Apple Silicon, so divide them to get watts
        if Unit = "mW" then
            Watts := Watts / 1000.0;
        end if;

        if Source = "CPU" then
            CPU_Watts := Watts;
        else
            GPU_Watts := Watts;
        end if;
    exception
        when others =>
            null;
    end Store;

    --------------------------------------------------

    -- Read every sample powermetrics wrote since the last call, and keep the values of the last one
    -- Nothing new to read simply keeps the values of the previous sample
    procedure Update is
        Result : Expect_Match;
        Matched : Match_Array (0 .. 3);
    begin
        if not Running then
            return;
        end if;

        loop
            Expect (Process, Result, Power_Line, Matched, Timeout => Drain_Timeout);

            exit when Result = Expect_Timeout or else Matched (0) = No_Match;

            Store (Expect_Out (Process), Matched);
        end loop;
    exception
        when others =>
            -- The process died or its output could not be read, so the sources it fed report zero from now on
            Stop;
    end Update;

    --------------------------------------------------

    -- Spawn powermetrics and wait for its first sample
    -- Returns False when it cannot be spawned, refuses to run, or gives nothing in time
    function Start return Boolean is
        Arguments : GNAT.OS_Lib.Argument_List :=
            (new String'("--samplers"), new String'("cpu_power,gpu_power"),
             new String'("-i"), new String'(Sample_Interval),
             -- Write each sample as it is taken instead of buffering them, so a reading gets the sample of the moment
             new String'("-b"), new String'("0"),
             -- Not needed here, and makes the output to read through shorter
             new String'("--hide-cpu-duty-cycle"));

        Result : Expect_Match;
        Matched : Match_Array (0 .. 3);

        -- Give the memory of the argument list back once it has been spawned
        -- Freeing a String sets it to null, and freeing null does nothing, so calling this twice is harmless
        procedure Free_Arguments is
        begin
            for Argument of Arguments loop
                GNAT.OS_Lib.Free (Argument);
            end loop;
        end Free_Arguments;
    begin
        -- Send what powermetrics writes on its error output to its standard output, so its own messages stay out of the terminal of the program using the library
        Non_Blocking_Spawn (Descriptor => Process,
                            Command => Tool,
                            Args => Arguments,
                            Buffer_Size => Output_Buffer_Size,
                            Err_To_Out => True);

        Free_Arguments;

        Running := True;

        -- Wait for the first sample, so the hardware sources are only reported as available when powermetrics actually answers
        Expect (Process, Result, Power_Line, Matched, Timeout => First_Sample_Timeout);

        if Result = Expect_Timeout or else Matched (0) = No_Match then
            Stop;
            return False;
        end if;

        Store (Expect_Out (Process), Matched);

        return True;
    exception
        when others =>
            Free_Arguments;
            Stop;
            return False;
    end Start;

    --------------------------------------------------

    function Is_Accessible return Boolean is
    begin
        -- The process is already running for the other hardware source, so simply share it
        if Running then
            Users := Users + 1;
            return True;
        end if;

        -- Only Apple Silicon is supported: Mac Intel report their power in another form, and have no power model here
        if Get_Platform_CPU_Name /= "apple" then
            return False;
        end if;

        if not Is_Root then
            return False;
        end if;

        if not Start then
            return False;
        end if;

        Users := 1;

        return True;
    exception
        when others =>
            return False;
    end Is_Accessible;

    --------------------------------------------------

    function Get_CPU_Power return Long_Float is
    begin
        Update;
        return CPU_Watts;
    end Get_CPU_Power;

    --------------------------------------------------

    function Get_GPU_Power return Long_Float is
    begin
        Update;
        return GPU_Watts;
    end Get_GPU_Power;

    --------------------------------------------------

    procedure Close is
    begin
        if Users > 0 then
            Users := Users - 1;
        end if;

        -- Neither the CPU nor the GPU uses the process any more, so kill it
        if Users = 0 then
            Stop;
        end if;
    end Close;

#else

    -- On other platforms, powermetrics does not exist, so return False and zeros

    function Is_Accessible return Boolean is
    begin
        return False;
    end Is_Accessible;

    --------------------------------------------------

    function Get_CPU_Power return Long_Float is
    begin
        return 0.0;
    end Get_CPU_Power;

    --------------------------------------------------

    function Get_GPU_Power return Long_Float is
    begin
        return 0.0;
    end Get_GPU_Power;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.Powermetrics;
