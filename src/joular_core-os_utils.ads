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

private package Joular_Core.OS_Utils is

    -- Get the CPU vendor (Intel/AMD) or the board name (for Raspberry Pi)
    -- Values: intel, amd, rpi, apple (for Apple Silicon only)
    -- Returns empty String is no supported platform found or can't read model or CPU vendor
    function Get_Platform_CPU_Name return String;

    -- Whether the processor counts the energy of its RAPL register in a supported unit
    -- The Silvermont generation of Atom counts one step of that register as 2^unit microjoules, where every other Intel and AMD processor counts it as 1/2^unit joules
    -- Therefore, such processor is turned down rather than read wrongly, and this is only True for Windows when reading RAPL directly with a driver
    --  Linux and EMI on Windows don't have this issue
    -- Always False when the processor cannot be asked, which is every platform where the registers are not read directly anyway
    function Has_Unsupported_Energy_Unit return Boolean;

end Joular_Core.OS_Utils;
