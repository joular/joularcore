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

-- Energy counters that only count up, and wrap back to zero once full (e.g. RAPL)
-- Turns two readings of such a counter into the energy consumed between them
private package Joular_Core.Energy_Counters is

    -- Counter values are in microjoules
    type Counter is
       record
           -- The previous reading, or zero if there is none yet
           Last : Long_Long_Integer := 0;

           -- The value where the counter wraps back to zero, or zero if it never wraps
           Wrap_At : Long_Long_Integer := 0;
       end record;

    -- Energy consumed since the last reading, in joules, and keep Reading as the new last one
    -- A reading of zero means the counter couldn't be read: it gives zero and keeps the last reading, so the next reading that works covers the gap
    -- Only one wrap can be corrected, so read more often than the counter takes to fill half its range
    -- A drop that doesn't look like a wrap is taken as a counter reset and gives zero
    function Joules_Since_Last (Item : in out Counter; Reading : in Long_Long_Integer) return Long_Float;

end Joular_Core.Energy_Counters;
