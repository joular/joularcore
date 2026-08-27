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

#if PJ_WINDOWS then

with Interfaces; use Interfaces;
with Interfaces.C; use type Interfaces.C.int;
with System; use System;
with System.Storage_Elements; use System.Storage_Elements;

with Joular_Core.OS_Utils; use Joular_Core.OS_Utils;

#end if;

package body Joular_Core.RAPL_MSR_Windows is

#if PJ_WINDOWS then

    -- Registers holding the energy unit and package counters on Intel and AMD
    MSR_INTEL_RAPL_POWER_UNIT : constant Unsigned_64 := 16#606#;
    MSR_INTEL_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#611#;
    MSR_AMD_RAPL_POWER_UNIT : constant Unsigned_64 := 16#C001_0299#;
    MSR_AMD_PKG_ENERGY_STATUS : constant Unsigned_64 := 16#C001_029B#;

    ENERGY_UNIT_BITS : constant Unsigned_64 := 16#1F00#; -- Bits 12:8 of the power unit register hold the energy unit
    ENERGY_UNIT_SHIFT : constant := 8; -- How far down to shift them
    ENERGY_COUNTER_BITS : constant Unsigned_64 := 16#FFFF_FFFF#; -- Only the low 32 bits of the energy register hold the counter, the rest is reserved

    -- Win32 types and flags
    subtype HANDLE is System.Address; -- Win32 kernel object handle
    subtype DWORD is Interfaces.Unsigned_32; -- Win32 32 bits unsigned
    subtype BOOL is Interfaces.C.int; -- Win32 boolean, where zero is false

    -- What CreateFileA returns when it could not open what was asked of it, which is the handle (HANDLE) -1 rather than a null pointer
    INVALID_HANDLE_VALUE : constant HANDLE := To_Address (Integer_Address'Last); -- (HANDLE) -1

    -- Flags for opening the device
    FILE_GENERIC_READ : constant DWORD := 16#0012_0089#;
    FILE_GENERIC_WRITE : constant DWORD := 16#0012_0116#;
    FILE_SHARE_READ : constant DWORD := 16#0000_0001#;
    FILE_SHARE_WRITE : constant DWORD := 16#0000_0002#;
    OPEN_EXISTING : constant DWORD := 3;

    -- The Hubblo's RAPL driver path
    Device_Path : aliased constant Interfaces.C.char_array := Interfaces.C.To_C ("\\.\ScaphandreDriver");

    --  Opens the driver and returns a handle on it
    function CreateFileA
       (lpFileName : System.Address;
        dwDesiredAccess : DWORD;
        dwShareMode : DWORD;
        lpSecurityAttributes : System.Address;
        dwCreationDisposition : DWORD;
        dwFlagsAndAttributes : DWORD;
        hTemplateFile : System.Address) return HANDLE;
    pragma Import (Stdcall, CreateFileA, "CreateFileA");

    --  Sends one request to the driver: the control code says what to do, the input buffer carries the register number, and the driver writes the register into the output buffer. Returns zero when the request failed
    function DeviceIoControl
       (hDevice : HANDLE;
        dwIoControlCode : DWORD;
        lpInBuffer : System.Address;
        nInBufferSize : DWORD;
        lpOutBuffer : System.Address;
        nOutBufferSize : DWORD;
        lpBytesReturned : System.Address;
        lpOverlapped : System.Address) return BOOL;
    pragma Import (Stdcall, DeviceIoControl, "DeviceIoControl");

    --  Gives the driver handle back to the system
    function CloseHandle (hObject : HANDLE) return BOOL;
    pragma Import (Stdcall, CloseHandle, "CloseHandle");

    --------------------------------------------------

    -- Driver handle (one for whole program, and not per read)
    Driver_Handle : HANDLE := INVALID_HANDLE_VALUE;

    -- MSR to be read (Intel or AMD)
    Energy_MSR : Unsigned_64 := 0;

    -- What one count of the counter is worth
    -- Exponent is never negative, so we're using Natural type instead of Integer
    Energy_Exponent : Natural := 0;

    --------------------------------------------------

    -- Read one register using the driver
    -- Returns zero if it cannot read
    function Read_MSR (MSR : in Unsigned_64) return Unsigned_64 is
        FILE_DEVICE_UNKNOWN : constant DWORD := 16#22#;
        ACCESS_READ_WRITE : constant DWORD := 3;
        Control_Code : constant DWORD :=
            Shift_Left (FILE_DEVICE_UNKNOWN, 16)
            or Shift_Left (ACCESS_READ_WRITE, 14)
            or Shift_Left (DWORD (MSR and 16#FFF#), 2);
        Input : aliased Unsigned_64 := MSR; -- Which register to read
        Output : aliased Unsigned_64 := 0; -- Read value by the driver
        Bytes_Returned : aliased DWORD := 0; -- How much the driver actually wrote
        Result : BOOL;
    begin
        if Driver_Handle = INVALID_HANDLE_VALUE then
            return 0;
        end if;

        -- Read MSR through driver
        Result := DeviceIoControl
           (hDevice => Driver_Handle,
            dwIoControlCode => Control_Code,
            lpInBuffer => Input'Address,
            nInBufferSize => 8,
            lpOutBuffer => Output'Address,
            nOutBufferSize => 8,
            lpBytesReturned => Bytes_Returned'Address,
            lpOverlapped => System.Null_Address);

        if Result = 0 or else Bytes_Returned /= 8 then
            return 0;
        end if;

        return Output;
    exception
        when others =>
            return 0;
    end Read_MSR;

    --------------------------------------------------

    function Open return Boolean is
        Vendor : constant String := Get_Platform_CPU_Name;
        Power_Unit_MSR : Unsigned_64;
        Power_Unit : Unsigned_64;
    begin
        -- First, check the vendor, and use proper registers
        if Vendor = "intel" then
            Power_Unit_MSR := MSR_INTEL_RAPL_POWER_UNIT;
            Energy_MSR := MSR_INTEL_PKG_ENERGY_STATUS;
        elsif Vendor = "amd" then
            Power_Unit_MSR := MSR_AMD_RAPL_POWER_UNIT;
            Energy_MSR := MSR_AMD_PKG_ENERGY_STATUS;
        else
            return False; -- No RAPL counter to look for on this processor
        end if;

        -- Then, open the device if not previsouly opened
        if Driver_Handle = INVALID_HANDLE_VALUE then
            Driver_Handle := CreateFileA
               (lpFileName => Device_Path'Address,
                dwDesiredAccess => FILE_GENERIC_READ or FILE_GENERIC_WRITE,
                dwShareMode => FILE_SHARE_READ or FILE_SHARE_WRITE,
                lpSecurityAttributes => System.Null_Address,
                dwCreationDisposition => OPEN_EXISTING,
                dwFlagsAndAttributes => 0,
                hTemplateFile => System.Null_Address);
        end if;

        -- Then check if there is any error (driver not installed, or not allowed)
        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
        end if;

        -- Then, what one count of the RAPL counter is worth
        Power_Unit := Read_MSR (Power_Unit_MSR);
        Energy_Exponent := Natural (Shift_Right (Power_Unit and ENERGY_UNIT_BITS, ENERGY_UNIT_SHIFT));

        -- If the register can't be read or is empty, then close driver and return False
        if Energy_Exponent = 0 then
            Close;
            return False;
        end if;

        -- Then, take first reading and check it is not zero
        -- Close and return False if it fails
        if (Read_MSR (Energy_MSR) and ENERGY_COUNTER_BITS) = 0 then
            Close;
            return False;
        end if;

        return True;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Max_Energy_Range return Long_Long_Integer is
    begin
        if Energy_Exponent = 0 then
            -- Nothing was recognized, so we don't know the max range
            return 0;
        end if;

        -- Counter is 32 bits wide, so it wraps after 2^32 counts, and one count is 1/2^Energy_Exponent of a joule: it therefore wraps at 2^(32 - Energy_Exponent) joules
        return 1_000_000 * 2 ** (32 - Energy_Exponent);
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
        Raw_Value : Unsigned_64;
    begin
        if Energy_Exponent = 0 then
            return 0;
        end if;

        -- Only the low 32 bits of the register hold the counter, the rest is reserved
        -- Masking keeps it inside 0 .. 2^32 - 1, which is the range the wrap correction assumes
        Raw_Value := Read_MSR (Energy_MSR) and ENERGY_COUNTER_BITS;

        if Raw_Value = 0 then
            return 0;
        end if;

        return Long_Long_Integer (Raw_Value) * 1_000_000 / 2 ** Energy_Exponent;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
        Ignored : BOOL;
    begin
        if Driver_Handle /= INVALID_HANDLE_VALUE then
            Ignored := CloseHandle (Driver_Handle);
            Driver_Handle := INVALID_HANDLE_VALUE;
        end if;

        Energy_MSR := 0;
        Energy_Exponent := 0;
    exception
        when others =>
            Driver_Handle := INVALID_HANDLE_VALUE;
    end Close;

#else

    -- Driver for Windows only, so return 0 or nothing if called from another platform

    function Open return Boolean is
    begin
        return False;
    end Open;

    --------------------------------------------------

    function Max_Energy_Range return Long_Long_Integer is
    begin
        return 0;
    end Max_Energy_Range;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
    begin
        return 0;
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.RAPL_MSR_Windows;
