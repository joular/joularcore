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

package Joular_Core.CPU_Monitor is

    -- Detect CPU packages and characteristics
    -- Ex.: RAPL max range, PKG supported, Raspberry Pi board model, MSR or powercap, etc.
    -- Return True is CPU monitoring is present and accessible, otherwise False
    function Detect_CPU return Boolean;

    -- Start the monitoring process
    -- For RAPL powercap, get max range + do a sample reading
    -- For RAPL MSR, initialize and open drive, get max range + do a sample reading
    -- For Powermetrics, spawn the tool's process and get a first reading
    -- For Raspberry Pi, do nothing
    procedure Start_Monitoring;

    -- Monitor the CPU energy and take a measurement
    -- Return the energy consumed since last reading, or the power consumption as reported by hardware
    function Get_CPU_Reading return Measurement;

end Joular_Core.CPU_Monitor;