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
with Joular_Core.RAPL_Powercap;
#elsif PJ_WINDOWS then
with Joular_Core.RAPL_MSR_Windows;
#else
with Joular_Core.RAPL_None;
#end if;

package body Joular_Core.RAPL is

    -- RAPL reader, renames this package to the proper one according to the OS/platform
#if PJ_LINUX then
    package Reader renames Joular_Core.RAPL_Powercap;
#elsif PJ_WINDOWS then
    package Reader renames Joular_Core.RAPL_MSR_Windows;
#else
    package Reader renames Joular_Core.RAPL_None;
#end if;

    -- Previous reading of the RAPL counter
    Previous_Counter : Long_Long_Integer := 0;

    -- Maximum energy range for the RAPL counter
    Max_Energy_Range : Long_Long_Integer := 0;

    --------------------------------------------------

    function Is_Accessible return Boolean is
    begin
        if not Reader.Open then
            return False;
        end if;

        -- Get max energy range
        Max_Energy_Range := Reader.Max_Energy_Range;

        -- Take the first reading, so the next reading calculate energy based on this and not of the counter big value
        Previous_Counter := Reader.Read_Counter;

        return True;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Energy return Long_Long_Integer is
        Current_Counter : Long_Long_Integer;
        Energy : Long_Long_Integer;
    begin
        Current_Counter := Reader.Read_Counter;

        -- Current counter reads 0, most probably failed to read the counter
        if Current_Counter = 0 then
            return 0;
        end if;

        -- If previous counter is 0 (meaning previous counter couldn't be read), don't calculate energy
        if Previous_Counter = 0 then
            Previous_Counter := Current_Counter;
        end if;

        Energy := Current_Counter - Previous_Counter;
        Previous_Counter := Current_Counter;

        -- If energy is negative, then the RAPL counter wrapped, so add max energy range
        if Energy < 0 then
            Energy := Energy + Max_Energy_Range;
        end if;

        -- If still negative, meaning the counter wrap can't be identified, report zero
        if Energy < 0 then
            return 0;
        end if;

        return Energy;
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        Reader.Close;
    end Close;

end Joular_Core.RAPL;
