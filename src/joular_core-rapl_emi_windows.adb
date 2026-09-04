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

with Ada.Unchecked_Conversion;

with Interfaces; use Interfaces;
with Interfaces.C; use type Interfaces.C.int;
with System; use System;
with System.Storage_Elements; use System.Storage_Elements;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;
with Joular_Core.Win32; use Joular_Core.Win32;

#end if;

package body Joular_Core.RAPL_EMI_Windows is

#if PJ_WINDOWS then

    -- The name Windows publishes energy meters under, as it is written in emi.h of the Windows kit
    -- {45BD8344-7ED6-49CF-A440-C276C933B053}
    -- A meter is not a file with a path of its own: it is asked for by this name, and Windows gives back the path of every meter present
    type GUID is
       record
           Data1 : Unsigned_32;
           Data2 : Unsigned_16;
           Data3 : Unsigned_16;
           Data4 : Storage_Array (1 .. 8);
       end record;

    -- Laid out specifically here rather than left to the compiler, as Windows reads these bytes as they are
    for GUID use
       record
           Data1 at 0 range 0 .. 31;
           Data2 at 4 range 0 .. 15;
           Data3 at 6 range 0 .. 15;
           Data4 at 8 range 0 .. 63;
       end record;

    for GUID'Size use 128;
    for GUID'Alignment use 4;

    -- Not a constant, as Windows takes the address of a name it may write to, even though it does not write to this one
    Energy_Meter_Name : aliased GUID :=
       (Data1 => 16#45BD_8344#,
        Data2 => 16#7ED6#,
        Data3 => 16#49CF#,
        Data4 => (16#A4#, 16#40#, 16#C2#, 16#76#, 16#C9#, 16#33#, 16#B0#, 16#53#));

    --------------------------------------------------

    -- The device type the meters answer to, and how their requests carry their buffers and what they are allowed to do, all as they are written in emi.h
    FILE_DEVICE_UNKNOWN : constant DWORD := 16#22#;
    METHOD_BUFFERED : constant DWORD := 0;
    FILE_READ_ACCESS : constant DWORD := 1;

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

    -- Which version of the interface the meter answers
    IOCTL_EMI_GET_VERSION : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 0, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4000#

    -- How much room the description of the meter takes
    IOCTL_EMI_GET_METADATA_SIZE : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 1, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4004#

    -- The description of the meter, which says what its channels are and what they are called
    IOCTL_EMI_GET_METADATA : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 2, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_4008#

    -- The counters of every channel of the meter
    IOCTL_EMI_GET_MEASUREMENT : constant DWORD :=
        Control_Code (FILE_DEVICE_UNKNOWN, 3, METHOD_BUFFERED, FILE_READ_ACCESS); -- 16#22_400C#

    --------------------------------------------------

    -- The version of the interface publishing one channel per RAPL domain
    -- The earlier version publishes a single channel, which is a meter built into the machine (a board rail, a battery) rather than a RAPL domain, so it is turned down along with everything else that is not a RAPL package counter
    EMI_VERSION_V2 : constant Unsigned_16 := 2;

    -- The only unit the interface defines, which is picowatt hours
    -- A meter counting in another one would be read as if it were counting in this one, so it is turned down instead
    EMI_UNIT_PICOWATT_HOURS : constant Unsigned_32 := 0;

    -- Where the description of a meter carries how many channels it has, and where those channels start, both counted from its beginning
    CHANNEL_COUNT_OFFSET : constant := 66;
    METADATA_HEADER_SIZE : constant := 68;

    -- What each channel carries before the name it ends with: the unit it counts in, then how many bytes it kept for that name
    CHANNEL_HEADER_SIZE : constant := 6;

    -- What the counter of one channel takes: the energy, then the moment it was taken at
    MEASUREMENT_SIZE : constant := 16;

    -- The channel of the package domain of the first socket, which is the one the library reports
    PACKAGE_CHANNEL_NAME : constant String := "RAPL_Package0_PKG";

    -- What the package domain of any socket is called, in case a machine numbers its sockets in another way than the one above
    PACKAGE_CHANNEL_SUFFIX : constant String := "_PKG";

    -- Nothing this package reads is asked of the machine without a bound, so a meter answering something out of all proportion is turned down rather than followed
    -- The meter of Windows 11 has four channels and describes itself in about five hundred bytes, so these are guards and not limits
    MAX_CHANNELS : constant := 32;
    MAX_METADATA_SIZE : constant := 65_536;
    MAX_NAME_LENGTH : constant := 128;
    MAX_LIST_CHARACTERS : constant := 32_768;

    --------------------------------------------------

    -- The functions of the configuration manager of Windows, which gives the paths of the meters present
    -- They are found in the library rather than linked to, so nothing has to be added to the link of a program using Joular Core

    -- What the configuration manager answers when a call went through
    CR_SUCCESS : constant Unsigned_32 := 0;

    -- What it answers when the list grew between being measured and being asked for
    CR_BUFFER_SMALL : constant Unsigned_32 := 26;

    -- Only the meters present in the machine, and not the ones it once had
    PRESENT_DEVICES_ONLY : constant Unsigned_32 := 0;

    -- How many times the list is asked for again when it grew while being read
    MAX_ATTEMPTS : constant := 3;

    -- How many characters the list of the paths takes
    type List_Size_Function is access function
       (Length : in System.Address;
        Interface_Class : in System.Address;
        Device : in System.Address;
        Flags : in Unsigned_32) return Unsigned_32;
    pragma Convention (Stdcall, List_Size_Function);

    -- The list itself, as the paths one after the other in wide characters, ending on an empty one
    type List_Function is access function
       (Interface_Class : in System.Address;
        Device : in System.Address;
        Buffer : in System.Address;
        Buffer_Length : in Unsigned_32;
        Flags : in Unsigned_32) return Unsigned_32;
    pragma Convention (Stdcall, List_Function);

    -- A function found in a library is an address, so needs to be converted to the function it is
    function To_List_Size is new Ada.Unchecked_Conversion (System.Address, List_Size_Function);
    function To_List is new Ada.Unchecked_Conversion (System.Address, List_Function);

    --------------------------------------------------

    -- The meter being read (one for the whole program, and not per read)
    Device_Handle : HANDLE := INVALID_HANDLE_VALUE;

    -- How many channels that meter has, which is how much it writes when its counters are asked for
    Channel_Count : Storage_Offset := 0;

    -- Where the counter of the channel being read sits in what the meter writes
    Channel_Offset : Storage_Offset := 0;

    --------------------------------------------------

    -- Read one number out of a buffer, least meaningful byte first, which is the order the interface writes them in
    -- Read byte by byte rather than laid over the buffer, so nothing depends on where that buffer happens to sit in memory: the channels of a description follow one another with no room left between them, so most of them start at an address a number could not be read from directly

    function Read_16 (Buffer : in Storage_Array; Offset : in Storage_Offset) return Unsigned_16 is
        Value : Unsigned_16 := 0;
    begin
        for Position in reverse 0 .. 1 loop
            Value := Shift_Left (Value, 8)
                     or Unsigned_16 (Buffer (Buffer'First + Offset + Storage_Offset (Position)));
        end loop;

        return Value;
    end Read_16;

    --------------------------------------------------

    function Read_32 (Buffer : in Storage_Array; Offset : in Storage_Offset) return Unsigned_32 is
        Value : Unsigned_32 := 0;
    begin
        for Position in reverse 0 .. 3 loop
            Value := Shift_Left (Value, 8)
                     or Unsigned_32 (Buffer (Buffer'First + Offset + Storage_Offset (Position)));
        end loop;

        return Value;
    end Read_32;

    --------------------------------------------------

    function Read_64 (Buffer : in Storage_Array; Offset : in Storage_Offset) return Unsigned_64 is
        Value : Unsigned_64 := 0;
    begin
        for Position in reverse 0 .. 7 loop
            Value := Shift_Left (Value, 8)
                     or Unsigned_64 (Buffer (Buffer'First + Offset + Storage_Offset (Position)));
        end loop;

        return Value;
    end Read_64;

    --------------------------------------------------

    -- Send one request to a meter, which takes nothing and writes its answer into the given buffer
    -- Returns False when the meter would not answer, leaving Returned at zero
    function Control
       (Device : in HANDLE;
        Code : in DWORD;
        Buffer : in System.Address;
        Size : in DWORD;
        Returned : out DWORD) return Boolean
    is
        Bytes_Returned : aliased DWORD := 0; -- How much the meter actually wrote
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
    exception
        when others =>
            Returned := 0;
            return False;
    end Control;

    --------------------------------------------------

    -- Read the counter of one channel of a meter, in the picowatt hours the interface counts in
    -- Returns False when the meter would not answer, or answered with less than the one counter per channel it is to write, leaving Value at zero
    function Read_Channel
       (Device : in HANDLE;
        Channels : in Storage_Offset;
        Offset : in Storage_Offset;
        Value : out Unsigned_64) return Boolean
    is
        -- Room for the counters of a meter with as many channels as this package follows, taken here rather than kept, as a reading needs it only while it lasts
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

        -- The meter writes one counter per channel and says how much it wrote, so an answer that is not that whole cannot be trusted to hold the channel being read
        if Returned /= Wanted then
            return False;
        end if;

        Value := Read_64 (Measurements, Offset);
        return True;
    exception
        when others =>
            Value := 0;
            return False;
    end Read_Channel;

    --------------------------------------------------

    -- Read the name a channel carries into plain characters
    -- The interface writes it in wide characters and ends it with a zero, which has to be inside the bytes the channel kept for it
    -- Returns nothing when it does not, or when the name carries anything that is not a plain character, neither of which the names of this interface do
    -- Size is what the channel kept for the name, which is not how long that name is: the meter of Windows 11 keeps a hundred bytes for every one of them
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
        -- Two bytes to each character, so an odd count is not a name
        if Size mod 2 /= 0 then
            return "";
        end if;

        while Position + 2 <= Size loop
            Low := Metadata (Metadata'First + Offset + Position);
            High := Metadata (Metadata'First + Offset + Position + 1);

            -- The zero ending the name, so the name is what came before it
            if Low = 0 and then High = 0 then
                return Result (1 .. Length);
            end if;

            -- Anything outside the plain printable characters is not one of the names looked for here
            if High /= 0 or else Low not in 32 .. 126 or else Length = MAX_NAME_LENGTH then
                return "";
            end if;

            Length := Length + 1;
            Result (Length) := Character'Val (Integer (Low));
            Position := Position + 2;
        end loop;

        -- No zero inside what the channel kept for it, so where the name ends cannot be told
        return "";
    end Channel_Name;

    --------------------------------------------------

    function Ends_With (Text : in String; Suffix : in String) return Boolean is
       (Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

    --------------------------------------------------

    -- Walk the description of a meter and find the channel holding the RAPL package counter
    -- Returns False when anything in that description does not hold together, and when the meter has no such channel, which is what leaves a machine carrying a meter of its own to the drivers reaching the registers
    function Select_Channel
       (Metadata : in Storage_Array;
        Channels : out Storage_Offset;
        Index : out Storage_Offset) return Boolean
    is
        Count : constant Storage_Offset := Storage_Offset (Read_16 (Metadata, CHANNEL_COUNT_OFFSET));
        Offset : Storage_Offset := METADATA_HEADER_SIZE;
        Name_Size : Storage_Offset;
        Exact : Storage_Offset := -1; -- The channel named as the first socket names it
        Suffix : Storage_Offset := -1; -- The first channel named as a package domain of any socket
    begin
        Channels := 0;
        Index := 0;

        -- A meter with no channel has nothing to read, and one with more channels than any meter carries is not one this package makes sense of
        if Count not in 1 .. MAX_CHANNELS then
            return False;
        end if;

        for Position in 0 .. Count - 1 loop
            -- What a channel says of itself has to be inside what the meter wrote
            if Offset + CHANNEL_HEADER_SIZE > Metadata'Length then
                return False;
            end if;

            if Read_32 (Metadata, Offset) /= EMI_UNIT_PICOWATT_HOURS then
                return False;
            end if;

            Name_Size := Storage_Offset (Read_16 (Metadata, Offset + 4));

            -- A name takes at least the zero ending it, and has to be inside what the meter wrote as well
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

            -- The channels follow one another with nothing in between, each as long as the name it kept room for
            Offset := Offset + CHANNEL_HEADER_SIZE + Name_Size;
        end loop;

        if Exact >= 0 then
            Index := Exact;
        elsif Suffix >= 0 then
            Index := Suffix;
        else
            -- The meter measures something, but not a RAPL package counter, and what it does measure is not the processor package this library reports
            return False;
        end if;

        Channels := Count;
        return True;
    end Select_Channel;

    --------------------------------------------------

    -- Check that an opened meter is one publishing the RAPL package counter, and say which channel that is
    -- Nothing the package keeps is written here, so a meter that is only being looked at never leaves the library half set up behind it
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

        -- First, which version of the interface this meter answers
        if not Control (Device, IOCTL_EMI_GET_VERSION, Version'Address, 2, Returned)
          or else Returned /= 2
          or else Version /= EMI_VERSION_V2
        then
            return False;
        end if;

        -- Then, how much the description of the meter takes, which has to hold at least the header every description starts with
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
            -- Then, the description itself, which the meter is to write whole
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

            -- Then, take a first reading and check the counter is not empty, as a meter that opens and describes itself but reads nothing is of no use here
            if not Read_Channel (Device, Channels, Offset, Counter) or else Counter = 0 then
                Channels := 0;
                Offset := 0;
                return False;
            end if;

            return True;
        end;
    end Examine;

    --------------------------------------------------

    -- Open one meter and keep it when it is the one publishing the RAPL package counter
    -- The handle is closed again when it is not, so the next meter of the list can be looked at in turn
    function Try_Device (Path : in System.Address) return Boolean is
        Device : HANDLE;
        Channels : Storage_Offset := 0;
        Offset : Storage_Offset := 0;
        Kept : Boolean := False;
        Ignored : BOOL;
    begin
        -- Windows gives the paths of the meters in wide characters, so they are passed on as they are rather than being converted
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
    exception
        when others =>
            return False;
    end Try_Device;

    --------------------------------------------------

    -- Walk the paths Windows gave and look at each meter in turn, keeping the first one publishing the RAPL package counter
    -- The paths follow one another in wide characters, each ending on a zero, and the list ends on an empty one
    function Try_Devices (List : in Storage_Array) return Boolean is
        Offset : Storage_Offset := 0;
        Start : Storage_Offset;
    begin
        while Offset + 2 <= List'Length loop
            -- A zero where a path would start is the empty one ending the list
            exit when List (List'First + Offset) = 0 and then List (List'First + Offset + 1) = 0;

            Start := Offset;

            -- Walk to the zero ending this path, two bytes at a time as it is written in wide characters
            while Offset + 2 <= List'Length
              and then not (List (List'First + Offset) = 0 and then List (List'First + Offset + 1) = 0)
            loop
                Offset := Offset + 2;
            end loop;

            -- A path that does not end inside the list is one the list was cut short of, so stop rather than hand it over as though it were whole
            exit when Offset + 2 > List'Length;

            if Try_Device (List (List'First + Start)'Address) then
                return True;
            end if;

            -- Past the zero ending this path, which is where the next one starts
            Offset := Offset + 2;
        end loop;

        return False;
    end Try_Devices;

    --------------------------------------------------

    -- Ask Windows for the meters present and look at each of them
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

        -- The list can grow between being measured and being asked for, which Windows says by turning the second call down, so it is measured again and asked for again a few times before giving up
        for Attempt in 1 .. MAX_ATTEMPTS loop
            pragma Unreferenced (Attempt);

            Status := Get_Size
               (Length => Length'Address,
                Interface_Class => Energy_Meter_Name'Address,
                Device => System.Null_Address,
                Flags => PRESENT_DEVICES_ONLY);

            -- A list of one character cannot even hold the empty path ending it, so there is no meter in this machine
            if Status /= CR_SUCCESS or else Length < 2 or else Length > MAX_LIST_CHARACTERS then
                return False;
            end if;

            declare
                -- Two bytes to each character, as the paths are written in wide characters
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

                -- Anything other than the list having grown will not be helped by asking again
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
        -- Opening again while a meter is already open would leave that one behind, so close first
        Close;

        -- The functions giving the paths of the meters are found in the library rather than linked to
        -- Only the system folder is looked in, which is where Windows keeps it
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

        -- The paths were read into buffers of this package, and the handle kept is not the library's, so nothing needs it any more
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

    function Max_Energy_Range return Long_Long_Integer is
    begin
        -- The interface hands over a counter of 64 bits that Windows has already added up across the wraps of the register behind it
        -- At a kilowatt it would take some hundreds of years to wrap in turn, so there is no wrap to correct here, which is what zero says
        return 0;
    end Max_Energy_Range;

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

        -- One picowatt hour is 3.6 nanojoules, which is 9/2500 of a microjoule
        -- Above this the multiplication below would not fit in the type the library reports in
        -- It stands for some nine thousand million million joules, which is a few hundred years of a machine drawing a kilowatt, so it is a guard and not a limit
        if Raw = 0 or else Raw > 2_500_000_000_000_000_000 then
            return 0;
        end if;

        -- Raw * 9 / 2500, split in two so what is multiplied stays small whatever the counter has added up to
        -- Both parts together give the very same number the one multiplication would
        return Long_Long_Integer (Raw / 2500) * 9
               + Long_Long_Integer ((Raw mod 2500) * 9 / 2500);
    exception
        when others =>
            return 0;
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
    exception
        when others =>
            Device_Handle := INVALID_HANDLE_VALUE;
            Channel_Count := 0;
            Channel_Offset := 0;
    end Close;

#else

    -- Interface of Windows only, so return 0 or nothing if called from another platform

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

end Joular_Core.RAPL_EMI_Windows;
