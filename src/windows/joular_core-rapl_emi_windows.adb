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

with Ada.Unchecked_Conversion;

with Interfaces; use Interfaces;
with Interfaces.C; use type Interfaces.C.int;
with System; use System;
with System.Storage_Elements; use System.Storage_Elements;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;
with Joular_Core.Win32; use Joular_Core.Win32;

package body Joular_Core.RAPL_EMI_Windows is

    -- GUID_DEVICE_ENERGY_METER from emi.h {45BD8344-7ED6-49CF-A440-C276C933B053}
    type GUID is
       record
           Data1 : Unsigned_32;
           Data2 : Unsigned_16;
           Data3 : Unsigned_16;
           Data4 : Storage_Array (1 .. 8);
       end record;

    for GUID use
       record
           Data1 at 0 range 0 .. 31;
           Data2 at 4 range 0 .. 15;
           Data3 at 6 range 0 .. 15;
           Data4 at 8 range 0 .. 63;
       end record;

    for GUID'Size use 128;
    for GUID'Alignment use 4;

    Energy_Meter_Name : aliased constant GUID :=
       (Data1 => 16#45BD_8344#,
        Data2 => 16#7ED6#,
        Data3 => 16#49CF#,
        Data4 => (16#A4#, 16#40#, 16#C2#, 16#76#, 16#C9#, 16#33#, 16#B0#, 16#53#));

    --------------------------------------------------

    -- IOCTL codes from emi.h
    FILE_READ_ACCESS : constant DWORD := 1;

    IOCTL_EMI_GET_VERSION : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 0, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4000#

    IOCTL_EMI_GET_METADATA_SIZE : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 1, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4004#

    IOCTL_EMI_GET_METADATA : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 2, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4008#

    IOCTL_EMI_GET_MEASUREMENT : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 3, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_400C#

    --------------------------------------------------

    -- V1 has a single non-RAPL channel, only V2 is supported
    EMI_VERSION_V2 : constant Unsigned_16 := 2;

    -- Only unit defined by emi.h
    EMI_UNIT_PICOWATT_HOURS : constant Unsigned_64 := 0;

    -- Offsets in EMI_METADATA_V2 (emi.h)
    CHANNEL_COUNT_OFFSET : constant := 66;
    METADATA_HEADER_SIZE : constant := 68;

    -- Unit (4 bytes), then name size (2 bytes)
    CHANNEL_HEADER_SIZE : constant := 6;

    -- Energy (8 bytes), then timestamp (8 bytes)
    MEASUREMENT_SIZE : constant := 16;

    -- Socket 0 package channel, or else the first *_PKG channel
    PACKAGE_CHANNEL_NAME : constant String := "RAPL_Package0_PKG";
    PACKAGE_CHANNEL_SUFFIX : constant String := "_PKG";

    -- Sanity bounds, far above what the Windows 11 meter returns (four channels, about 500 bytes of metadata)
    MAX_CHANNELS : constant := 32;
    MAX_METADATA_SIZE : constant := 65_536;
    MAX_NAME_LENGTH : constant := 128;
    MAX_LIST_CHARACTERS : constant := 32_768;

    --------------------------------------------------

    -- cfgmgr32 functions, loaded at run time so no extra link is needed

    CR_SUCCESS : constant Unsigned_32 := 0;
    CR_BUFFER_SMALL : constant Unsigned_32 := 26;
    PRESENT_DEVICES_ONLY : constant Unsigned_32 := 0;
    MAX_ATTEMPTS : constant := 3;

    type List_Size_Function is access function
       (Length : in System.Address;
        Interface_Class : in System.Address;
        Device : in System.Address;
        Flags : in Unsigned_32) return Unsigned_32;
    pragma Convention (Stdcall, List_Size_Function);

    type List_Function is access function
       (Interface_Class : in System.Address;
        Device : in System.Address;
        Buffer : in System.Address;
        Buffer_Length : in Unsigned_32;
        Flags : in Unsigned_32) return Unsigned_32;
    pragma Convention (Stdcall, List_Function);

    function To_List_Size is new Ada.Unchecked_Conversion (System.Address, List_Size_Function);
    function To_List is new Ada.Unchecked_Conversion (System.Address, List_Function);

    --------------------------------------------------

    Device_Handle : HANDLE := INVALID_HANDLE_VALUE;
    Channel_Count : Storage_Offset := 0;
    Channel_Offset : Storage_Offset := 0;

    --------------------------------------------------

    -- Little endian, byte by byte: channels are packed and not aligned
    function Read_Unsigned
       (Buffer : in Storage_Array;
        Offset : in Storage_Offset;
        Size : in Storage_Offset) return Unsigned_64
    is
        Value : Unsigned_64 := 0;
    begin
        for Position in reverse 0 .. Size - 1 loop
            Value := Shift_Left (Value, 8) or Unsigned_64 (Buffer (Buffer'First + Offset + Position));
        end loop;

        return Value;
    end Read_Unsigned;

    --------------------------------------------------

    -- Returns False if the IOCTL fails
    function Control
       (Device : in HANDLE;
        Code : in DWORD;
        Buffer : in System.Address;
        Size : in DWORD;
        Returned : out DWORD) return Boolean
    is
        Bytes_Returned : aliased DWORD := 0;
        Result : BOOL;
    begin
        Returned := 0;

        if Device = INVALID_HANDLE_VALUE then
            return False;
        end if;

        Result := DeviceIoControl
           (hDevice => Device,
            dwIoControlCode => Code,
            lpInBuffer => System.Null_Address,
            nInBufferSize => 0,
            lpOutBuffer => Buffer,
            nOutBufferSize => Size,
            lpBytesReturned => Bytes_Returned'Address,
            lpOverlapped => System.Null_Address);

        if Result = 0 then
            return False;
        end if;

        Returned := Bytes_Returned;
        return True;
    end Control;

    --------------------------------------------------

    -- Raw counter in picowatt hours. Returns False if the IOCTL fails or answers short.
    function Read_Channel
       (Device : in HANDLE;
        Channels : in Storage_Offset;
        Offset : in Storage_Offset;
        Value : out Unsigned_64) return Boolean
    is
        Measurements : Storage_Array (1 .. MAX_CHANNELS * MEASUREMENT_SIZE) := (others => 0);
        Wanted : DWORD;
        Returned : DWORD;
    begin
        Value := 0;

        if Channels not in 1 .. MAX_CHANNELS
          or else Offset + MEASUREMENT_SIZE > Channels * MEASUREMENT_SIZE
        then
            return False;
        end if;

        Wanted := DWORD (Channels * MEASUREMENT_SIZE);

        if not Control (Device, IOCTL_EMI_GET_MEASUREMENT, Measurements'Address, Wanted, Returned) then
            return False;
        end if;

        if Returned /= Wanted then
            return False;
        end if;

        Value := Read_Unsigned (Measurements, Offset, 8);
        return True;
    end Read_Channel;

    --------------------------------------------------

    -- UTF-16 name, NUL-terminated within Size. Returns "" if malformed or not printable ASCII.
    function Channel_Name
       (Metadata : in Storage_Array;
        Offset : in Storage_Offset;
        Size : in Storage_Offset) return String
    is
        Result : String (1 .. MAX_NAME_LENGTH);
        Length : Natural := 0;
        Position : Storage_Offset := 0;
        Low : Storage_Element;
        High : Storage_Element;
    begin
        if Size mod 2 /= 0 then
            return "";
        end if;

        while Position + 2 <= Size loop
            Low := Metadata (Metadata'First + Offset + Position);
            High := Metadata (Metadata'First + Offset + Position + 1);

            if Low = 0 and then High = 0 then
                return Result (1 .. Length);
            end if;

            if High /= 0 or else Low not in 32 .. 126 or else Length = MAX_NAME_LENGTH then
                return "";
            end if;

            Length := Length + 1;
            Result (Length) := Character'Val (Integer (Low));
            Position := Position + 2;
        end loop;

        return "";
    end Channel_Name;

    --------------------------------------------------

    function Ends_With (Text : in String; Suffix : in String) return Boolean is
       (Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

    --------------------------------------------------

    -- Returns False if the metadata is malformed or has no package channel
    function Select_Channel
       (Metadata : in Storage_Array;
        Channels : out Storage_Offset;
        Index : out Storage_Offset) return Boolean
    is
        Count : constant Storage_Offset := Storage_Offset (Read_Unsigned (Metadata, CHANNEL_COUNT_OFFSET, 2));
        Offset : Storage_Offset := METADATA_HEADER_SIZE;
        Name_Size : Storage_Offset;
        Exact : Storage_Offset := -1; -- Exact name match
        Suffix : Storage_Offset := -1; -- First *_PKG match
    begin
        Channels := 0;
        Index := 0;

        if Count not in 1 .. MAX_CHANNELS then
            return False;
        end if;

        for Position in 0 .. Count - 1 loop
            if Offset + CHANNEL_HEADER_SIZE > Metadata'Length then
                return False;
            end if;

            if Read_Unsigned (Metadata, Offset, 4) /= EMI_UNIT_PICOWATT_HOURS then
                return False;
            end if;

            Name_Size := Storage_Offset (Read_Unsigned (Metadata, Offset + 4, 2));

            if Name_Size < 2 or else Offset + CHANNEL_HEADER_SIZE + Name_Size > Metadata'Length then
                return False;
            end if;

            declare
                Name : constant String := Channel_Name (Metadata, Offset + CHANNEL_HEADER_SIZE, Name_Size);
            begin
                if Name = PACKAGE_CHANNEL_NAME then
                    Exact := Position;
                elsif Suffix < 0 and then Ends_With (Name, PACKAGE_CHANNEL_SUFFIX) then
                    Suffix := Position;
                end if;
            end;

            Offset := Offset + CHANNEL_HEADER_SIZE + Name_Size;
        end loop;

        if Exact >= 0 then
            Index := Exact;
        elsif Suffix >= 0 then
            Index := Suffix;
        else
            return False;
        end if;

        Channels := Count;
        return True;
    end Select_Channel;

    --------------------------------------------------

    -- Check the meter publishes the RAPL package counter. Does not touch package state.
    function Examine
       (Device : in HANDLE;
        Channels : out Storage_Offset;
        Offset : out Storage_Offset) return Boolean
    is
        Version : aliased Unsigned_16 := 0;
        Metadata_Size : aliased Unsigned_32 := 0;
        Returned : DWORD;
    begin
        Channels := 0;
        Offset := 0;

        if not Control (Device, IOCTL_EMI_GET_VERSION, Version'Address, 2, Returned)
          or else Returned /= 2
          or else Version /= EMI_VERSION_V2
        then
            return False;
        end if;

        if not Control (Device, IOCTL_EMI_GET_METADATA_SIZE, Metadata_Size'Address, 4, Returned)
          or else Returned /= 4
          or else Metadata_Size <= METADATA_HEADER_SIZE
          or else Metadata_Size > MAX_METADATA_SIZE
        then
            return False;
        end if;

        declare
            Metadata : Storage_Array (1 .. Storage_Offset (Metadata_Size)) := (others => 0);
            Found : Storage_Offset;
            Counter : Unsigned_64;
        begin
            if not Control (Device, IOCTL_EMI_GET_METADATA, Metadata'Address, DWORD (Metadata_Size), Returned)
              or else Returned /= DWORD (Metadata_Size)
            then
                return False;
            end if;

            if not Select_Channel (Metadata, Channels, Found) then
                Channels := 0;
                return False;
            end if;

            Offset := Found * MEASUREMENT_SIZE;

            -- Reject a meter that reads zero
            if not Read_Channel (Device, Channels, Offset, Counter) or else Counter = 0 then
                Channels := 0;
                Offset := 0;
                return False;
            end if;

            return True;
        end;
    end Examine;

    --------------------------------------------------

    -- Keep the device if it is a RAPL meter, else close it
    function Try_Device (Path : in System.Address) return Boolean is
        Device : HANDLE;
        Channels : Storage_Offset := 0;
        Offset : Storage_Offset := 0;
        Kept : Boolean := False;
        Ignored : BOOL;
    begin
        Device := CreateFileW
           (lpFileName => Path,
            dwDesiredAccess => FILE_GENERIC_READ,
            dwShareMode => FILE_SHARE_READ or FILE_SHARE_WRITE,
            lpSecurityAttributes => System.Null_Address,
            dwCreationDisposition => OPEN_EXISTING,
            dwFlagsAndAttributes => 0,
            hTemplateFile => System.Null_Address);

        if Device = INVALID_HANDLE_VALUE then
            return False;
        end if;

        begin
            Kept := Examine (Device, Channels, Offset);
        exception
            when others =>
                Kept := False;
        end;

        if not Kept then
            Ignored := CloseHandle (Device);
            return False;
        end if;

        Device_Handle := Device;
        Channel_Count := Channels;
        Channel_Offset := Offset;
        return True;
    end Try_Device;

    --------------------------------------------------

    -- UTF-16 paths, each NUL-terminated, list ends with an empty one
    function Try_Devices (List : in Storage_Array) return Boolean is
        Offset : Storage_Offset := 0;
        Start : Storage_Offset;
    begin
        while Offset + 2 <= List'Length loop
            exit when List (List'First + Offset) = 0 and then List (List'First + Offset + 1) = 0;

            Start := Offset;

            while Offset + 2 <= List'Length
              and then not (List (List'First + Offset) = 0 and then List (List'First + Offset + 1) = 0)
            loop
                Offset := Offset + 2;
            end loop;

            -- Truncated path
            exit when Offset + 2 > List'Length;

            if Try_Device (List (List'First + Start)'Address) then
                return True;
            end if;

            Offset := Offset + 2;
        end loop;

        return False;
    end Try_Devices;

    --------------------------------------------------

    function Enumerate (Library : in System.Address) return Boolean is
        Get_Size : constant List_Size_Function :=
            To_List_Size (Find_Symbol (Library, "CM_Get_Device_Interface_List_SizeW"));
        Get_List : constant List_Function :=
            To_List (Find_Symbol (Library, "CM_Get_Device_Interface_ListW"));
        Length : aliased Unsigned_32 := 0;
        Status : Unsigned_32;
    begin
        if Get_Size = null or else Get_List = null then
            return False;
        end if;

        -- Retry if the list grew between the two calls
        for Attempt in 1 .. MAX_ATTEMPTS loop
            pragma Unreferenced (Attempt);

            Status := Get_Size
               (Length => Length'Address,
                Interface_Class => Energy_Meter_Name'Address,
                Device => System.Null_Address,
                Flags => PRESENT_DEVICES_ONLY);

            if Status /= CR_SUCCESS or else Length < 2 or else Length > MAX_LIST_CHARACTERS then
                return False;
            end if;

            declare
                -- Length is in wide characters
                List : Storage_Array (1 .. Storage_Offset (Length) * 2) := (others => 0);
            begin
                Status := Get_List
                   (Interface_Class => Energy_Meter_Name'Address,
                    Device => System.Null_Address,
                    Buffer => List'Address,
                    Buffer_Length => Length,
                    Flags => PRESENT_DEVICES_ONLY);

                if Status = CR_SUCCESS then
                    return Try_Devices (List);
                end if;

                if Status /= CR_BUFFER_SMALL then
                    return False;
                end if;
            end;
        end loop;

        return False;
    end Enumerate;

    --------------------------------------------------

    function Open return Boolean is
        Library : System.Address;
        Found : Boolean := False;
    begin
        -- Close any meter already open
        Close;

        Library := Load ("cfgmgr32.dll");

        if Library = System.Null_Address then
            return False;
        end if;

        begin
            Found := Enumerate (Library);
        exception
            when others =>
                Found := False;
        end;

        Unload (Library);

        if not Found then
            Close;
        end if;

        return Found;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
        Raw : Unsigned_64;
    begin
        if Device_Handle = INVALID_HANDLE_VALUE or else Channel_Count = 0 then
            return 0;
        end if;

        if not Read_Channel (Device_Handle, Channel_Count, Channel_Offset, Raw) then
            return 0;
        end if;

        -- 1 pWh = 9/2500 uJ, split so Raw * 9 cannot overflow
        return Long_Long_Integer (Raw / 2500) * 9
               + Long_Long_Integer ((Raw mod 2500) * 9 / 2500);
    end Read_Counter;

    --------------------------------------------------

    procedure Close is
        Ignored : BOOL;
    begin
        if Device_Handle /= INVALID_HANDLE_VALUE then
            Ignored := CloseHandle (Device_Handle);
            Device_Handle := INVALID_HANDLE_VALUE;
        end if;

        Channel_Count := 0;
        Channel_Offset := 0;
    end Close;

end Joular_Core.RAPL_EMI_Windows;
