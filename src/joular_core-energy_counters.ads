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

with Ada.Real_Time;

-- Energy counters that only count up, and wrap back to zero once full (e.g. RAPL)
-- Turns two readings of such a counter into the energy consumed between them
private package Joular_Core.Energy_Counters is

    -- No processor package draws this much: a reading implying more is a counter reset (suspend, driver glitch), not consumption
    Max_Package_Watts : constant Long_Float := 1000.0;

    -- Counter values are in microjoules
    type Counter is
       record
           -- The previous reading, or zero if there is none yet
           Last : Long_Long_Integer := 0;

           -- The value where the counter wraps back to zero, or zero if it never wraps
           Wrap_At : Long_Long_Integer := 0;

           -- When Last was read, to tell energy from a reset
           Last_Time : Ada.Real_Time.Time := Ada.Real_Time.Clock;

           -- How many packages the counter adds up (EMI sums every socket), so the reset bound grows with them
           Packages : Positive := 1;
       end record;

    -- Energy consumed since the last reading, in joules, and keep Reading as the new last one
    -- A reading of zero means the counter couldn't be read: it gives zero and keeps the last reading, so the next reading that works covers the gap
    -- A drop is a wrap, corrected by adding the range; only one wrap can be corrected, so read more often than the counter takes to fill half its range
    -- Energy that would mean more than Max_Package_Watts per package is a reset: it gives zero, and the next reading counts from this one
    function Joules_Since_Last (Item : in out Counter; Reading : in Long_Long_Integer) return Long_Float;

end Joular_Core.Energy_Counters;
