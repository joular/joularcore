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

private package Joular_Core.CPU_Monitor is

    -- Detect CPU packages and characteristics
    -- Ex.: RAPL max range, PKG supported, Raspberry Pi board model, MSR or powercap, etc.
    -- Return True is CPU monitoring is present and accessible, otherwise False
    function Detect_CPU (Platform : in String) return Boolean;

    -- Monitor the CPU energy and take a measurement
    -- Return the energy consumed since last reading, or the power consumption as reported by hardware
    function Get_CPU_Reading return Measurement;

    -- Stops monitoring
    -- For RAPL, if a driver was used (on Windows for example), then close driver
    -- For powermetrics (macOS), kill the spawned process
    procedure Stop_Monitoring;

end Joular_Core.CPU_Monitor;
