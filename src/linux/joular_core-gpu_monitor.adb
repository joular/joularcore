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

package body Joular_Core.GPU_Monitor is

    -- Both, so a machine carrying cards of both makes is read whole
    Nvidia_Open : Boolean := False;
    AMD_Open : Boolean := False;

    --------------------------------------------------

    function Open return Boolean is
    begin
        Nvidia_Open := GPU_Nvidia_NVML.Open;
        AMD_Open := GPU_AMD_Sysfs.Open;

        return Nvidia_Open or AMD_Open;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
        Watts : Long_Float := 0.0;
    begin
        if not (Nvidia_Open or AMD_Open) then
            return (others => <>);
        end if;

        if Nvidia_Open then
            Watts := Watts + GPU_Nvidia_NVML.Get_Power;
        end if;

        if AMD_Open then
            Watts := Watts + GPU_AMD_Sysfs.Get_Power;
        end if;

        return (Available => True, Value => Watts, Unit => Power);
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        GPU_Nvidia_NVML.Close;
        GPU_AMD_Sysfs.Close;

        Nvidia_Open := False;
        AMD_Open := False;
    end Close;

end Joular_Core.GPU_Monitor;
