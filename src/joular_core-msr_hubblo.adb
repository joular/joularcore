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

with Joular_Core.Win32; use Joular_Core.Win32;

#end if;

package body Joular_Core.MSR_Hubblo is

#if PJ_WINDOWS then

    -- The Hubblo's RAPL driver path
    -- Ada string literals have no escape character, so this is the plain \\.\ScaphandreDriver the driver registers
    Device_Path : aliased constant Interfaces.C.char_array := Interfaces.C.To_C ("\\.\ScaphandreDriver");

    -- Driver handle (one for whole program, and not per read)
    Driver_Handle : HANDLE := INVALID_HANDLE_VALUE;

    --------------------------------------------------

    function Open return Boolean is
    begin
        -- Open the device if not previously opened
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

        -- Driver not installed, not running, or not allowed
        return Driver_Handle /= INVALID_HANDLE_VALUE;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Read (MSR : in Unsigned_64; Value : out Unsigned_64) return Boolean is
        FILE_DEVICE_UNKNOWN : constant DWORD := 16#22#;
        ACCESS_READ_WRITE : constant DWORD := 3;
        -- The driver reads the register from the input buffer and pays no attention to the number in the control code, which is kept as the driver's own tool builds it
        Control_Code : constant DWORD :=
            Shift_Left (FILE_DEVICE_UNKNOWN, 16)
            or Shift_Left (ACCESS_READ_WRITE, 14)
            or Shift_Left (DWORD (MSR and 16#FFF#), 2);
        Input : aliased Unsigned_64 := MSR; -- Which register to read, and which processor to read it on in its upper half, which is left at zero for the first one
        Output : aliased Unsigned_64 := 0; -- Read value by the driver
        Bytes_Returned : aliased DWORD := 0; -- How much the driver actually wrote
        Result : BOOL;
    begin
        Value := 0;

        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
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
            return False;
        end if;

        Value := Output;
        return True;
    exception
        when others =>
            Value := 0;
            return False;
    end Read;

    --------------------------------------------------

    procedure Close is
        Ignored : BOOL;
    begin
        if Driver_Handle /= INVALID_HANDLE_VALUE then
            Ignored := CloseHandle (Driver_Handle);
            Driver_Handle := INVALID_HANDLE_VALUE;
        end if;
    exception
        when others =>
            Driver_Handle := INVALID_HANDLE_VALUE;
    end Close;

#else

    -- Driver for Windows only, so answer nothing if called from another platform

    function Open return Boolean is
    begin
        return False;
    end Open;

    --------------------------------------------------

    function Read (MSR : in Interfaces.Unsigned_64; Value : out Interfaces.Unsigned_64) return Boolean is
        pragma Unreferenced (MSR);
    begin
        Value := 0;
        return False;
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.MSR_Hubblo;
