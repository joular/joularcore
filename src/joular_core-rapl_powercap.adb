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

with Joular_Core.File_Utils; use Joular_Core.File_Utils;

package body Joular_Core.RAPL_Powercap is

    -- RAPL domains in powercap sysfs
    -- The PKG domain of the main CPU socket is usually the first one (intel-rapl:0), but on a few machines another domain (i.e., psys) comes first, so the first ones are checked in order
    Powercap_Path : constant String := "/sys/class/powercap/intel-rapl:";
    Max_Domains : constant := 8;

    -- The files of the found PKG domain
    Energy_File : Unbounded_String;
    Max_Range_File : Unbounded_String;

    --------------------------------------------------

    -- Util function to read RAPL files (energy or max range file)
    function Read_Value (File_Name : in String) return Long_Long_Integer is
    begin
        return Long_Long_Integer'Value (Read_First_Line (File_Name));
    exception
        when others =>
            return 0;
    end Read_Value;

    --------------------------------------------------

    function Open return Boolean is
    begin
        -- Look for the PKG domain, which is the one named package-0 (package-X for other CPU sockets)
        for Number in 0 .. Max_Domains - 1 loop
            declare
                Domain : constant String := Powercap_Path & Trim (Natural'Image (Number), Left);
            begin
                if Index (Read_First_Line (Domain & "/name"), "package") = 1 then
                    Energy_File := To_Unbounded_String (Domain & "/energy_uj");
                    Max_Range_File := To_Unbounded_String (Domain & "/max_energy_range_uj");

                    -- Take first reading and check it is not zero
                    -- Reading the energy file needs root on most Linux systems
                    return Read_Value (To_String (Energy_File)) /= 0;
                end if;
            end;
        end loop;

        -- No PKG domain found, so no RAPL on this machine
        return False;
    end Open;

    --------------------------------------------------

    function Max_Energy_Range return Long_Long_Integer is
    begin
        return Read_Value (To_String (Max_Range_File));
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
    begin
        return Read_Value (To_String (Energy_File));
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        -- Nothing to close on Linux (no drivers), just forget the found files
        Energy_File := Null_Unbounded_String;
        Max_Range_File := Null_Unbounded_String;
    end Close;

end Joular_Core.RAPL_Powercap;
