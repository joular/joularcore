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

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Environment_Variables;

with Joular_Core.Energy_Counters;
with Joular_Core.RAPL_EMI_Windows;
with Joular_Core.RAPL_MSR_Windows; use Joular_Core.RAPL_MSR_Windows;

package body Joular_Core.RAPL_Windows is

    -- Picks one approach, to test each on a machine carrying several or to work around a broken one
    Choice_Variable : constant String := "JOULARCORE_WINDOWS_RAPL";

    type Choice_Kind is (Any, Only_EMI, Only_PawnIO, Only_Hubblo);

    type Reader_Kind is (None, EMI, MSR);

    Reader : Reader_Kind := None;

    -- The EMI counter; the MSR packages keep their own
    Counter : Energy_Counters.Counter;

    --------------------------------------------------

    -- Any value other than emi, pawnio or hubblo, or none, tries every approach
    function Choice return Choice_Kind is
        Name : constant String := To_Lower (Ada.Environment_Variables.Value (Choice_Variable, Default => ""));
    begin
        if Name = "emi" then
            return Only_EMI;
        elsif Name = "pawnio" then
            return Only_PawnIO;
        elsif Name = "hubblo" then
            return Only_Hubblo;
        else
            return Any;
        end if;
    end Choice;

    --------------------------------------------------

    function Open return Boolean is
        Wanted : constant Choice_Kind := Choice;
    begin
        -- Close any reader already open
        Close;

        -- EMI first: no driver, no admin rights (PawnIO needs an elevated terminal)
        -- The two drivers are rarely both installed; PawnIO refuses an AMD family its module was not built for, Hubblo does not
        if Wanted in Any | Only_EMI and then RAPL_EMI_Windows.Open then
            Reader := EMI;
            -- Windows already unwraps the counter
            Counter := (Last => RAPL_EMI_Windows.Read_Counter, Wrap_At => 0, others => <>);
            return True;
        end if;

        if (Wanted in Any | Only_PawnIO and then RAPL_MSR_Windows.Open (PawnIO))
           or else (Wanted in Any | Only_Hubblo and then RAPL_MSR_Windows.Open (Hubblo))
        then
            Reader := MSR;
            return True;
        end if;

        Close;
        return False;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Get_Energy return Long_Float is
    begin
        case Reader is
            when EMI => return Energy_Counters.Joules_Since_Last (Counter, RAPL_EMI_Windows.Read_Counter);
            when MSR => return RAPL_MSR_Windows.Get_Energy;
            when None => return 0.0;
        end case;
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        RAPL_EMI_Windows.Close;
        RAPL_MSR_Windows.Close;

        Reader := None;
        Counter := (others => <>);
    end Close;

end Joular_Core.RAPL_Windows;
