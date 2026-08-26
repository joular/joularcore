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

-- Calculate CPU usage. Used mainly for Raspberry Pi power estimation models
private package Joular_Core.CPU_Load is

    -- Read the CPU time counter to get CPU load and use them in next reading to calculate CPU usage
    procedure Start;

    -- Calculate CPU usage since last reading, as a value between 0.0 and 1.0
    -- Return zero when counter can't be read, or when no time has passed
    function Usage return Long_Float;

end Joular_Core.CPU_Load;
