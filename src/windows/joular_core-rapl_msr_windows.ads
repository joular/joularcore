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

private package Joular_Core.RAPL_MSR_Windows is

    -- The drivers that can read the registers
    -- PawnIO is preferred: maintained, with signed modules; Hubblo's driver is not maintained anymore
    type Driver_Kind is (PawnIO, Hubblo);

    -- Open the RAPL counter of every package (socket) through Driver
    -- False, with the driver closed, if the processor has no RAPL registers or the driver gives no energy unit or a zero first reading
    function Open (Driver : in Driver_Kind) return Boolean;

    -- Energy consumed by all packages since the last reading, in joules; a package whose counter can't be read counts zero
    function Get_Energy return Long_Float;

    -- Close the driver
    procedure Close;

end Joular_Core.RAPL_MSR_Windows;
