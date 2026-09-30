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

with Joular_Core.GPU_Nvidia_NVML;
with Joular_Core.GPU_AMD_Sysfs;

-- Linux: Nvidia cards through NVML, otherwise AMD cards through hwmon sysfs
package body Joular_Core.GPU_Monitor is

    type Driver_Kind is (None, Nvidia_NVML, AMD_Sysfs);

    Driver : Driver_Kind := None;

    --------------------------------------------------

    function Open return Boolean is
    begin
        if GPU_Nvidia_NVML.Open then
            Driver := Nvidia_NVML;
        elsif GPU_AMD_Sysfs.Open then
            Driver := AMD_Sysfs;
        else
            Driver := None;
        end if;

        return Driver /= None;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        case Driver is
            when Nvidia_NVML =>
                return (Available => True, Value => GPU_Nvidia_NVML.Get_Power, Unit => Power);

            when AMD_Sysfs =>
                return (Available => True, Value => GPU_AMD_Sysfs.Get_Power, Unit => Power);

            when None =>
                return (others => <>);
        end case;
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        case Driver is
            when Nvidia_NVML => GPU_Nvidia_NVML.Close;
            when AMD_Sysfs => GPU_AMD_Sysfs.Close;
            when None => null;
        end case;

        Driver := None;
    end Close;

end Joular_Core.GPU_Monitor;
