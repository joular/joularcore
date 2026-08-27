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

#if PJ_WINDOWS or PJ_LINUX then
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
#end if;

#if PJ_WINDOWS then
with Ada.Environment_Variables;
#end if;

#if PJ_LINUX then
with Ada.Text_IO; use Ada.Text_IO;
#end if;

#if PJ_MACOS then
with Interfaces.C; use Interfaces.C;
with System;
#end if;

package body Joular_Core.OS_Utils is

#if PJ_WINDOWS or PJ_LINUX then

    -- From an information (from Windows variable or /proc/cpuinfo in Linux)
    -- Check and return the normalized vendor name or empty string if none found
    function Get_Vendor_Name (Info : in String) return String is
    begin
        if Index (Info, "Intel") > 0 then
            return "intel";
        end if;

        if (Index (Info, "AMD") > 0) or else (Index (Info, "Ryzen") > 0) or else (Index (Info, "EPYC") > 0) then
            return "amd";
        end if;

        if Index (Info, "Raspberry Pi") > 0 then
            return "rpi";
        end if;

        return "";
    end Get_Vendor_Name;

#end if;

#if PJ_WINDOWS then

    -- On Windows, get CPU vendor from PROCESSOR_IDENTIFIER environmental variable
    function Get_Platform_CPU_Name return String is
    begin
        if not Ada.Environment_Variables.Exists ("PROCESSOR_IDENTIFIER") then
            return "";
        end if;

        declare
            CPU_Identifier : constant String := Ada.Environment_Variables.Value ("PROCESSOR_IDENTIFIER");
            Vendor : constant String := Get_Vendor_Name (CPU_Identifier);
        begin
            if Vendor /= "" then
                return Vendor;
            end if;
        end;

        return "";
    exception
        when others =>
            return "";
    end Get_Platform_CPU_Name;

#elsif PJ_LINUX then

    -- On Linux, get CPU vendor from /proc/cpuinfo
    -- If not on PC/Server, check for Raspberry Pi model
    function Get_Platform_CPU_Name return String is
        F_Name : File_Type; -- File handle
        File_Name : constant String := "/proc/cpuinfo"; -- File name for CPU info
    begin
        Open (F_Name, In_File, File_Name);
        
        while not End_Of_File (F_Name) loop
            declare
                Vendor : constant String := Get_Vendor_Name (Get_Line (F_Name));
            begin
                if Vendor /= "" then
                    Close (F_Name);
                    return Vendor;
                end if; 
            end;
        end loop;

        Close (F_Name);

        -- No supported platform found
        return "";
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            return "";
    end Get_Platform_CPU_Name;

#elsif PJ_MACOS then

    -- MacOS platform
    function Get_Platform_CPU_Name return String is
        function Sysctl_By_Name
            (Name    : in char_array;
            Oldp    : in System.Address;
            Oldlenp : in System.Address;
            Newp    : in System.Address;
            Newlen  : in size_t) return int
            with Import, Convention => C, External_Name => "sysctlbyname";

        Key    : constant char_array := To_C ("hw.optional.arm64");
        Is_ARM : aliased int := 0;
        Length : aliased size_t := int'Size / System.Storage_Unit;
    begin
        -- Check if Apple Silicon (ARM64)
        if Sysctl_By_Name (Key, Is_ARM'Address, Length'Address, System.Null_Address, 0) = 0 and then Is_ARM = 1
        then
            return "apple";
        end if;

        -- Mac Intel are not supported
        return "";
    end Get_Platform_CPU_Name;

#elsif PJ_BSD then

    -- BSD platforms
    function Get_Platform_CPU_Name return String is
    begin
        return "";
    end Get_Platform_CPU_Name;

#else

    -- On other platforms, not supported
    function Get_Platform_CPU_Name return String is
    begin
        return "";
    end Get_Platform_CPU_Name;

#end if;

end Joular_Core.OS_Utils;
