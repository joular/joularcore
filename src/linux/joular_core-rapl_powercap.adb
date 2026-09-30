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
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Joular_Core.Energy_Counters;
with Joular_Core.File_Utils; use Joular_Core.File_Utils;

package body Joular_Core.RAPL_Powercap is

    -- PKG is usually intel-rapl:0, but on some machines another domain (e.g. psys) comes first
    Powercap_Path : constant String := "/sys/class/powercap/intel-rapl:";
    Max_Domains : constant := 8;

    Energy_File : Unbounded_String;

    Counter : Energy_Counters.Counter;

    --------------------------------------------------

    function Open return Boolean is
    begin
        Close;

        -- PKG domains are named package-N, the first found is the main socket
        for Number in 0 .. Max_Domains - 1 loop
            declare
                Domain : constant String := Powercap_Path & Trim (Natural'Image (Number), Left);
            begin
                if Index (Read_First_Line (Domain & "/name"), "package") = 1 then
                    Energy_File := To_Unbounded_String (Domain & "/energy_uj");

                    Counter := (Last => Read_Integer (Domain & "/energy_uj"),
                                Wrap_At => Read_Integer (Domain & "/max_energy_range_uj"));

                    -- energy_uj reads 0 without root on most systems
                    -- Without a valid max range a wrapped reading could only be dropped
                    if Counter.Last = 0 or else Counter.Wrap_At <= 0 then
                        Close;
                        return False;
                    end if;

                    return True;
                end if;
            end;
        end loop;

        return False;
    end Open;

    --------------------------------------------------

    function Get_Energy return Long_Float is
    begin
        return Energy_Counters.Joules_Since_Last (Counter, Read_Integer (To_String (Energy_File)));
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        Energy_File := Null_Unbounded_String;
        Counter := (others => 0);
    end Close;

end Joular_Core.RAPL_Powercap;
