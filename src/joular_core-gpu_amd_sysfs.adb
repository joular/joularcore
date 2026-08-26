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

#if PJ_LINUX or PJ_BSD then
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
#end if;

package body Joular_Core.GPU_AMD_Sysfs is

#if PJ_LINUX or PJ_BSD then

    -- Hwmon path
    Hwmon_Path : constant String := "/sys/class/hwmon";

    -- AMD GPU driver name
    Driver_Name : constant String := "amdgpu";

    -- Power files an AMD GPU can offer, will be check in this order (average is preferred as it is averaged over the last moment and more suitable than instant reading)
    Average_File : constant String := "power1_average";
    Instant_File : constant String := "power1_input";

    -- Max sensors to search in hwmon looking for AMD GPU
    Max_Sensors : constant := 32;

    -- The power file of the found GPU card
    Power_File : Unbounded_String;

    --------------------------------------------------

    -- Util function to read the hwmon files (usually one line containing driver name or power value)
    -- Return an empty String if file doesn't exist or cannot be read
    function Read_Line_Of (File_Name : in String) return String is
        F_Name : File_Type;
    begin
        Open (F_Name, In_File, File_Name);

        if End_Of_File (F_Name) then
            Close (F_Name);
            return "";
        end if;

        declare
            Value : constant String := Get_Line (F_Name);
        begin
            Close (F_Name);
            return Value;
        end;
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            return "";
    end Read_Line_Of;

    --------------------------------------------------

    -- Get the power file provided by the read hwmon sensors
    -- Return empty string if no power file is found for the sensor
    function Power_File_Of (Folder : in String) return String is
    begin
        if Read_Line_Of (Folder & "/" & Average_File) /= "" then
            return Folder & "/" & Average_File;
        end if;

        if Read_Line_Of (Folder & "/" & Instant_File) /= "" then
            return Folder & "/" & Instant_File;
        end if;

        return "";
    end Power_File_Of;

    --------------------------------------------------

    function Is_Accessible return Boolean is
    begin
        -- Just to be sure, start from nothing so no double detection
        Close;

        -- Check hwmon sensors for the first AMD card found
        for Number in 0 .. Max_Sensors - 1 loop
            declare
                Folder : constant String := Hwmon_Path & "/hwmon" & Trim (Natural'Image (Number), Left);
            begin
                if Read_Line_Of (Folder & "/name") = Driver_Name then
                    Power_File := To_Unbounded_String (Power_File_Of (Folder));

                    exit when Power_File /= Null_Unbounded_String;
                end if;
            end;
        end loop;

        return Power_File /= Null_Unbounded_String;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Power return Long_Float is
    begin
        declare
            Value : constant String := Read_Line_Of (To_String (Power_File));
        begin
            -- If card stops answering, return 0
            if Value = "" then
                return 0.0;
            end if;

            -- hwmon files provide power in microwatts, so convert it to watts
            return Long_Float (Long_Long_Integer'Value (Value)) / 1_000_000.0;
        end;
    exception
        when others =>
            return 0.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        Power_File := Null_Unbounded_String;
    end Close;

#else

    -- On unsupported systems, return False and zeros

    function Is_Accessible return Boolean is
    begin
        return False;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Power return Long_Float is
    begin
        return 0.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.GPU_AMD_Sysfs;
