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

-- RAPL energy counter of the PKG domain of the first socket, read from the registers of the processor through cpuctl(4)
-- Needs the cpuctl driver loaded (kldload cpuctl), and root or the kmem group, which the device belongs to
private package Joular_Core.RAPL_CPUCTL is

    -- Opens the device, reads the energy unit and takes a first reading; false when the processor has no RAPL registers or they cannot be read
    function Open return Boolean;

    -- Energy consumed since the last reading, in joules; zero when the counter can't be read
    function Get_Energy return Long_Float;

    -- Close the device
    procedure Close;

end Joular_Core.RAPL_CPUCTL;
