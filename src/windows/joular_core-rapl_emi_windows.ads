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

-- RAPL energy through the Energy Meter Interface (EMI), built into Windows
-- https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface
-- On Windows 11 the processor driver publishes the RAPL domains as channels of this meter, so it is the same counter the MSR drivers read, handed over by Windows
-- Nothing to install, no administrator privileges
-- Only the package channel of the first socket is read: it already covers the cores and the integrated graphics
private package Joular_Core.RAPL_EMI_Windows is

    -- Find and open a meter publishing the RAPL package counter
    -- A meter publishing something else (a board rail, a battery) is refused and left to the MSR drivers
    -- Returns False when Windows publishes no such meter, as on Windows 10
    function Open return Boolean;

    -- Raw counter in microjoules, zero when the meter does not answer
    -- Windows hands over a 64-bit counter already unwrapped, which takes years to wrap at package power, so there is no wrap to correct
    function Read_Counter return Long_Long_Integer;

    -- Close the meter
    procedure Close;

end Joular_Core.RAPL_EMI_Windows;
