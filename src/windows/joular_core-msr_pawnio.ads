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
with System.Storage_Elements; use System.Storage_Elements;

-- Reads model specific registers on Windows through the PawnIO driver
-- https://github.com/namazso/PawnIO
-- The driver reads no register on its own: a signed module saying which registers it lets through must be loaded first
private package Joular_Core.MSR_PawnIO is

    -- Open the driver and load Module into it
    -- Module is one of the modules of Joular_Core.PawnIO_Modules
    -- False if PawnIO is missing, the process is not elevated, or the module refuses this CPU
    -- Calling it again closes the driver first: a handle takes only one module
    function Open (Module : in Storage_Array) return Boolean;

    -- Read one register
    -- Returns False when the driver would not answer, leaving Value at zero
    function Read (MSR : in Interfaces.Unsigned_64; Value : out Interfaces.Unsigned_64) return Boolean;

    -- Close the driver, which unloads the module with it
    procedure Close;

end Joular_Core.MSR_PawnIO;
