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

-- Read RAPL energy counter for supported platforms
-- Only reads PKG domain of the main CPU socket

package Joular_Core.RAPL is

    -- Check if RAPL counter can be read on machine (file or MSR)
    -- Opens driver when needed (Windows)
    -- Also takes one reading so the next reading can calculate consumed energy since this one
    function Is_Accessible return Boolean;

    -- Get energy consumed since the last reading, in microjoules
    -- Returns zero when the counter cannot be read
    function Get_Energy return Long_Long_Integer;

    -- Close driver on Windows, nothing on Linux
    procedure Close;

end Joular_Core.RAPL;
