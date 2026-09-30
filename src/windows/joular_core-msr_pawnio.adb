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

package body Joular_Core.MSR_PawnIO is

    -- Ada string literals have no escape character: this is the literal path the driver registers
    Device_Path : aliased constant Interfaces.C.char_array := Interfaces.C.To_C ("\\?\GLOBALROOT\Device\PawnIO");

    PAWNIO_DEVICE_TYPE : constant DWORD := 41394; -- 16#A1B2#

    -- PawnIO leaves the access bits at zero
    FILE_ANY_ACCESS : constant DWORD := 0;

    -- Give the driver a module, which it checks and runs
    IOCTL_PIO_LOAD_BINARY : constant DWORD :=
        Control_Code (PAWNIO_DEVICE_TYPE, 16#821#, METHOD_BUFFERED, FILE_ANY_ACCESS); -- 16#A1B2_2084#

    -- Run one of the functions of the module already loaded
    IOCTL_PIO_EXECUTE_FN : constant DWORD :=
        Control_Code (PAWNIO_DEVICE_TYPE, 16#841#, METHOD_BUFFERED, FILE_ANY_ACCESS); -- 16#A1B2_2104#

    -- A name filling all the bytes leaves no ending zero, and the driver refuses it
    Name_Size : constant := 32;

    subtype Name_Bytes is Storage_Array (1 .. Name_Size);

    -- What ioctl_read_msr of the Intel and AMD modules takes: the function name, then its one value
    type Execute_Input is
       record
           Name : Name_Bytes;
           Argument : Unsigned_64;
       end record;

    -- The driver reads these bytes as they are
    for Execute_Input use
       record
           Name at 0 range 0 .. 8 * Name_Size - 1;
           Argument at Name_Size range 0 .. 63;
       end record;

    -- Catch any padding at compile time
    for Execute_Input'Size use 8 * (Name_Size + 8);
    for Execute_Input'Alignment use 8;

    Execute_Input_Size : constant DWORD := Name_Size + 8; -- 40 bytes

    -- One 64 bits value back
    Execute_Output_Size : constant DWORD := 8;

    --------------------------------------------------

    -- Kept only once a module is loaded, so a valid handle always carries one
    Driver_Handle : HANDLE := INVALID_HANDLE_VALUE;

    --------------------------------------------------

    -- Zero padded; empty when the name would not fit, which the driver refuses
    function To_Name (Name : in String) return Name_Bytes is
        Result : Name_Bytes := (others => 0);
    begin
        if Name'Length >= Name_Size then
            return Result;
        end if;

        for I in Name'Range loop
            Result (Name_Bytes'First + Storage_Offset (I - Name'First)) :=
                Storage_Element (Character'Pos (Name (I)));
        end loop;

        return Result;
    end To_Name;

    -- Built once, outside the read path
    Read_MSR_Name : constant Name_Bytes := To_Name ("ioctl_read_msr");

    --------------------------------------------------

    function Open (Module : in Storage_Array) return Boolean is
        Result : BOOL;
        Bytes_Returned : aliased DWORD := 0;
    begin
        -- A handle takes only one module
        Close;

        if Module'Length = 0 then
            return False;
        end if;

        Driver_Handle := CreateFileA
           (lpFileName => Device_Path'Address,
            dwDesiredAccess => FILE_GENERIC_READ or FILE_GENERIC_WRITE,
            dwShareMode => FILE_SHARE_READ or FILE_SHARE_WRITE,
            lpSecurityAttributes => System.Null_Address,
            dwCreationDisposition => OPEN_EXISTING,
            dwFlagsAndAttributes => 0,
            hTemplateFile => System.Null_Address);

        -- Missing, not running, or not elevated: PawnIO needs administrator, Hubblo's driver doesn't
        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
        end if;

        -- The module's main refuses an unsupported CPU (vendor, family, 32 bits), so this is where one is detected
        Result := DeviceIoControl
           (hDevice => Driver_Handle,
            dwIoControlCode => IOCTL_PIO_LOAD_BINARY,
            lpInBuffer => Module (Module'First)'Address,
            nInBufferSize => DWORD (Module'Length),
            lpOutBuffer => System.Null_Address,
            nOutBufferSize => 0,
            lpBytesReturned => Bytes_Returned'Address,
            lpOverlapped => System.Null_Address);

        -- Another driver may be tried next, so leave no handle behind
        if Result = 0 then
            Close;
            return False;
        end if;

        return True;
    end Open;

    --------------------------------------------------

    function Read (MSR : in Unsigned_64; Value : out Unsigned_64) return Boolean is
        Input : aliased Execute_Input :=
           (Name => Read_MSR_Name,
            Argument => MSR);
        Output : aliased Unsigned_64 := 0;
        Bytes_Returned : aliased DWORD := 0;
        Result : BOOL := 0;
        Thread : HANDLE;

        -- Processor 0 of group 0 is the first socket, whatever group the thread runs in
        First_Processor : aliased constant GROUP_AFFINITY := (Mask => 1, Group => 0, Reserved => (others => 0));
        Previous_Affinity : aliased GROUP_AFFINITY := (Mask => 0, Group => 0, Reserved => (others => 0));
        Ignored : BOOL;
    begin
        Value := 0;

        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
        end if;

        -- The module reads the MSR of the current processor (Hubblo's driver pins in the kernel), so pin the thread to the first socket
        Thread := GetCurrentThread;

        if SetThreadGroupAffinity (Thread, First_Processor'Address, Previous_Affinity'Address) = 0 then
            return False;
        end if;

        -- Own block so the affinity is always restored
        begin
            Result := DeviceIoControl
               (hDevice => Driver_Handle,
                dwIoControlCode => IOCTL_PIO_EXECUTE_FN,
                lpInBuffer => Input'Address,
                nInBufferSize => Execute_Input_Size,
                lpOutBuffer => Output'Address,
                nOutBufferSize => Execute_Output_Size,
                lpBytesReturned => Bytes_Returned'Address,
                lpOverlapped => System.Null_Address);
        exception
            when others =>
                Result := 0;
        end;

        Ignored := SetThreadGroupAffinity (Thread, Previous_Affinity'Address, System.Null_Address);

        -- A call that went through reports the whole output size
        if Result = 0 or else Bytes_Returned /= Execute_Output_Size then
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

end Joular_Core.MSR_PawnIO;
