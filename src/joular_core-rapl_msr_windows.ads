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

-- This package is for RAPL for Windows (reading the MSR directly through a driver)
-- Reading a register needs a driver, and either of two is used: PawnIO first, and Hubblo's RAPL driver when PawnIO is not there or not supporting the processor
-- This package keeps the vendor detection and the counter abstract, and hands the reading of a single register to Joular_Core.MSR_PawnIO or Joular_Core.MSR_Hubblo
private package Joular_Core.RAPL_MSR_Windows is

    -- Open the RAPL counter (driver or files)
    -- Checks that PKG domain exists and can be read
    function Open return Boolean;

    -- Get the max energy range of the RAPL counter
    function Max_Energy_Range return Long_Long_Integer;

    -- Get a reading from the RAPL counter, as is, in microjoules
    function Read_Counter return Long_Long_Integer;

    -- Close driver on Windows, nothing on Linux
    procedure Close;

end Joular_Core.RAPL_MSR_Windows;
