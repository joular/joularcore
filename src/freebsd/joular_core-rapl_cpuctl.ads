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

private package Joular_Core.RAPL_CPUCTL is

    -- Opens one device per package (socket), reads the energy unit and takes a first reading of each
    -- False when the processor has no RAPL registers or they cannot be read
    function Open return Boolean;

    -- Energy consumed by all packages since the last reading, in joules; a package whose counter can't be read counts zero
    function Get_Energy return Long_Float;

    -- Close the devices
    procedure Close;

end Joular_Core.RAPL_CPUCTL;
