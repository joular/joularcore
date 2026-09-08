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
    -- Returns a negative value when there was no interval to measure: the counter could not be read, there was no earlier reading to measure from, the counter went backwards, or no time has passed since the last reading, which is what reading faster than the kernel counts looks like
    -- That is told apart from a usage of zero on purpose. The power models turn a usage of zero into the idle power of the board, so an interval that could not be measured would otherwise come back as a plausible number of watts that was never measured
    function Usage return Long_Float;

end Joular_Core.CPU_Load;
