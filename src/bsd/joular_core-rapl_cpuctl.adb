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
with Interfaces.C; use Interfaces.C;
with GNAT.OS_Lib; use GNAT.OS_Lib;

with Joular_Core.Energy_Counters;
with Joular_Core.Processor; use Joular_Core.Processor;

package body Joular_Core.RAPL_CPUCTL is

    -- The first processor, so the package of the first socket
    Device_Name : constant String := "/dev/cpuctl0";

    -- Registers holding the energy unit and package counter on Intel and AMD
    MSR_INTEL_RAPL_POWER_UNIT : constant Unsigned_32 := 16#606#;
    MSR_INTEL_PKG_ENERGY_STATUS : constant Unsigned_32 := 16#611#;
    MSR_AMD_RAPL_POWER_UNIT : constant Unsigned_32 := 16#C001_0299#;
    MSR_AMD_PKG_ENERGY_STATUS : constant Unsigned_32 := 16#C001_029B#;

    -- CPUCTL_RDMSR of sys/cpuctl.h: _IOWR ('c', 1, cpuctl_msr_args_t)
    CPUCTL_RDMSR : constant unsigned_long := 16#C010_6301#;

    -- cpuctl_msr_args_t: the register to read, and what it holds
    type MSR_Args is
       record
           MSR : Unsigned_32 := 0;
           Data : Unsigned_64 := 0;
       end record
       with Convention => C;

    for MSR_Args use
       record
           MSR at 0 range 0 .. 31;
           Data at 8 range 0 .. 63;
       end record;

    for MSR_Args'Size use 128;

    -- ioctl takes its arguments after the request as a C function with a variable number of them
    function IOCtl (Device : in File_Descriptor; Request : in unsigned_long; Args : access MSR_Args) return int
        with Import, Convention => C_Variadic_2, External_Name => "ioctl";

    --------------------------------------------------

    Device : File_Descriptor := Invalid_FD;

    -- Intel or AMD
    Energy_MSR : Unsigned_32 := 0;

    -- One count is 1/2^Energy_Exponent joules
    Energy_Exponent : Natural := 0;

    Counter : Energy_Counters.Counter;

    --------------------------------------------------

    -- Zero when the register can't be read
    function Read_MSR (MSR : in Unsigned_32) return Unsigned_64 is
        Args : aliased MSR_Args := (MSR => MSR, Data => 0);
    begin
        if IOCtl (Device, CPUCTL_RDMSR, Args'Access) /= 0 then
            return 0;
        end if;

        return Args.Data;
    end Read_MSR;

    --------------------------------------------------

    -- The counter in microjoules: only the low 32 bits of the register hold it, the rest is reserved
    function Read_Counter return Long_Long_Integer is
        (Long_Long_Integer (Read_MSR (Energy_MSR) and 16#FFFF_FFFF#) * 1_000_000 / 2 ** Energy_Exponent);

    --------------------------------------------------

    function Open return Boolean is
        Power_Unit_MSR : Unsigned_32;
    begin
        Close;

        case Vendor is
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

        -- Reading needs no write access to the device, which belongs to root and the kmem group
        Device := Open_Read (Device_Name, Binary);

        if Device = Invalid_FD then
            return False;
        end if;

        -- Bits 12:8 of the power unit register hold the energy unit
        Energy_Exponent := Natural (Shift_Right (Read_MSR (Power_Unit_MSR), 8) and 16#1F#);

        -- 2^32 counts of 1/2^Energy_Exponent joules
        Counter := (Last => Read_Counter, Wrap_At => 1_000_000 * 2 ** (32 - Energy_Exponent));

        -- No unit or a zero first reading: the processor has no such register
        if Energy_Exponent = 0 or else Counter.Last = 0 then
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

    function Get_Energy return Long_Float is
    begin
        return Energy_Counters.Joules_Since_Last (Counter, Read_Counter);
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        if Device /= Invalid_FD then
            GNAT.OS_Lib.Close (Device);
        end if;

        Device := Invalid_FD;
        Energy_MSR := 0;
        Energy_Exponent := 0;
        Counter := (others => 0);
    end Close;

end Joular_Core.RAPL_CPUCTL;
