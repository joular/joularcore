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

-- RAPL on Windows, where the same counter can be reached three ways: the Energy Meter Interface (EMI) built into Windows, the MSR registers through the PawnIO driver, or through Hubblo's RAPL driver
-- Keeps which one answered, reads through Joular_Core.RAPL_EMI_Windows or Joular_Core.RAPL_MSR_Windows, and turns the counter into energy
-- Only reads the PKG domain of the main CPU socket
private package Joular_Core.RAPL_Windows is

    -- Open the RAPL counter with the first approach that answers
    -- JOULARCORE_WINDOWS_RAPL (emi, pawnio or hubblo) picks one instead
    -- Takes a first reading so the next one can report the energy since
    function Open return Boolean;

    -- Energy consumed since the last reading, in joules
    -- Returns zero when the counter cannot be read
    function Get_Energy return Long_Float;

    -- Close the approach used (driver or EMI)
    procedure Close;

end Joular_Core.RAPL_Windows;
