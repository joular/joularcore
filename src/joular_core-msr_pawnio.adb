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

package body Joular_Core.MSR_PawnIO is

#if PJ_WINDOWS then

    -- The PawnIO driver path
    -- Ada string literals have no escape character, so this is the plain \\?\GLOBALROOT\Device\PawnIO the driver registers
    Device_Path : aliased constant Interfaces.C.char_array := Interfaces.C.To_C ("\\?\GLOBALROOT\Device\PawnIO");

    -- The device type PawnIO answers to
    PAWNIO_DEVICE_TYPE : constant DWORD := 41394; -- 16#A1B2#

    -- How the request carries its buffers, and what it is allowed to do, both of which PawnIO leaves at zero
    METHOD_BUFFERED : constant DWORD := 0;
    FILE_ANY_ACCESS : constant DWORD := 0;

    -- CTL_CODE of the Windows driver kit, which builds the number naming one request of a driver
    function Control_Code
       (Device_Type : in DWORD;
        Request : in DWORD;
        Method : in DWORD;
        Access_Mode : in DWORD) return DWORD
    is (Shift_Left (Device_Type, 16)
        or Shift_Left (Access_Mode, 14)
        or Shift_Left (Request, 2)
        or Method);

    -- Give the driver a module, which it checks and runs
    IOCTL_PIO_LOAD_BINARY : constant DWORD :=
        Control_Code (PAWNIO_DEVICE_TYPE, 16#821#, METHOD_BUFFERED, FILE_ANY_ACCESS); -- 16#A1B2_2084#

    -- Run one of the functions of the module already loaded
    IOCTL_PIO_EXECUTE_FN : constant DWORD :=
        Control_Code (PAWNIO_DEVICE_TYPE, 16#841#, METHOD_BUFFERED, FILE_ANY_ACCESS); -- 16#A1B2_2104#

    -- PawnIO takes the name of the function to run as this many bytes, and refuses a name that fills them all, as it would leave no zero to end it
    Name_Size : constant := 32;

    subtype Name_Bytes is Storage_Array (1 .. Name_Size);

    -- The buffer of a call taking one value, which is what ioctl_read_msr of the Intel and AMD modules takes: the name of the function, then its values
    type Execute_Input is
       record
           Name : Name_Bytes;
           Argument : Unsigned_64;
       end record;

    -- Laid out by hand rather than left to the compiler, as the driver reads these bytes as they are
    for Execute_Input use
       record
           Name at 0 range 0 .. 8 * Name_Size - 1;
           Argument at Name_Size range 0 .. 63;
       end record;

    -- Pinned so a padding byte slipping in would not build instead of being refused by the driver at runtime
    for Execute_Input'Size use 8 * (Name_Size + 8);
    for Execute_Input'Alignment use 8;

    Execute_Input_Size : constant DWORD := Name_Size + 8; -- 40 bytes

    -- What one reading of a register gives back: one 64 bits value
    Execute_Output_Size : constant DWORD := 8;

    --------------------------------------------------

    -- Driver handle (one for whole program, and not per read)
    Driver_Handle : HANDLE := INVALID_HANDLE_VALUE;

    -- A module is loaded into one handle and stays there, and loading a second one into the same handle is refused, so remember which one this handle carries
    -- Asking for a different module therefore starts from a new handle, rather than silently keeping the first
    Loaded_Module : System.Address := System.Null_Address;

    --------------------------------------------------

    -- Write the name of a function into the bytes PawnIO expects, padded with zeros
    -- Gives back an empty name if it would not fit, which the driver refuses
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

    -- The function of the Intel and AMD modules that reads one register
    -- Written out once here rather than on every read, which also keeps the empty name To_Name gives back for a name that would not fit out of the reading path
    Read_MSR_Name : constant Name_Bytes := To_Name ("ioctl_read_msr");

    --------------------------------------------------

    function Open (Module : in Storage_Array) return Boolean is
        Result : BOOL;
        Bytes_Returned : aliased DWORD := 0;
        Wanted : System.Address;
    begin
        -- No module to load means nothing to open, as the driver reads no register on its own
        if Module'Length = 0 then
            return False;
        end if;

        -- Which module is being asked for, as the modules are constants that stay where they are
        Wanted := Module (Module'First)'Address;

        -- Already opened and carrying this very module, nothing more to do
        if Driver_Handle /= INVALID_HANDLE_VALUE and then Loaded_Module = Wanted then
            return True;
        end if;

        -- A handle carries the one module it was given and refuses a second, so a different module starts from a new handle rather than being quietly dropped for the one already there
        if Driver_Handle /= INVALID_HANDLE_VALUE then
            Close;
        end if;

        Driver_Handle := CreateFileA
           (lpFileName => Device_Path'Address,
            dwDesiredAccess => FILE_GENERIC_READ or FILE_GENERIC_WRITE,
            dwShareMode => FILE_SHARE_READ or FILE_SHARE_WRITE,
            lpSecurityAttributes => System.Null_Address,
            dwCreationDisposition => OPEN_EXISTING,
            dwFlagsAndAttributes => 0,
            hTemplateFile => System.Null_Address);

        -- Driver not installed, not running, or the program is not running as administrator, which PawnIO requires and Hubblo's driver does not
        if Driver_Handle = INVALID_HANDLE_VALUE then
            return False;
        end if;

        -- Hand the module to the driver, which checks its signature and runs its main
        -- That main refuses a machine the module was not made for (wrong vendor, wrong family, not 64 bits), so this is also where a processor PawnIO cannot serve is found out
        Result := DeviceIoControl
           (hDevice => Driver_Handle,
            dwIoControlCode => IOCTL_PIO_LOAD_BINARY,
            lpInBuffer => Module (Module'First)'Address,
            nInBufferSize => DWORD (Module'Length),
            lpOutBuffer => System.Null_Address,
            nOutBufferSize => 0,
            lpBytesReturned => Bytes_Returned'Address,
            lpOverlapped => System.Null_Address);

        -- Close the device rather than leaving a handle behind, as another driver may be tried after this one
        if Result = 0 then
            Close;
            return False;
        end if;

        Loaded_Module := Wanted;
        return True;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Read (MSR : in Unsigned_64; Value : out Unsigned_64) return Boolean is
        Input : aliased Execute_Input :=
           (Name => Read_MSR_Name,
            Argument => MSR);
        Output : aliased Unsigned_64 := 0; -- Read value by the module
        Bytes_Returned : aliased DWORD := 0; -- How much the driver actually wrote
        Result : BOOL := 0;
        Thread : HANDLE;
        Previous_Affinity : DWORD_PTR := 0;
    begin
        Value := 0;

        if Driver_Handle = INVALID_HANDLE_VALUE or else Loaded_Module = System.Null_Address then
            return False;
        end if;

        -- The module reads the register of whichever processor the thread happens to run on and does not pin it itself, unlike Hubblo's driver which pins in the kernel
        -- The library reports the PKG domain of the first socket, so pin here: on a machine with several sockets an unpinned read would jump between two counters that have nothing to do with each other, and the energy since the last reading would be nonsense
        -- The mask is read against the processor group the thread is in, so bit 0 is the first processor of that group: that is the first socket on a machine of up to 64 logical processors, which has only one group
        Thread := GetCurrentThread;
        Previous_Affinity := SetThreadAffinityMask (Thread, 1);

        -- Kept in its own block, so the thread is put back below whatever happens here rather than being left pinned to the first processor for the rest of the program
        begin
            -- Run ioctl_read_msr of the loaded module
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

        -- Put the thread back where it was, if it was restricted at all
        if Previous_Affinity /= 0 then
            Previous_Affinity := SetThreadAffinityMask (Thread, Previous_Affinity);
        end if;

        -- The driver reports the whole output size when the call went through
        if Result = 0 or else Bytes_Returned /= Execute_Output_Size then
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

        Loaded_Module := System.Null_Address;
    exception
        when others =>
            Driver_Handle := INVALID_HANDLE_VALUE;
            Loaded_Module := System.Null_Address;
    end Close;

#else

    -- Driver for Windows only, so answer nothing if called from another platform

    function Open (Module : in Storage_Array) return Boolean is
        pragma Unreferenced (Module);
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

end Joular_Core.MSR_PawnIO;
