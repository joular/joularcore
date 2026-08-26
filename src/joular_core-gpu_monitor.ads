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

private package Joular_Core.GPU_Monitor is

    -- Detect the main discrete graphic card, and how to get its data
    -- Ex. Nvidia or AMD card, NVML or ADLX library, hwmon sysfs files, etc.
    -- Also, opens the library needed to read the GPU card
    -- Returns True if GPU monitoring is present and accessible, otherwise False
    function Detect_GPU return Boolean;

    -- Monitor the GPU and take a measurement
    -- Return the power consumption of the graphic card as reported
    function Get_GPU_Reading return Measurement;

    -- Stops monitoring
    -- For Nvidia and AMD cards, if a library was used (NVML or ADLX), then unload it
    procedure Stop_Monitoring;

end Joular_Core.GPU_Monitor;
