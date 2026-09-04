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

-- Get RAPL energy using the Energy Meter Interface (EMI), which is part of Windows itself
-- https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface
-- On Windows 11, the processor driver publishes the RAPL domains of the processor as the channels of such meter, so the counter read here is the very one the two register drivers read, only handed over by Windows instead of being taken from the register
-- Nothing has to be installed for it, and runs without administrator privileges
-- Only the channel of the package domain of the first socket is read, which is what the library reports: the package domain already covers the cores and the integrated graphics, so the channels are never added up
private package Joular_Core.RAPL_EMI_Windows is

    -- Find a meter publishing the RAPL package counter and open it
    -- Refuses a meter that publishes something else, so a machine carrying a meter of its own (a board rail, a battery) is left to the MSR drivers reaching the registers rather than having that meter reported as the processor
    -- Returns False when Windows publishes no such meter, which is the case on Windows 10 and on a processor whose driver does not publish one
    function Open return Boolean;

    -- Get the max energy range of the RAPL counter
    function Max_Energy_Range return Long_Long_Integer;

    -- Get a reading from the RAPL counter, as is, in microjoules
    function Read_Counter return Long_Long_Integer;

    -- Close the meter
    procedure Close;

end Joular_Core.RAPL_EMI_Windows;
