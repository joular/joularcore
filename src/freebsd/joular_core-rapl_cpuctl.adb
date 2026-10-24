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

with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Interfaces; use Interfaces;
with Interfaces.C; use Interfaces.C;
with GNAT.OS_Lib; use GNAT.OS_Lib;

with Joular_Core.Energy_Counters;
with Joular_Core.Processor;
with Joular_Core.RAPL_MSR; use Joular_Core.RAPL_MSR;

package body Joular_Core.RAPL_CPUCTL is

    -- One device per processor; the first processor of each package is kept
    Device_Path : constant String := "/dev/cpuctl";
    Max_Processors : constant := 1024;
    Max_Packages : constant := 16;

    -- CPUCTL_RDMSR and CPUCTL_CPUID_COUNT of sys/cpuctl.h: _IOWR ('c', 1, cpuctl_msr_args_t) and _IOWR ('c', 4, cpuctl_cpuid_count_args_t)
    CPUCTL_RDMSR : constant unsigned_long := 16#C010_6301#;
    CPUCTL_CPUID_COUNT : constant unsigned_long := 16#C018_6304#;

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

    -- cpuctl_cpuid_count_args_t: the leaf and subleaf asked for, and the four registers the processor answers with (EAX, EBX, ECX, EDX)
    type Answer is array (0 .. 3) of Unsigned_32
       with Convention => C;

    type CPUID_Args is
       record
           Level : int := 0;
           Level_Type : int := 0;
           Data : Answer := (others => 0);
       end record
       with Convention => C;

    -- ioctl takes its arguments after the request as a C function with a variable number of them
    function IOCtl (Device : in File_Descriptor; Request : in unsigned_long; Args : access MSR_Args) return int
        with Import, Convention => C_Variadic_2, External_Name => "ioctl";

    function IOCtl (Device : in File_Descriptor; Request : in unsigned_long; Args : access CPUID_Args) return int
        with Import, Convention => C_Variadic_2, External_Name => "ioctl";

    --------------------------------------------------

    type Package_Reader is
       record
           Device : File_Descriptor := Invalid_FD;
           Id : Natural := 0;
           Counter : Energy_Counters.Counter;
       end record;

    Packages : array (1 .. Max_Packages) of Package_Reader;
    Count : Natural := 0;

    -- Intel or AMD
    Set : Register_Set;

    -- One count is 1/2^Exponent joules
    Exponent : Natural := 0;

    --------------------------------------------------

    -- Zero when the register can't be read
    function Read_MSR (Device : in File_Descriptor; MSR : in Unsigned_32) return Unsigned_64 is
        Args : aliased MSR_Args := (MSR => MSR, Data => 0);
    begin
        if IOCtl (Device, CPUCTL_RDMSR, Args'Access) /= 0 then
            return 0;
        end if;

        return Args.Data;
    end Read_MSR;

    --------------------------------------------------

    -- The package of the processor behind Device, asked with leaf 0BH; zero when it has no such leaf
    function Package_Of (Device : in File_Descriptor) return Natural is
        Args : aliased CPUID_Args;
    begin
        -- Leaf 0 says how far the leaves go
        if IOCtl (Device, CPUCTL_CPUID_COUNT, Args'Access) /= 0 or else Args.Data (0) < 16#B# then
            return 0;
        end if;

        Args := (Level => 16#B#, Level_Type => 1, others => <>);

        if IOCtl (Device, CPUCTL_CPUID_COUNT, Args'Access) /= 0 then
            return 0;
        end if;

        return Processor.Package_Of (Args.Data (0), Args.Data (1), Args.Data (3));
    end Package_Of;

    --------------------------------------------------

    function Read_Counter (Device : in File_Descriptor) return Long_Long_Integer is
        (Microjoules (Read_MSR (Device, Set.Energy_Status), Exponent));

    --------------------------------------------------

    function Open return Boolean is
        Device : File_Descriptor;
        Id : Natural;
    begin
        Close;

        if not Registers (Set) then
            return False;
        end if;

        -- Reading needs no write access to the devices, which belong to root and the kmem group
        -- The devices stop where the processors do
        for Number in 0 .. Max_Processors - 1 loop
            Device := Open_Read (Device_Path & Trim (Natural'Image (Number), Left), Binary);

            exit when Device = Invalid_FD;

            Id := Package_Of (Device);

            if Count = Max_Packages or else (for some Item of Packages (1 .. Count) => Item.Id = Id) then
                GNAT.OS_Lib.Close (Device);
            else
                Count := Count + 1;
                Packages (Count) := (Device => Device, Id => Id, others => <>);
            end if;
        end loop;

        if Count = 0 then
            return False;
        end if;

        -- The unit is the same on every package
        Exponent := Energy_Exponent (Read_MSR (Packages (1).Device, Set.Power_Unit));

        for Item of Packages (1 .. Count) loop
            Item.Counter := (Last => Read_Counter (Item.Device), Wrap_At => Wrap_At (Exponent), others => <>);
        end loop;

        -- No unit or a zero first reading: the processor has no such register
        if Exponent = 0 or else Packages (1).Counter.Last = 0 then
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
        Joules : Long_Float := 0.0;
    begin
        for Item of Packages (1 .. Count) loop
            Joules := Joules + Energy_Counters.Joules_Since_Last (Item.Counter, Read_Counter (Item.Device));
        end loop;

        return Joules;
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        for Item of Packages (1 .. Count) loop
            GNAT.OS_Lib.Close (Item.Device);
        end loop;

        Packages := (others => <>);
        Count := 0;
        Exponent := 0;
    end Close;

end Joular_Core.RAPL_CPUCTL;
