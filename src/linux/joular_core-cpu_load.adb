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

with GNAT.String_Split; use GNAT;
with Joular_Core.File_Utils; use Joular_Core.File_Utils;

package body Joular_Core.CPU_Load is

    -- Returned when no interval could be measured
    Not_Measured : constant Long_Float := -1.0;

    Stat_File : constant String := "/proc/stat";

    -- Kernel ticks since boot
    type CPU_Times is
       record
           Total : Long_Long_Integer := 0;
           Idle : Long_Long_Integer := 0;
       end record;

    Previous_Times : CPU_Times;

    --------------------------------------------------

    -- Read CPU times from /proc/stat on Linux
    -- Example file is: cpu  83141 56 28074 2909632 3452 10196 3416 0 0 0
    -- which is the time spent in user mode, in user mode at a low priority (nice), in system mode, in the idle task, waiting for I/O, handling interrupts, handling soft interrupts, and stolen by the hypervisor of a virtual machine
    -- The two columns that follow those eight, guest and guest_nice, are left out, as the kernel already counts them inside user and nice
    function Read_Times return CPU_Times is
        Subs : String_Split.Slice_Set;
        Times : CPU_Times;

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

        Times.Idle := Column (5) + Column (6); -- idle, iowait

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
        Elapsed_Time : constant Long_Long_Integer := Current_Times.Total - Previous_Times.Total;
        Waiting_Time : Long_Long_Integer; -- Ticks of the interval spent waiting
    begin
        -- Counter unreadable: keep Previous_Times so the next good reading covers the gap
        if Current_Times.Total = 0 then
            return Not_Measured;
        end if;

        -- Nothing to measure from yet, so this reading becomes what the next one measures from
        if Previous_Times.Total = 0 then
            Previous_Times := Current_Times;
            return Not_Measured;
        end if;

        -- Counter went backwards (e.g. machine restarted): restart from here
        if Elapsed_Time < 0 then
            Previous_Times := Current_Times;
            return Not_Measured;
        end if;

        -- Read within one kernel tick: keep Previous_Times so the next interval is longer
        if Elapsed_Time = 0 then
            return Not_Measured;
        end if;

        -- Idle can't exceed the interval, and some kernels let it go backwards
        Waiting_Time := Long_Long_Integer'Max (0, Long_Long_Integer'Min (Elapsed_Time, Current_Times.Idle - Previous_Times.Idle));

        Previous_Times := Current_Times;

        return Long_Float (Elapsed_Time - Waiting_Time) / Long_Float (Elapsed_Time);
    end Usage;

end Joular_Core.CPU_Load;
