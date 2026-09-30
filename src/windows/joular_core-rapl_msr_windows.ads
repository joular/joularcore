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

-- RAPL on Windows, reading the MSR directly through a driver: PawnIO or Hubblo's
-- Vendor detection and the counter live here; the single register read is done by Joular_Core.MSR_PawnIO or Joular_Core.MSR_Hubblo
private package Joular_Core.RAPL_MSR_Windows is

    -- The drivers that can read the registers
    -- PawnIO is preferred: maintained, with signed modules; Hubblo's driver is not maintained anymore
    type Driver_Kind is (PawnIO, Hubblo);

    -- Open the RAPL counter through Driver
    -- False, with the driver closed, if the processor has no RAPL registers or the driver gives no energy unit or a zero first reading
    function Open (Driver : in Driver_Kind) return Boolean;

    -- Get a reading from the RAPL counter, as is, in microjoules
    -- Returns zero when the counter cannot be read
    function Read_Counter return Long_Long_Integer;

    -- The value, in microjoules, where the counter wraps back to zero
    function Wrap_At return Long_Long_Integer;

    -- Close the driver
    procedure Close;

end Joular_Core.RAPL_MSR_Windows;
