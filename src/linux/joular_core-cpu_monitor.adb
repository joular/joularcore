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

with Joular_Core.RAPL_Powercap;
with Joular_Core.RPI;

-- Linux: RAPL through powercap (Intel and AMD), otherwise the power models of Raspberry Pi and other boards
package body Joular_Core.CPU_Monitor is

    type Driver_Kind is (None, RAPL, Board_Model);

    Driver : Driver_Kind := None;

    --------------------------------------------------

    function Open return Boolean is
    begin
        -- RAPL first, the common case
        if RAPL_Powercap.Open then
            Driver := RAPL;
        elsif RPI.Open then
            Driver := Board_Model;

        else
            Driver := None;
        end if;

        return Driver /= None;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        case Driver is
            when RAPL =>
                return (Available => True, Value => RAPL_Powercap.Get_Energy, Unit => Energy);

            -- Board models give the average power since the last reading, not energy
            when Board_Model =>
                return (Available => True, Value => RPI.Get_Power, Unit => Power);

            when None =>
                return (others => <>);
        end case;
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        case Driver is
            when RAPL => RAPL_Powercap.Close;
            when Board_Model => RPI.Close;
            when None => null;
        end case;

        Driver := None;
    end Close;

end Joular_Core.CPU_Monitor;
