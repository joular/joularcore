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

-- This package is for RAPL for Windows, where the same counter can be reached in two ways:
-- 1) through the Energy Meter Interface, which is the meter Windows itself publishes and requires no installation, or 2) by reading the MSR registers directly through a driver
-- This package keeps which of the two answered, and hands the reading to Joular_Core.RAPL_EMI_Windows or Joular_Core.RAPL_MSR_Windows
private package Joular_Core.RAPL_Windows is

    -- Open the RAPL counter, trying each approach and keeping the first that answers
    function Open return Boolean;

    -- Get the max energy range of the RAPL counter
    function Max_Energy_Range return Long_Long_Integer;

    -- Get a reading from the RAPL counter, as is, in microjoules
    function Read_Counter return Long_Long_Integer;

    -- Close the approach used (driver or EMI)
    procedure Close;

end Joular_Core.RAPL_Windows;
