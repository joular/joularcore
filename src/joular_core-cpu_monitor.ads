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

-- Measure the CPU
-- Each OS has its own body, in its folder, listing the ways it can read the CPU and the order they are tried in
private package Joular_Core.CPU_Monitor is

    -- Detect the CPU and how to read it (e.g. RAPL, Raspberry Pi board model, powermetrics)
    -- Opens the files, drivers or processes needed, and takes a first reading of cumulative counters
    -- Returns False when the CPU cannot be measured
    function Open return Boolean;

    -- One measurement: the energy consumed since the last reading, or the power drawn, depending on what the hardware reports
    function Read return Measurement;

    -- Close what Open opened (e.g. a driver on Windows, the powermetrics process on macOS)
    procedure Close;

end Joular_Core.CPU_Monitor;
