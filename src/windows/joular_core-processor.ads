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

-- Ask the processor about itself (with the CPUID instruction), to know which RAPL registers to read on Windows
-- CPUID only exists on x86 processors, so on others (e.g. ARM), the vendor is not known and no register is read
private package Joular_Core.Processor is

    -- The processor vendors with RAPL registers
    type Vendor_Kind is (Unknown, Intel, AMD);

    -- The vendor of the processor, or Unknown when it has no RAPL registers or cannot be asked
    function Vendor return Vendor_Kind;

    -- True on Silvermont/Airmont Atoms (models 37H, 4AH, 4CH, 5AH, 5DH), whose RAPL energy unit is 2^unit uJ instead of 1/2^unit J
    -- Only matters when reading the MSR directly (Linux and EMI cope); False when the processor cannot be asked
    function Has_Unsupported_Energy_Unit return Boolean;

end Joular_Core.Processor;
