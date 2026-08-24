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

package Joular_Core.RAPL_Type is

    -- Data structure to store RAPL information
    -- Type used for all RAPL platforms (Linux, Windows, BSD)
    type RAPL_Data is
        record
            -- Energy consumed since last reading
            -- Value corrected if RAPL counter wrapped
            PKG_Energy : Long_Long_Integer := 0;

            -- Store energy value as read from RAPL counter
            -- No changes at all on this value (no counter wrap corrections, etc.)
            PKG_Raw_Energy : Long_Long_Integer := 0;

            -- Max value the RAPL counter can hold
            -- Useful to check when RAPL counter wraps
            PKG_Max_Energy_Range : Long_Long_Integer := 0;
        end record;

end Joular_Core.RAPL_Type;