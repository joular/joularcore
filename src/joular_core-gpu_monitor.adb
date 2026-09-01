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

with Joular_Core.GPU_Nvidia_NVML; use Joular_Core.GPU_Nvidia_NVML;
with Joular_Core.GPU_AMD_Sysfs; use Joular_Core.GPU_AMD_Sysfs;
with Joular_Core.GPU_AMD_ADLX; use Joular_Core.GPU_AMD_ADLX;
with Joular_Core.Powermetrics; use Joular_Core.Powermetrics;

package body Joular_Core.GPU_Monitor is

    -- GPU driver method to get power readings
    type Driver_Kind is (None, Nvidia_NVML, AMD_Sysfs, AMD_ADLX, Apple_Powermetrics);

    -- Driver detected and used
    Driver : Driver_Kind := None;

    --------------------------------------------------

    function Detect_GPU return Boolean is
    begin
        -- First check Nvidia card through NVML
        if GPU_Nvidia_NVML.Is_Accessible then
            Driver := Nvidia_NVML;

        -- No Nvidia card, then check for AMD card on Linux/BSD
        elsif GPU_AMD_Sysfs.Is_Accessible then
            Driver := AMD_Sysfs;

        -- Check AMD card on Windows
        elsif GPU_AMD_ADLX.Is_Accessible then
            Driver := AMD_ADLX;

        -- No card of another vendor, then check the GPU built in the chip of Apple Silicon Macs
        elsif Powermetrics.Is_Accessible then
            Driver := Apple_Powermetrics;

        -- No supported GPU
        else
            Driver := None;
        end if;

        return Driver /= None;
    end Detect_GPU;

    --------------------------------------------------

    function Get_GPU_Reading return Measurement is
        Watts_Value : Long_Float;
    begin
        case Driver is
            when Nvidia_NVML =>
                Watts_Value := GPU_Nvidia_NVML.Get_Power;

            when AMD_Sysfs =>
                Watts_Value := GPU_AMD_Sysfs.Get_Power;

            when AMD_ADLX =>
                Watts_Value := GPU_AMD_ADLX.Get_Power;

            when Apple_Powermetrics =>
                Watts_Value := Powermetrics.Get_GPU_Power;

            -- No driver available, nothing to read so return empty measurement
            when None =>
                return (others => <>);
        end case;

        return (Available => True,
                Value => Watts_Value,
                Unit => Power);
    end Get_GPU_Reading;

    --------------------------------------------------

    procedure Stop_Monitoring is
    begin
        case Driver is
            when Nvidia_NVML =>
                GPU_Nvidia_NVML.Close;

            when AMD_Sysfs =>
                GPU_AMD_Sysfs.Close;

            when AMD_ADLX =>
                GPU_AMD_ADLX.Close;

            when Apple_Powermetrics =>
                Powermetrics.Close;

            when None =>
                null;
        end case;

        Driver := None;
    end Stop_Monitoring;

end Joular_Core.GPU_Monitor;
