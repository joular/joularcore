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

#if PJ_LINUX then
with GNAT.String_Split; use GNAT;
with Joular_Core.File_Utils; use Joular_Core.File_Utils;
#end if;

package body Joular_Core.CPU_Load is

#if PJ_LINUX then

    -- CPU statistics files on Linux
    Stat_File : constant String := "/proc/stat";

    -- Type for CPU statistics
    type CPU_Times is
       record
           -- Total time spend
           Total : Long_Long_Integer := 0;
           -- Time spend in idle mode
           Idle : Long_Long_Integer := 0;
       end record;

    -- Time read at the previous call
    Previous_Times : CPU_Times;

    --------------------------------------------------

    -- Read CPU times from /proc/stat on Linux
    -- Example file is: cpu  83141 56 28074 2909632 3452 10196 3416 0 0 0
    -- which is the time spent in user mode, in user mode at a low priority (nice), in system mode, in the idle task, waiting for I/O, handling interrupts, handling soft interrupts, and stolen by the hypervisor of a virtual machine
    -- The two columns that follow those eight, guest and guest_nice, are left out, as the kernel already counts them inside user and nice
    function Read_Times return CPU_Times is
        Subs : String_Split.Slice_Set;
        Times : CPU_Times;

        -- Util function to slice the read file and get the specific column needed
        function Column (Index : in String_Split.Slice_Number) return Long_Long_Integer is
            (Long_Long_Integer'Value (String_Split.Slice (Subs, Index)));
    begin
        -- Slice the first line of the file (an unreadable file gives an empty line, rejected below)
        String_Split.Create (S => Subs,
                             From => Read_First_Line (Stat_File),
                             Separators => " ",
                             Mode => String_Split.Multiple);

        -- The line must hold the name and the eight columns (so 9 slices), and must be the one totalling every core (so "cpu") rather than the one of a single core, "cpu0"
        if Integer (String_Split.Slice_Count (Subs)) < 9
           or else String_Split.Slice (Subs, 1) /= "cpu"
        then
            return Times;
        end if;

        -- Get idle time
        Times.Idle := Column (5) + Column (6); -- idle, iowait

        -- Get total time
        Times.Total := Column (2) + Column (3) + Column (4) -- user, nice, system
                     + Times.Idle -- idle, iowait
                     + Column (7) + Column (8) + Column (9); -- irq, softirq, steal

        return Times;
    exception
        when others =>
            return (others => <>);
    end Read_Times;

    --------------------------------------------------

    procedure Start is
    begin
        Previous_Times := Read_Times;
    end Start;

    --------------------------------------------------

    function Usage return Long_Float is
        Current_Times : constant CPU_Times := Read_Times;
        Elasped_Time : constant Long_Long_Integer := Current_Times.Total - Previous_Times.Total;
        Waiting_Time : Long_Long_Integer; -- Ticks of the interval the machine spend waiting
        Result : Long_Float := 0.0;
    begin
        -- Current time is zero (counter can't be read or other error), return 0
        if Current_Times.Total = 0 then
            return 0.0;
        end if;

        -- Previous time is positive, and time has elapsed
        if Previous_Times.Total > 0 and then Elasped_Time > 0 then
            -- Waiting can't be longer than the elasped time (the interval it is part of)
            -- Some kernel version let it go backward, so it might report more work done than actually done
            Waiting_Time := Long_Long_Integer'Max (0, Long_Long_Integer'Min (Elasped_Time, Current_Times.Idle - Previous_Times.Idle));
            Result := Long_Float (Elasped_Time - Waiting_Time) / Long_Float (Elasped_Time);
        end if;

        Previous_Times := Current_Times;

        return Result;
    end Usage;

#else

    -- On other platforms, not used, hence no implementation

    procedure Start is
    begin
        null;
    end Start;

    --------------------------------------------------

    function Usage return Long_Float is
    begin
        return 0.0;
    end Usage;

#end if;

end Joular_Core.CPU_Load;
