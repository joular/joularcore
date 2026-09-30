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

-- RAPL energy counter of the PKG domain of the main CPU socket, through powercap sysfs
private package Joular_Core.RAPL_Powercap is

    -- Finds the PKG domain and takes a first reading, false when none can be read
    function Open return Boolean;

    -- Energy consumed since the last reading, in joules; zero when the counter can't be read
    function Get_Energy return Long_Float;

    -- Forgets the domain found, nothing to release
    procedure Close;

end Joular_Core.RAPL_Powercap;
