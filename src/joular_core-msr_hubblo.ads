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

with Interfaces;

-- Reads model specific registers on Windows through Hubblo's RAPL driver
-- https://github.com/hubblo-org/windows-rapl-driver
-- The driver knows the registers of RAPL and only lets those through, so there is nothing to load into it: opening the device is enough
private package Joular_Core.MSR_Hubblo is

    -- Open the driver
    -- Returns False when it is not installed, not running, or the program is not allowed to reach it
    -- Calling it again while it is open does nothing and returns True
    function Open return Boolean;

    -- Read one register
    -- Returns False when the driver would not answer, leaving Value at zero
    function Read (MSR : in Interfaces.Unsigned_64; Value : out Interfaces.Unsigned_64) return Boolean;

    -- Close the driver
    procedure Close;

end Joular_Core.MSR_Hubblo;
