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

end Joular_Core.OS_Utils;
