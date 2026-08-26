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

with System;

-- Load a shared library (instead of linking to it)
-- The libraries are installed with the drivers of the GPU card (NVML for Nvidia, ADLX for AMD)
private package Joular_Core.Dynamic_Library is

    -- Load the shared library
    -- Returns the null address if the library is not installed
    function Load (Name : in String) return System.Address;

    -- Find a function from an already loaded library
    -- Returns the null address when the library does not have the function
    function Find_Symbol (Library : in System.Address; Name : in String) return System.Address;

    -- Unload the library
    procedure Unload (Library : in System.Address);

end Joular_Core.Dynamic_Library;
