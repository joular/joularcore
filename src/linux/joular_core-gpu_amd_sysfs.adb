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

package body Joular_Core.GPU_AMD_Sysfs is

    Hwmon_Path : constant String := "/sys/class/hwmon";

    Driver_Name : constant String := "amdgpu";

    -- Checked in this order, the average over the last moment is preferred to an instant reading
    Average_File : constant String := "power1_average";
    Instant_File : constant String := "power1_input";

    Max_Sensors : constant := 64;

    -- The power file of every card
    Power_Files : array (1 .. Max_Sensors) of Unbounded_String;
    Count : Natural := 0;

    --------------------------------------------------

    -- Empty string when the sensor has no readable power file
    function Power_File_Of (Folder : in String) return String is
    begin
        if Read_First_Line (Folder & "/" & Average_File) /= "" then
            return Folder & "/" & Average_File;
        end if;

        if Read_First_Line (Folder & "/" & Instant_File) /= "" then
            return Folder & "/" & Instant_File;
        end if;

        return "";
    end Power_File_Of;

    --------------------------------------------------

    function Open return Boolean is
    begin
        Close;

        for Number in 0 .. Max_Sensors - 1 loop
            declare
                Folder : constant String := Hwmon_Path & "/hwmon" & Trim (Natural'Image (Number), Left);
            begin
                if Read_First_Line (Folder & "/name") = Driver_Name and then Power_File_Of (Folder) /= "" then
                    Count := Count + 1;
                    Power_Files (Count) := To_Unbounded_String (Power_File_Of (Folder));
                end if;
            end;
        end loop;

        return Count > 0;
    end Open;

    --------------------------------------------------

    function Get_Power return Long_Float is
        Watts : Long_Float := 0.0;
    begin
        -- hwmon reports microwatts; a file reads 0 when its card stops answering
        for File of Power_Files (1 .. Count) loop
            Watts := Watts + Long_Float (Read_Integer (To_String (File))) / 1_000_000.0;
        end loop;

        return Watts;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        Count := 0;
    end Close;

end Joular_Core.GPU_AMD_Sysfs;
