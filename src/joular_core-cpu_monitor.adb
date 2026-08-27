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

with Joular_Core.RAPL; use Joular_Core.RAPL;

#if PJ_LINUX then
with Joular_Core.RPI; use Joular_Core.RPI;
#end if;

package body Joular_Core.CPU_Monitor is

    -- CPU driver method to get energy/power readings
    type Driver_Kind is (None, RAPL_Counter, RPI_Models); --, Powermetrics);

    -- Driver detected and used
    Driver : Driver_Kind := None;

    --------------------------------------------------

    function Detect_CPU (Platform : in String) return Boolean is
    begin
        Driver := None;

        -- Check RAPL first (most common usecase)
        if Platform /= "rpi" and then RAPL.Is_Accessible then
            Driver := RAPL_Counter;
            return True;
        end if;

#if PJ_LINUX then

        -- On Linux, but no RAPL, then check for Raspberry Pi models
        if RPI.Is_Accessible then
            Driver := RPI_Models;
            return True;
        end if;

#elsif PJ_MACOS then

        -- Driver := Powermetrics;

        -- TODO: check if powermetrics accessible and return power values

#end if;

        return Driver /= None;
    end Detect_CPU;

    --------------------------------------------------

    function Get_CPU_Reading return Measurement is
    begin
        if Driver = RAPL_Counter then
            -- RAPL reports energy in microjoules, so divide it to get it in joules
            return (Available => True,
                    Value => Long_Float (RAPL.Get_Energy) / 1_000_000.0,
                    Unit => Energy);
        end if;

#if PJ_LINUX then
        if Driver = RPI_Models then
            -- Raspberry Pi models estimate the power drawn since the last reading, in watts
            return (Available => True,
                    Value => RPI.Get_Power,
                    Unit => Power);
        end if;
#end if;

        -- No driver available, nothing to read so return empty measurement
        return (others => <>);
    end Get_CPU_Reading;

    --------------------------------------------------

    procedure Stop_Monitoring is
    begin
        if Driver = RAPL_Counter then
            RAPL.Close;
        end if;

#if PJ_LINUX then
        if Driver = RPI_Models then
            RPI.Close;
        end if;
#end if;

        Driver := None;
    end Stop_Monitoring;

end Joular_Core.CPU_Monitor;
