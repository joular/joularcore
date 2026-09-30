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

-- CPU usage, for the Rapbserry Pi board power models
private package Joular_Core.CPU_Load is

    -- Takes the first reading, so the next Usage call has an interval to measure
    procedure Start;

    -- CPU usage since the last reading, between 0.0 and 1.0
    -- Negative when no interval could be measured (kept apart from 0, which the power models read as idle)
    function Usage return Long_Float;

end Joular_Core.CPU_Load;
