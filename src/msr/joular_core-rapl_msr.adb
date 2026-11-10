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

with Joular_Core.Processor; use Joular_Core.Processor;

package body Joular_Core.RAPL_MSR is

    MSR_INTEL_RAPL_POWER_UNIT : constant Unsigned_32 := 16#606#;
    MSR_INTEL_PKG_ENERGY_STATUS : constant Unsigned_32 := 16#611#;
    MSR_AMD_RAPL_POWER_UNIT : constant Unsigned_32 := 16#C001_0299#;
    MSR_AMD_PKG_ENERGY_STATUS : constant Unsigned_32 := 16#C001_029B#;

    --------------------------------------------------

    function Registers (Set : out Register_Set) return Boolean is
    begin
        Set := (others => <>);

        case Vendor is
            when Intel =>
                -- Silvermont/Airmont Atoms, whose energy unit would be read wrongly
                if Has_Unsupported_Energy_Unit then
                    return False;
                end if;

                Set := (MSR_INTEL_RAPL_POWER_UNIT, MSR_INTEL_PKG_ENERGY_STATUS);

            when AMD =>
                Set := (MSR_AMD_RAPL_POWER_UNIT, MSR_AMD_PKG_ENERGY_STATUS);

            when Unknown =>
                return False;
        end case;

        return True;
    end Registers;

    --------------------------------------------------

    function Energy_Exponent (Power_Unit : in Unsigned_64) return Natural is
        (Natural (Shift_Right (Power_Unit, 8) and 16#1F#));

    --------------------------------------------------

    function Microjoules (Energy_Status : in Unsigned_64; Exponent : in Natural) return Long_Long_Integer is
        (Long_Long_Integer (Energy_Status and 16#FFFF_FFFF#) * 1_000_000 / 2 ** Exponent);

    --------------------------------------------------

    function Wrap_At (Exponent : in Natural) return Long_Long_Integer is
        (1_000_000 * 2 ** (32 - Exponent));

end Joular_Core.RAPL_MSR;
