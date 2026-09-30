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

#if PJ_X86 then
with Interfaces; use Interfaces;
with System.Machine_Code; use System.Machine_Code;
#end if;

package body Joular_Core.Processor is

#if PJ_X86 then

    -- Ask the processor about itself
    -- Leaf says what is being asked for, and the four registers are what the processor answers with
    -- All four outputs are declared so the compiler knows cpuid overwrites them
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

    -- Leaf 0 gives the twelve characters in EBX, EDX, ECX, low byte first
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

    function Vendor return Vendor_Kind is
        Name : constant String := Vendor_String;
    begin
        if Name = "GenuineIntel" then
            return Intel;
        end if;

        if Name = "AuthenticAMD" then
            return AMD;
        end if;

        return Unknown;
    end Vendor;

    --------------------------------------------------

    function Has_Unsupported_Energy_Unit return Boolean is
        EAX, EBX, ECX, EDX : Unsigned_32;
        Family : Unsigned_32;
        Model : Unsigned_32;
    begin
        CPU_ID (1, EAX, EBX, ECX, EDX);

        -- Family 6 adds the extended model bits 19:16 to the model
        Family := Shift_Right (EAX, 8) and 16#F#;
        Model := Shift_Right (EAX, 4) and 16#F#;

        -- Only family 6 has the Atoms below
        if Family /= 6 then
            return False;
        end if;

        Model := Model + Shift_Left (Shift_Right (EAX, 16) and 16#F#, 4);

        -- Silvermont and Airmont Atoms, counting the register in microjoules rather than fractions of a joule
        -- 37H is Bay Trail, 4AH and 5AH and 5DH the ones built into phones and tablets, and 4CH is Cherry Trail
        return Model = 16#37# or else Model = 16#4A# or else Model = 16#4C#
               or else Model = 16#5A# or else Model = 16#5D#;
    end Has_Unsupported_Energy_Unit;

#else

    -- Not 64 bits x86: no CPUID to ask, and no RAPL registers to read

    function Vendor return Vendor_Kind is
    begin
        return Unknown;
    end Vendor;

    --------------------------------------------------

    function Has_Unsupported_Energy_Unit return Boolean is
    begin
        return False;
    end Has_Unsupported_Energy_Unit;

#end if;

end Joular_Core.Processor;
