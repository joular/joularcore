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

-- This package is for platforms with no RAPL support yet
package Joular_Core.RAPL_None is

    -- Open the RAPL counter (driver or files)
    -- Checks that PKG domain exists and can be read
    function Open return Boolean;
    
    -- Get the max energy range of the RAPL counter
    function Max_Energy_Range return Long_Long_Integer;
    
    -- Get a reading from the RAPL counter, as is, in microjoules
    function Read_Counter return Long_Long_Integer;
    
    -- Close driver on Windows, nothing on Linux
    procedure Close;

end Joular_Core.RAPL_None;
