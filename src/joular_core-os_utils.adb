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

#if PJ_LINUX then
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Text_IO; use Ada.Text_IO;
#end if;

#if PJ_WINDOWS and then PJ_X86 then
with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
#end if;

#if PJ_MACOS then
with Interfaces.C; use Interfaces.C;
with System;
#end if;

package body Joular_Core.OS_Utils is

#if PJ_LINUX then

    -- From /proc/cpuinfo in Linux
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

#if PJ_WINDOWS and then PJ_X86 then

    -- Ask the processor about itself
    -- Leaf says what is being asked for, and the four registers are what the processor answers with
    -- All four are written by the instruction, so all four are declared: one left out would let the compiler keep something of its own in a register the processor is about to overwrite
    procedure CPU_ID
       (Leaf : in Unsigned_32;
        EAX : out Unsigned_32;
        EBX : out Unsigned_32;
        ECX : out Unsigned_32;
        EDX : out Unsigned_32)
    is
    begin
        Asm ("cpuid",
             Outputs => (Unsigned_32'Asm_Output ("=a", EAX),
                         Unsigned_32'Asm_Output ("=b", EBX),
                         Unsigned_32'Asm_Output ("=c", ECX),
                         Unsigned_32'Asm_Output ("=d", EDX)),
             Inputs => (Unsigned_32'Asm_Input ("a", Leaf),
                        Unsigned_32'Asm_Input ("c", Unsigned_32'(0))),
             Volatile => True);
    end CPU_ID;

    --------------------------------------------------

    -- The twelve characters the processor names its maker with
    -- Leaf zero hands them over four at a time, in EBX, then EDX, then ECX, least meaningful byte first
    function Vendor_String return String is
        EAX, EBX, ECX, EDX : Unsigned_32;
        Result : String (1 .. 12);

        procedure Put_Word (Value : in Unsigned_32; First : in Positive) is
        begin
            for Offset in 0 .. 3 loop
                Result (First + Offset) :=
                    Character'Val (Natural (Shift_Right (Value, 8 * Offset) and 16#FF#));
            end loop;
        end Put_Word;
    begin
        CPU_ID (0, EAX, EBX, ECX, EDX);

        Put_Word (EBX, 1);
        Put_Word (EDX, 5);
        Put_Word (ECX, 9);

        return Result;
    end Vendor_String;

    --------------------------------------------------

    -- On Windows, ask the processor itself about its vendor
    function Get_Platform_CPU_Name return String is
        Vendor : constant String := Vendor_String;
    begin
        if Vendor = "GenuineIntel" then
            return "intel";
        end if;

        if Vendor = "AuthenticAMD" then
            return "amd";
        end if;

        return "";
    exception
        when others =>
            return "";
    end Get_Platform_CPU_Name;

    --------------------------------------------------

    function Has_Unsupported_Energy_Unit return Boolean is
        EAX, EBX, ECX, EDX : Unsigned_32;
        Family : Unsigned_32;
        Model : Unsigned_32;
    begin
        CPU_ID (1, EAX, EBX, ECX, EDX);

        -- The family and the model sit in the first register, and for family 6 the model carries four more bits from further up
        Family := Shift_Right (EAX, 8) and 16#F#;
        Model := Shift_Right (EAX, 4) and 16#F#;

        -- Only family 6 carries the processors below, so nothing else needs the extended model
        if Family /= 6 then
            return False;
        end if;

        Model := Model + Shift_Left (Shift_Right (EAX, 16) and 16#F#, 4);

        -- The Silvermont and Airmont generations of Atom, which count the energy of the register in microjoules rather than in fractions of a joule
        -- 37H is Bay Trail, 4AH and 5AH and 5DH the ones built into phones and tablets, and 4CH is Cherry Trail
        return Model = 16#37# or else Model = 16#4A# or else Model = 16#4C#
               or else Model = 16#5A# or else Model = 16#5D#;
    exception
        when others =>
            -- The processor could not be asked, so we trurn it down
            -- Turning it down reports nothing, where carrying on could report a thousand times what the machine draws
            return True;
    end Has_Unsupported_Energy_Unit;

#elsif PJ_WINDOWS then

    -- Windows on a processor that is not a 64 bits x86 one
    -- There is no RAPL counter to look for there, and no CPUID instruction to ask with
    function Get_Platform_CPU_Name return String is
    begin
        return "";
    end Get_Platform_CPU_Name;

    --------------------------------------------------

    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

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

    --------------------------------------------------

    -- The RAPL registers are only ever read directly on Windows, and Linux works the unit of its counter out on its own, so there is nothing to turn down here
    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

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

    --------------------------------------------------

    -- The RAPL registers are only ever read directly on Windows, and Linux works the unit of its counter out on its own, so there is nothing to turn down here
    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

#elsif PJ_BSD then

    -- BSD platforms
    function Get_Platform_CPU_Name return String is
    begin
        return "";
    end Get_Platform_CPU_Name;

    --------------------------------------------------

    -- The RAPL registers are only ever read directly on Windows, and Linux works the unit of its counter out on its own, so there is nothing to turn down here
    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

#else

    -- On other platforms, not supported
    function Get_Platform_CPU_Name return String is
    begin
        return "";
    end Get_Platform_CPU_Name;

    --------------------------------------------------

    -- The RAPL registers are only ever read directly on Windows, and Linux works the unit of its counter out on its own, so there is nothing to turn down here
    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

#end if;

end Joular_Core.OS_Utils;
