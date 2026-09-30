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

    Power_File : Unbounded_String;

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
                if Read_First_Line (Folder & "/name") = Driver_Name then
                    Power_File := To_Unbounded_String (Power_File_Of (Folder));

                    exit when Power_File /= Null_Unbounded_String;
                end if;
            end;
        end loop;

        return Power_File /= Null_Unbounded_String;
    end Open;

    --------------------------------------------------

    function Get_Power return Long_Float is
    begin
        -- hwmon reports microwatts; the file reads 0 when the card stops answering
        return Long_Float (Read_Integer (To_String (Power_File))) / 1_000_000.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        Power_File := Null_Unbounded_String;
    end Close;

end Joular_Core.GPU_AMD_Sysfs;
