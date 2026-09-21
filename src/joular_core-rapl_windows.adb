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

with Joular_Core.RAPL_EMI_Windows;
with Joular_Core.RAPL_MSR_Windows;

#end if;

package body Joular_Core.RAPL_Windows is

#if PJ_WINDOWS then

    -- The environment variable that selects the driver to use
    -- The same variable also tells the two drivers reaching the registers apart, which Joular_Core.RAPL_MSR_Windows reads on its own
    DRIVER_VARIABLE : constant String := "JOULARCORE_WINDOWS_RAPL";

    --------------------------------------------------

    -- How the RAPL counter is accessed
    -- The meter Windows publishes (EMI) is preferred: no driver needed or admin rights, while the MSR registers need a driver installed and, for PawnIO, an elevated terminal
    type Reader_Kind is (None, EMI, MSR);

    -- The approach used
    Reader : Reader_Kind := None;

    --------------------------------------------------

    -- Close the named way, whether or not it is the one that was kept
    procedure Close_One (Kind : in Reader_Kind) is
    begin
        case Kind is
            when EMI =>
                RAPL_EMI_Windows.Close;

            when MSR =>
                RAPL_MSR_Windows.Close;

            when None =>
                null;
        end case;
    end Close_One;

    --------------------------------------------------

    -- Open one way and keep it when it answers
    -- Each of the two checks on its own that the counter is there and can be read, and closes itself when it is not, so there is nothing more to check here
    function Try_Reader (Kind : in Reader_Kind) return Boolean is
        Opened : Boolean;
    begin
        case Kind is
            when EMI =>
                Opened := RAPL_EMI_Windows.Open;

            when MSR =>
                Opened := RAPL_MSR_Windows.Open;

            when None =>
                Opened := False;
        end case;

        if not Opened then
            Close_One (Kind);
            return False;
        end if;

        Reader := Kind;
        return True;
    exception
        when others =>
            Close_One (Kind);
            return False;
    end Try_Reader;

    --------------------------------------------------

    -- Which approach to try, and in which order
    -- If an approach is named in the env variable, then use it, otherwise try first EMI, then the MSR drivers
    procedure Wanted_Readers (Try_EMI : out Boolean; Try_MSR : out Boolean) is
    begin
        Try_EMI := True;
        Try_MSR := True;

        if not Ada.Environment_Variables.Exists (DRIVER_VARIABLE) then
            return;
        end if;

        declare
            Wanted : constant String := To_Lower (Ada.Environment_Variables.Value (DRIVER_VARIABLE));
        begin
            if Wanted = "emi" then
                Try_MSR := False;
            elsif Wanted = "pawnio" or else Wanted = "hubblo" then
                Try_EMI := False;
            end if;
        end;
    exception
        when others =>
            null;
    end Wanted_Readers;

    --------------------------------------------------

    function Open return Boolean is
        Try_EMI : Boolean;
        Try_MSR : Boolean;
    begin
        -- Opening again while one is already open would leave that one behind, so close first
        Close;

        Wanted_Readers (Try_EMI, Try_MSR);

        -- Then, try them in turn and keep the first that answers
        -- EMI is tried first as it asks for no drivers or rights: it is turned down on a machine where Windows publishes no such meter, or where the meter it publishes measures something other than the processor package, and the registers are then read as they were before
        if Try_EMI and then Try_Reader (EMI) then
            return True;
        end if;

        if Try_MSR and then Try_Reader (MSR) then
            return True;
        end if;

        -- Neither answered
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
        case Reader is
            when EMI =>
                return RAPL_EMI_Windows.Max_Energy_Range;

            when MSR =>
                return RAPL_MSR_Windows.Max_Energy_Range;

            when None =>
                -- Nothing was opened, so we don't know the max range
                return 0;
        end case;
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
    begin
        case Reader is
            when EMI =>
                return RAPL_EMI_Windows.Read_Counter;

            when MSR =>
                return RAPL_MSR_Windows.Read_Counter;

            when None =>
                return 0;
        end case;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        -- Close all drivers
        Close_One (EMI);
        Close_One (MSR);

        Reader := None;
    end Close;

#else

    -- Windows only, so return 0 or nothing if called from another platform

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

end Joular_Core.RAPL_Windows;
