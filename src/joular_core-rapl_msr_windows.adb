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

#if PJ_WINDOWS then

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Environment_Variables;

with Interfaces; use Interfaces;

with Joular_Core.MSR_Hubblo;
with Joular_Core.MSR_PawnIO;
with Joular_Core.OS_Utils; use Joular_Core.OS_Utils;
with Joular_Core.PawnIO_Modules;

#end if;

package body Joular_Core.RAPL_MSR_Windows is

#if PJ_WINDOWS then

    -- Registers holding the energy unit and package counters on Intel and AMD
    MSR_INTEL_RAPL_POWER_UNIT : constant Unsigned_64 := 16#606#;
    MSR_INTEL_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#611#;
    MSR_AMD_RAPL_POWER_UNIT : constant Unsigned_64 := 16#C001_0299#;
    MSR_AMD_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#C001_029B#;

    ENERGY_UNIT_BITS : constant Unsigned_64 := 16#1F00#; -- Bits 12:8 of the power unit register hold the energy unit
    ENERGY_UNIT_SHIFT : constant := 8; -- How far down to shift them
    ENERGY_COUNTER_BITS : constant Unsigned_64 := 16#FFFF_FFFF#; -- Only the low 32 bits of the energy register hold the counter, the rest is reserved

    -- The environment variable that picks one driver instead of trying both, which makes each one testable on a machine carrying both and gives a way out if one of them crashes or not working properly
    DRIVER_VARIABLE : constant String := "JOULARCORE_WINDOWS_RAPL";

    --------------------------------------------------

    -- Which driver is used to reach the registers
    -- PawnIO is preferred: it is maintained, its modules are signed and each one only lets through the registers it was built for, while Hubblo's driver is not maintained anymore
    type Driver_Kind is (None, PawnIO, Hubblo);

    -- Driver detected and used
    Driver : Driver_Kind := None;

    -- MSR to be read (Intel or AMD)
    Energy_MSR : Unsigned_64 := 0;

    -- MSR holding what one count of the counter is worth (Intel or AMD)
    Power_Unit_MSR : Unsigned_64 := 0;

    -- Whether the processor is an Intel one, which says which module PawnIO needs
    Vendor_Is_Intel : Boolean := False;

    -- What one count of the counter is worth
    -- Exponent is never negative, so we're using Natural type instead of Integer
    Energy_Exponent : Natural := 0;

    --------------------------------------------------

    -- Read one register through the named driver, rather than through whichever one was kept
    -- Named, so a driver still being tried can be read from without the package having to claim it first
    -- Returns zero if it cannot read
    function Read_One (Kind : in Driver_Kind; MSR : in Unsigned_64) return Unsigned_64 is
        Value : Unsigned_64 := 0;
        Read_Done : Boolean;
    begin
        case Kind is
            when PawnIO =>
                Read_Done := MSR_PawnIO.Read (MSR, Value);

            when Hubblo =>
                Read_Done := MSR_Hubblo.Read (MSR, Value);

            when None =>
                return 0;
        end case;

        if not Read_Done then
            return 0;
        end if;

        return Value;
    exception
        when others =>
            return 0;
    end Read_One;

    --------------------------------------------------

    -- Read one register using the driver that was kept
    function Read_MSR (MSR : in Unsigned_64) return Unsigned_64 is
       (Read_One (Driver, MSR));

    --------------------------------------------------

    -- Close the named driver, whether or not it is the one that was kept
    procedure Close_One (Kind : in Driver_Kind) is
    begin
        case Kind is
            when PawnIO =>
                MSR_PawnIO.Close;

            when Hubblo =>
                MSR_Hubblo.Close;

            when None =>
                null;
        end case;
    end Close_One;

    --------------------------------------------------

    -- Close whichever driver is open, without forgetting which registers this processor uses, so another driver can still be tried after it
    procedure Close_Driver is
    begin
        Close_One (Driver);

        Driver := None;
        Energy_Exponent := 0;
    end Close_Driver;

    --------------------------------------------------

    -- Open one driver and check it really answers: it has to give one reading, and a first reading that is not zero
    -- If not, close it and report failure, so the next driver can be tried
    -- Nothing the package keeps is written until all of that has gone through, so a driver that is only being tried never leaves the library half set up behind it
    function Try_Driver (Kind : in Driver_Kind) return Boolean is
        Opened : Boolean;
        Power_Unit : Unsigned_64;
        Exponent : Natural;
    begin
        case Kind is
            when PawnIO =>
                -- Each module only serves the vendor it was written for, and refuses to load on the other one
                if Vendor_Is_Intel then
                    Opened := MSR_PawnIO.Open (PawnIO_Modules.Intel_MSR);
                else
                    Opened := MSR_PawnIO.Open (PawnIO_Modules.AMD_Family17);
                end if;

            when Hubblo =>
                Opened := MSR_Hubblo.Open;

            when None =>
                Opened := False;
        end case;

        if not Opened then
            Close_One (Kind);
            return False;
        end if;

        -- Then, what one count of the RAPL counter is worth
        Power_Unit := Read_One (Kind, Power_Unit_MSR);
        Exponent := Natural (Shift_Right (Power_Unit and ENERGY_UNIT_BITS, ENERGY_UNIT_SHIFT));

        -- If the register can't be read or is empty, then close this driver and report failure
        if Exponent = 0 then
            Close_One (Kind);
            return False;
        end if;

        -- Then, take first reading and check it is not zero
        if (Read_One (Kind, Energy_MSR) and ENERGY_COUNTER_BITS) = 0 then
            Close_One (Kind);
            return False;
        end if;

        -- This one answered, so it is the one the package keeps
        Driver := Kind;
        Energy_Exponent := Exponent;
        return True;
    exception
        when others =>
            Close_One (Kind);
            return False;
    end Try_Driver;

    --------------------------------------------------

    -- Which drivers to try, and in which order
    -- Anything other than pawnio or hubblo, including nothing at all, tries PawnIO first and then Hubblo
    procedure Wanted_Drivers (Try_PawnIO : out Boolean; Try_Hubblo : out Boolean) is
    begin
        Try_PawnIO := True;
        Try_Hubblo := True;

        if not Ada.Environment_Variables.Exists (DRIVER_VARIABLE) then
            return;
        end if;

        declare
            Wanted : constant String := To_Lower (Ada.Environment_Variables.Value (DRIVER_VARIABLE));
        begin
            if Wanted = "pawnio" then
                Try_Hubblo := False;
            elsif Wanted = "hubblo" then
                Try_PawnIO := False;
            end if;
        end;
    exception
        -- Both are already set above, before anything that could bring us here
        when others =>
            null;
    end Wanted_Drivers;

    --------------------------------------------------

    function Open return Boolean is
        Vendor : constant String := Get_Platform_CPU_Name;
        Try_PawnIO : Boolean;
        Try_Hubblo : Boolean;
    begin
        -- First, check the vendor, and use proper registers
        if Vendor = "intel" then
            Power_Unit_MSR := MSR_INTEL_RAPL_POWER_UNIT;
            Energy_MSR := MSR_INTEL_PKG_ENERGY_STATUS;
            Vendor_Is_Intel := True;
        elsif Vendor = "amd" then
            Power_Unit_MSR := MSR_AMD_RAPL_POWER_UNIT;
            Energy_MSR := MSR_AMD_PKG_ENERGY_STATUS;
            Vendor_Is_Intel := False;
        else
            return False; -- No RAPL counter to look for on this processor
        end if;

        Wanted_Drivers (Try_PawnIO, Try_Hubblo);

        -- Then, try the drivers in turn and keep the first that answers
        -- They are rarely both installed, and a machine one of them refuses may still be served by the other: PawnIO turns down an AMD family its module was not built for, while Hubblo's driver has no such limit
        if Try_PawnIO and then Try_Driver (PawnIO) then
            return True;
        end if;

        if Try_Hubblo and then Try_Driver (Hubblo) then
            return True;
        end if;

        -- No driver answered
        Close;
        return False;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Max_Energy_Range return Long_Long_Integer is
    begin
        if Energy_Exponent = 0 then
            -- Nothing was recognized, so we don't know the max range
            return 0;
        end if;

        -- Counter is 32 bits wide, so it wraps after 2^32 counts, and one count is 1/2^Energy_Exponent of a joule: it therefore wraps at 2^(32 - Energy_Exponent) joules
        return 1_000_000 * 2 ** (32 - Energy_Exponent);
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
        Raw_Value : Unsigned_64;
    begin
        if Energy_Exponent = 0 then
            return 0;
        end if;

        -- Only the low 32 bits of the register hold the counter, the rest is reserved
        -- Masking keeps it inside 0 .. 2^32 - 1, which is the range the wrap correction assumes
        Raw_Value := Read_MSR (Energy_MSR) and ENERGY_COUNTER_BITS;

        if Raw_Value = 0 then
            return 0;
        end if;

        return Long_Long_Integer (Raw_Value) * 1_000_000 / 2 ** Energy_Exponent;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        Close_Driver;

        Energy_MSR := 0;
        Power_Unit_MSR := 0;
        Vendor_Is_Intel := False;
    end Close;

#else

    -- Driver for Windows only, so return 0 or nothing if called from another platform

    function Open return Boolean is
    begin
        return False;
    end Open;

    --------------------------------------------------

    function Max_Energy_Range return Long_Long_Integer is
    begin
        return 0;
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
    begin
        return 0;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.RAPL_MSR_Windows;
