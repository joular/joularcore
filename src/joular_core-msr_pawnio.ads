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
-- The driver knows no register on its own: it runs modules, and each module is signed and says which registers it lets through, so one has to be loaded into it before anything can be read
private package Joular_Core.MSR_PawnIO is

    -- Open the driver and load Module into it
    -- Module is one of the modules of Joular_Core.PawnIO_Modules
    -- The driver checks the signature of the module and runs its main, and that main refuses a machine the module was not made for, so this also returns False on a processor PawnIO cannot serve
    -- Returns False when the driver is not installed, not running, the program is not allowed to reach it, or the module was refused
    -- PawnIO only answers a program running as administrator, unlike Hubblo's driver, so this also returns False on a terminal that is not elevated
    -- Calling it again with the same module does nothing and returns True, and calling it with a different one loads that one instead
    function Open (Module : in Storage_Array) return Boolean;

    -- Read one register
    -- Returns False when the driver would not answer, leaving Value at zero
    function Read (MSR : in Interfaces.Unsigned_64; Value : out Interfaces.Unsigned_64) return Boolean;

    -- Close the driver, which unloads the module with it
    procedure Close;

end Joular_Core.MSR_PawnIO;
