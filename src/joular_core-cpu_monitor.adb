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
with Joular_Core.RPI; use Joular_Core.RPI;
with Joular_Core.Powermetrics; use Joular_Core.Powermetrics;

package body Joular_Core.CPU_Monitor is

    -- CPU driver method to get energy/power readings
    type Driver_Kind is (None, RAPL_Counter, RPI_Models, Apple_Powermetrics);

    -- Driver detected and used
    Driver : Driver_Kind := None;

    --------------------------------------------------

    function Detect_CPU (Platform : in String) return Boolean is
    begin
        Driver := None;

        -- Check Apple Silicon first, as it is the only CPU of the Macs supported and has neither RAPL nor a board model
        if Platform = "apple" and then Powermetrics.Is_Accessible then
            Driver := Apple_Powermetrics;
            return True;
        end if;

        -- Check RAPL first (most common usecase)
        if Platform /= "rpi" and then RAPL.Is_Accessible then
            Driver := RAPL_Counter;
            return True;
        end if;

        -- No RAPL, then check for Raspberry Pi and other board models
        -- Only boards running Linux have a model, so this simply finds nothing on other OSes
        if RPI.Is_Accessible then
            Driver := RPI_Models;
            return True;
        end if;

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

        if Driver = RPI_Models then
            -- Raspberry Pi models estimate the power drawn since the last reading, in watts
            return (Available => True,
                    Value => RPI.Get_Power,
                    Unit => Power);
        end if;

        if Driver = Apple_Powermetrics then
            -- powermetrics reports the power drawn by the CPU of the chip over its last sample, in watts
            return (Available => True,
                    Value => Powermetrics.Get_CPU_Power,
                    Unit => Power);
        end if;

        -- No driver available, nothing to read so return empty measurement
        return (others => <>);
    end Get_CPU_Reading;

    --------------------------------------------------

    procedure Stop_Monitoring is
    begin
        if Driver = RAPL_Counter then
            RAPL.Close;
        end if;

        if Driver = RPI_Models then
            RPI.Close;
        end if;

        if Driver = Apple_Powermetrics then
            Powermetrics.Close;
        end if;

        Driver := None;
    end Stop_Monitoring;

end Joular_Core.CPU_Monitor;
