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
with Interfaces.C; use type Interfaces.C.int;
with System;

with Joular_Core.Energy_Counters;
with Joular_Core.MSR_Hubblo;
with Joular_Core.MSR_PawnIO;
with Joular_Core.PawnIO_Modules;
with Joular_Core.Processor; use Joular_Core.Processor;
with Joular_Core.RAPL_MSR; use Joular_Core.RAPL_MSR;
with Joular_Core.Win32; use Joular_Core.Win32;

package body Joular_Core.RAPL_MSR_Windows is

    -- A driver reads a register on the processor running the thread, so the thread is pinned to one processor of each package
    Max_Groups : constant := 16; -- Processor groups of up to 64 processors
    Max_Packages : constant := 16;

    type Package_Reader is
       record
           Where : GROUP_AFFINITY := (Mask => 0, Group => 0, Reserved => (others => 0));
           Id : Natural := 0;
           Counter : Energy_Counters.Counter;
       end record;

    Packages : array (1 .. Max_Packages) of Package_Reader;
    Count : Natural := 0;

    Current_Driver : Driver_Kind := PawnIO;

    -- Intel or AMD
    Set : Register_Set;

    -- One count is 1/2^Exponent joules
    Exponent : Natural := 0;

    --------------------------------------------------

    -- Zero when the driver would not answer
    function Read_MSR (MSR : in Unsigned_32) return Unsigned_64 is
        Value : Unsigned_64;
        Read_Done : Boolean;
    begin
        case Current_Driver is
            when PawnIO => Read_Done := MSR_PawnIO.Read (Unsigned_64 (MSR), Value);
            when Hubblo => Read_Done := MSR_Hubblo.Read (Unsigned_64 (MSR), Value);
        end case;

        return (if Read_Done then Value else 0);
    end Read_MSR;

    --------------------------------------------------

    -- Pins the thread to the processor Where, keeping where it ran in Previous; False when there is no such processor
    function Pin (Where : in GROUP_AFFINITY; Previous : access GROUP_AFFINITY) return Boolean is
        Wanted : aliased GROUP_AFFINITY := Where;
    begin
        return SetThreadGroupAffinity (GetCurrentThread, Wanted'Address, Previous.all'Address) /= 0;
    end Pin;

    --------------------------------------------------

    procedure Unpin (Previous : in GROUP_AFFINITY) is
        Wanted : aliased GROUP_AFFINITY := Previous;
        Ignored : BOOL;
    begin
        Ignored := SetThreadGroupAffinity (GetCurrentThread, Wanted'Address, System.Null_Address);
    end Unpin;

    --------------------------------------------------

    -- The counter of one package, in microjoules, read on one of its processors; zero when it can't be
    function Read_Counter (Item : in Package_Reader) return Long_Long_Integer is
        Previous : aliased GROUP_AFFINITY;
        Value : Long_Long_Integer := 0;
    begin
        if Pin (Item.Where, Previous'Access) then
            Value := Microjoules (Read_MSR (Set.Energy_Status), Exponent);
            Unpin (Previous);
        end if;

        return Value;
    end Read_Counter;

    --------------------------------------------------

    function Open (Driver : in Driver_Kind) return Boolean is
        Opened : Boolean;
        Where : GROUP_AFFINITY := (Mask => 0, Group => 0, Reserved => (others => 0));
        Previous : aliased GROUP_AFFINITY;
        Id : Natural;
    begin
        Close;

        if not Registers (Set) then
            return False;
        end if;

        case Driver is
            when PawnIO =>
                -- A module refuses to load on the other vendor
                if Vendor = Intel then
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

        -- One processor of each package: the thread visits every processor in turn, until a group has none
        Groups : for Group in 0 .. Max_Groups - 1 loop
            Where.Group := Unsigned_16 (Group);

            for Bit in 0 .. DWORD_PTR'Size - 1 loop
                Where.Mask := 2 ** Bit;

                if not Pin (Where, Previous'Access) then
                    exit Groups when Bit = 0;
                    exit;
                end if;

                Id := Package_Here;
                Unpin (Previous);

                if Count < Max_Packages and then not (for some Item of Packages (1 .. Count) => Item.Id = Id) then
                    Count := Count + 1;
                    Packages (Count) := (Where => Where, Id => Id, others => <>);
                end if;
            end loop;
        end loop Groups;

        if Count = 0 then
            Close;
            return False;
        end if;

        -- The unit is the same on every package
        if Pin (Packages (1).Where, Previous'Access) then
            Exponent := Energy_Exponent (Read_MSR (Set.Power_Unit));
            Unpin (Previous);
        end if;

        for Item of Packages (1 .. Count) loop
            Item.Counter := (Last => Read_Counter (Item), Wrap_At => Wrap_At (Exponent), others => <>);
        end loop;

        -- No unit or a zero first reading: the driver isn't really reading
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
            Joules := Joules + Energy_Counters.Joules_Since_Last (Item.Counter, Read_Counter (Item));
        end loop;

        return Joules;
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        -- Both: a driver being tried is open before it is kept
        MSR_PawnIO.Close;
        MSR_Hubblo.Close;

        Packages := (others => <>);
        Count := 0;
        Exponent := 0;
    end Close;

end Joular_Core.RAPL_MSR_Windows;
