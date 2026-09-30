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

with Interfaces; use Interfaces;
with Interfaces.C; use type Interfaces.C.int;
with System; use System;

with Joular_Core.Win32; use Joular_Core.Win32;

package body Joular_Core.MSR_Hubblo is

    -- Ada string literals have no escape character: this is the literal path the driver registers
    Device_Path : aliased constant Interfaces.C.char_array := Interfaces.C.To_C ("\\.\ScaphandreDriver");

    Driver_Handle : HANDLE := INVALID_HANDLE_VALUE;

    --------------------------------------------------

    function Open return Boolean is
    begin
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

        return Driver_Handle /= INVALID_HANDLE_VALUE;
    end Open;

    --------------------------------------------------

    function Read (MSR : in Unsigned_64; Value : out Unsigned_64) return Boolean is
        ACCESS_READ_WRITE : constant DWORD := 3;
        -- The driver takes the register from the input buffer and ignores the number in the control code, built here as its own tool does
        -- Known from the driver's published source, not from the signed binary installed
        Request_Code : constant DWORD :=
            Control_Code (FILE_DEVICE_UNKNOWN, DWORD (MSR and 16#FFF#), METHOD_BUFFERED, ACCESS_READ_WRITE);
        Input : aliased Unsigned_64 := MSR; -- Register in the low half, processor in the high half (zero: the first one)
        Output : aliased Unsigned_64 := 0;
        Bytes_Returned : aliased DWORD := 0;
        Result : BOOL;
    begin
        Value := 0;

        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
        end if;

        Result := DeviceIoControl
           (hDevice => Driver_Handle,
            dwIoControlCode => Request_Code,
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
    end Read;

    --------------------------------------------------

    procedure Close is
        Ignored : BOOL;
    begin
        if Driver_Handle /= INVALID_HANDLE_VALUE then
            Ignored := CloseHandle (Driver_Handle);
            Driver_Handle := INVALID_HANDLE_VALUE;
        end if;
    end Close;

end Joular_Core.MSR_Hubblo;
