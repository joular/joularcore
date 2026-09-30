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

package body Joular_Core.Energy_Counters is

    function Joules_Since_Last (Item : in out Counter; Reading : in Long_Long_Integer) return Long_Float is
        Microjoules : Long_Long_Integer;
    begin
        if Reading = 0 then
            return 0.0;
        end if;

        -- Nothing to measure from yet
        if Item.Last = 0 then
            Item.Last := Reading;
        end if;

        Microjoules := Reading - Item.Last;
        Item.Last := Reading;

        -- Negative means the counter wrapped, so add the range it wraps at
        -- A jump of more than half the range can't be a wrap between two readings: the counter was reset (e.g. after suspend)
        if Microjoules < 0 then
            Microjoules := Microjoules + Item.Wrap_At;

            if Microjoules > Item.Wrap_At / 2 then
                return 0.0;
            end if;
        end if;

        -- Still negative when the wrap point is unknown (Wrap_At = 0), so report zero
        if Microjoules < 0 then
            return 0.0;
        end if;

        return Long_Float (Microjoules) / 1_000_000.0;
    end Joules_Since_Last;

end Joular_Core.Energy_Counters;
