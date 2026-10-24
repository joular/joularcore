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

package body Joular_Core.Energy_Counters is

    function Joules_Since_Last (Item : in out Counter; Reading : in Long_Long_Integer) return Long_Float is
        Now : constant Time := Clock;
        Seconds : Long_Float;
        Microjoules : Long_Long_Integer;
        Joules : Long_Float;
    begin
        if Reading = 0 then
            return 0.0;
        end if;

        -- Nothing to measure from yet
        if Item.Last = 0 then
            Item.Last := Reading;
            Item.Last_Time := Now;
        end if;

        Microjoules := Reading - Item.Last;
        Seconds := Long_Float (To_Duration (Now - Item.Last_Time));
        Item.Last := Reading;
        Item.Last_Time := Now;

        -- Negative means the counter wrapped, so add the range it wraps at
        if Microjoules < 0 then
            Microjoules := Microjoules + Item.Wrap_At;
        end if;

        -- Still negative when the wrap point is unknown (Wrap_At = 0), so report zero
        if Microjoules < 0 then
            return 0.0;
        end if;

        Joules := Long_Float (Microjoules) / 1_000_000.0;

        -- More than a package can draw: the counter was reset, and this reading only starts the next one
        if Seconds > 0.0 and then Joules / Seconds > Max_Package_Watts then
            return 0.0;
        end if;

        return Joules;
    end Joules_Since_Last;

end Joular_Core.Energy_Counters;
