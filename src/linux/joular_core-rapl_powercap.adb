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

    -- Each socket is a top-level domain intel-rapl:N named package-N; other domains (e.g. psys) can come first
    Powercap_Path : constant String := "/sys/class/powercap/intel-rapl:";
    Max_Domains : constant := 16;

    type Domain is
       record
           Energy_File : Unbounded_String;
           Counter : Energy_Counters.Counter;
       end record;

    Packages : array (1 .. Max_Domains) of Domain;
    Count : Natural := 0;

    --------------------------------------------------

    function Open return Boolean is
    begin
        Close;

        for Number in 0 .. Max_Domains - 1 loop
            declare
                Folder : constant String := Powercap_Path & Trim (Natural'Image (Number), Left);
                Item : Domain;
            begin
                if Index (Read_First_Line (Folder & "/name"), "package") = 1 then
                    Item.Energy_File := To_Unbounded_String (Folder & "/energy_uj");
                    Item.Counter := (Last => Read_Integer (Folder & "/energy_uj"),
                                     Wrap_At => Read_Integer (Folder & "/max_energy_range_uj"),
                                     others => <>);

                    -- energy_uj reads 0 without root on most systems
                    -- Without a valid max range a wrapped reading could only be dropped
                    if Item.Counter.Last > 0 and then Item.Counter.Wrap_At > 0 then
                        Count := Count + 1;
                        Packages (Count) := Item;
                    end if;
                end if;
            end;
        end loop;

        return Count > 0;
    end Open;

    --------------------------------------------------

    function Get_Energy return Long_Float is
        Joules : Long_Float := 0.0;
    begin
        for Item of Packages (1 .. Count) loop
            Joules := Joules + Energy_Counters.Joules_Since_Last (Item.Counter, Read_Integer (To_String (Item.Energy_File)));
        end loop;

        return Joules;
    end Get_Energy;

    --------------------------------------------------

    procedure Close is
    begin
        Count := 0;
    end Close;

end Joular_Core.RAPL_Powercap;
