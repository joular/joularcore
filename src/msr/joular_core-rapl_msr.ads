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

with Interfaces; use Interfaces;

-- What the RAPL registers of Intel and AMD processors hold, for the OSes reading them themselves (FreeBSD through cpuctl, Windows through a driver)
private package Joular_Core.RAPL_MSR is

    -- The registers holding the energy unit and the package counter, which Intel and AMD number differently
    type Register_Set is
       record
           Power_Unit : Unsigned_32 := 0;
           Energy_Status : Unsigned_32 := 0;
       end record;

    -- The registers of this processor; False when it has no RAPL registers, or its energy unit would be read wrongly
    function Registers (Set : out Register_Set) return Boolean;

    -- One count is 1/2^exponent joules: bits 12:8 of the power unit register
    function Energy_Exponent (Power_Unit : in Unsigned_64) return Natural;

    -- The counter in microjoules: only the low 32 bits of the energy register hold it, the rest is reserved
    function Microjoules (Energy_Status : in Unsigned_64; Exponent : in Natural) return Long_Long_Integer;

    -- The value, in microjoules, where the counter wraps back to zero: 2^32 counts
    function Wrap_At (Exponent : in Natural) return Long_Long_Integer;

end Joular_Core.RAPL_MSR;
