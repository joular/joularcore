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

with Joular_Core.MSR_Hubblo;
with Joular_Core.MSR_PawnIO;
with Joular_Core.PawnIO_Modules;
with Joular_Core.Processor; use Joular_Core.Processor;

package body Joular_Core.RAPL_MSR_Windows is

    -- Registers holding the energy unit and package counters on Intel and AMD
    MSR_INTEL_RAPL_POWER_UNIT : constant Unsigned_64 := 16#606#;
    MSR_INTEL_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#611#;
    MSR_AMD_RAPL_POWER_UNIT : constant Unsigned_64 := 16#C001_0299#;
    MSR_AMD_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#C001_029B#;

    ENERGY_UNIT_BITS : constant Unsigned_64 := 16#1F00#; -- Bits 12:8 of the power unit register hold the energy unit
    ENERGY_UNIT_SHIFT : constant := 8; -- How far down to shift them
    ENERGY_COUNTER_BITS : constant Unsigned_64 := 16#FFFF_FFFF#; -- Only the low 32 bits of the energy register hold the counter, the rest is reserved

    --------------------------------------------------

    Current_Driver : Driver_Kind := PawnIO;

    -- Intel or AMD
    Energy_MSR : Unsigned_64 := 0;

    -- One count is 1/2^Energy_Exponent joules
    Energy_Exponent : Natural := 0;

    --------------------------------------------------

    -- Zero when the driver would not answer
    function Read_MSR (MSR : in Unsigned_64) return Unsigned_64 is
        Value : Unsigned_64;
        Read_Done : Boolean;
    begin
        case Current_Driver is
            when PawnIO => Read_Done := MSR_PawnIO.Read (MSR, Value);
            when Hubblo => Read_Done := MSR_Hubblo.Read (MSR, Value);
        end case;

        return (if Read_Done then Value else 0);
    end Read_MSR;

    --------------------------------------------------

    function Open (Driver : in Driver_Kind) return Boolean is
        Vendor_Found : constant Vendor_Kind := Vendor;
        Power_Unit_MSR : Unsigned_64;
        Opened : Boolean;
    begin
        Close;

        case Vendor_Found is
            when Intel =>
                -- Silvermont/Airmont Atoms, whose energy unit would be read wrongly
                if Has_Unsupported_Energy_Unit then
                    return False;
                end if;

                Power_Unit_MSR := MSR_INTEL_RAPL_POWER_UNIT;
                Energy_MSR := MSR_INTEL_PKG_ENERGY_STATUS;

            when AMD =>
                Power_Unit_MSR := MSR_AMD_RAPL_POWER_UNIT;
                Energy_MSR := MSR_AMD_PKG_ENERGY_STATUS;

            when Unknown =>
                return False;
        end case;

        case Driver is
            when PawnIO =>
                -- A module refuses to load on the other vendor
                if Vendor_Found = Intel then
                    Opened := MSR_PawnIO.Open (PawnIO_Modules.Intel_MSR);
                else
                    Opened := MSR_PawnIO.Open (PawnIO_Modules.AMD_Family17);
                end if;

            when Hubblo =>
                Opened := MSR_Hubblo.Open;
        end case;

        if not Opened then
            Close;
            return False;
        end if;

        Current_Driver := Driver;

        Energy_Exponent := Natural (Shift_Right (Read_MSR (Power_Unit_MSR) and ENERGY_UNIT_BITS, ENERGY_UNIT_SHIFT));

        -- No unit or a zero first reading: the driver isn't really reading
        if Energy_Exponent = 0 or else Read_Counter = 0 then
            Close;
            return False;
        end if;

        return True;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Wrap_At return Long_Long_Integer is
    begin
        if Energy_Exponent = 0 then
            return 0;
        end if;

        -- 2^32 counts of 1/2^Energy_Exponent joules
        return 1_000_000 * 2 ** (32 - Energy_Exponent);
    end Wrap_At;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
        Raw_Value : Unsigned_64;
    begin
        if Energy_Exponent = 0 then
            return 0;
        end if;

        -- Keeps the value in 0 .. 2^32 - 1, as the wrap correction assumes
        Raw_Value := Read_MSR (Energy_MSR) and ENERGY_COUNTER_BITS;

        return Long_Long_Integer (Raw_Value) * 1_000_000 / 2 ** Energy_Exponent;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        -- Both: a driver being tried is open before it is kept
        MSR_PawnIO.Close;
        MSR_Hubblo.Close;

        Energy_MSR := 0;
        Energy_Exponent := 0;
    end Close;

end Joular_Core.RAPL_MSR_Windows;
