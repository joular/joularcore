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

#if PJ_LINUX then
with Joular_Core.RAPL_Powercap; use Joular_Core.RAPL_Powercap;
#end if;

#if PJ_LINUX or PJ_WINDOWS or PJ_BSD then
with Joular_Core.RAPL_Type; use Joular_Core.RAPL_Type;
#end if;

package body Joular_Core.CPU_Monitor is

    -- CPU driver method to get energy/power readings
    type Driver_Kind is (None, Powercap, MSR_Linux, MSR_Windows, MSR_BSD, RPI_Models, Powermetrics);

    -- Driver detected and used
    Driver : Driver_Kind := None;

#if PJ_LINUX or PJ_WINDOWS or PJ_BSD then
    -- RAPL data of the PKG domain, on the main CPU socket
    -- Kept between readings, as the raw energy is the reference for the next reading
    CPU_RAPL_Data : RAPL_Data;
#end if;

    --------------------------------------------------

    function Detect_CPU return Boolean is
    begin
        Driver := None;

#if PJ_LINUX then

        -- Check if PowerCap accessible
        if Is_Accessible then
            Driver := Powercap;
        else
            Driver := None;
        end if;

        -- TODO: otherwise try MSR_Linux (in a future version)

#elsif PJ_WINDOWS then

        Driver := MSR_Windows;

        -- TODO: check is RAPL driver exist and can be read

#elsif PJ_MACOS then

        Driver := Powermetrics;

        -- TODO: check if powermetrics accessible and return power values

#elsif PJ_BSD then

        Driver := MSR_BSD;

        -- check if RAPL is accessible

#end if;

        return Driver /= None;
    end Detect_CPU;

    --------------------------------------------------

    procedure Start_Monitoring is
    begin
#if PJ_LINUX then

    if Driver = Powercap then
        -- Get max energy range for RAPL, called and read only once
        Get_Max_Energy_Range (CPU_RAPL_Data);

        -- First reading, useful to set the reference for RAPL cumulative counter for the next reading
        -- The calculated energy value is not valid and thus discarded
        Get_Energy (CPU_RAPL_Data);
    end if;

    -- TODO: MSR_Linux (in a future version)

#elsif PJ_WINDOWS then

    -- TODO: open the RAPL driver, get max range and do a first reading
    null;

#elsif PJ_MACOS then

    -- TODO: spawn the powermetrics process and get a first reading
    null;

#elsif PJ_BSD then

    -- TODO: MSR, get max range and do a first reading
    null;

#end if;
    end Start_Monitoring;

    --------------------------------------------------

    function Get_CPU_Reading return Measurement is
    begin

#if PJ_LINUX then

        if Driver = Powercap then
            Get_Energy (CPU_RAPL_Data);

            -- RAPL reports energy in microjoules, so divide it to get it in joules
            return (Available => True,
                    Value => Long_Float (CPU_RAPL_Data.PKG_Energy) / 1_000_000.0,
                    Unit => Energy);
        end if;

#end if;

        -- No driver available, nothing to read so return empty measurement
        return (others => <>);
    end Get_CPU_Reading;

end Joular_Core.CPU_Monitor;