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

with Joular_Core.RAPL_Windows;

-- Windows: RAPL (Intel and AMD) through the Energy Meter Interface, PawnIO, or Hubblo's driver
package body Joular_Core.CPU_Monitor is

    function Open return Boolean is
    begin
        return RAPL_Windows.Open;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        return (Available => True, Value => RAPL_Windows.Get_Energy, Unit => Energy);
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        RAPL_Windows.Close;
    end Close;

end Joular_Core.CPU_Monitor;
