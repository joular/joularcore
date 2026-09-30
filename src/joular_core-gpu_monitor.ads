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

-- Measure the main graphic card
-- Each OS has its own body, in its folder, listing the ways it can read the GPU and the order they are tried in
private package Joular_Core.GPU_Monitor is

    -- Detect the main graphic card, and how to get its data (e.g. NVML or ADLX library, hwmon sysfs files, powermetrics)
    -- Opens the library needed to read it
    -- Returns False when the GPU cannot be measured
    function Open return Boolean;

    -- One measurement: the power drawn by the card, in watts
    function Read return Measurement;

    -- Close what Open opened (e.g. unload the NVML or ADLX library)
    procedure Close;

end Joular_Core.GPU_Monitor;
