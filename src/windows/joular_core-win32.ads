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

with Interfaces;
with Interfaces.C;
with System;
with System.Storage_Elements; use System.Storage_Elements;

-- The Win32 bits needed to talk to a driver
private package Joular_Core.Win32 is

    -- Win32 types and flags
    subtype HANDLE is System.Address; -- Win32 kernel object handle
    subtype DWORD is Interfaces.Unsigned_32; -- Win32 32 bits unsigned
    use type Interfaces.Unsigned_32; -- For the bit operations in Control_Code
    subtype BOOL is Interfaces.C.int; -- Win32 boolean, where zero is false

    -- Win32 unsigned that is as wide as a pointer: 64 bits on x64, 32 bits on x86
    type DWORD_PTR is mod 2 ** Standard'Address_Size;

    -- CreateFile returns (HANDLE) -1 on failure, not null
    INVALID_HANDLE_VALUE : constant HANDLE := To_Address (Integer_Address'Last);

    -- Flags for opening the device
    FILE_GENERIC_READ : constant DWORD := 16#0012_0089#;
    FILE_GENERIC_WRITE : constant DWORD := 16#0012_0116#;
    FILE_SHARE_READ : constant DWORD := 16#0000_0001#;
    FILE_SHARE_WRITE : constant DWORD := 16#0000_0002#;
    OPEN_EXISTING : constant DWORD := 3;

    -- From the WDK
    FILE_DEVICE_UNKNOWN : constant DWORD := 16#22#;
    METHOD_BUFFERED : constant DWORD := 0;

    -- CTL_CODE from the WDK
    function Control_Code
       (Device_Type : in DWORD;
        Request : in DWORD;
        Method : in DWORD;
        Access_Mode : in DWORD) return DWORD
    is (Interfaces.Shift_Left (Device_Type, 16)
        or Interfaces.Shift_Left (Access_Mode, 14)
        or Interfaces.Shift_Left (Request, 2)
        or Method);

    function CreateFileA
       (lpFileName : System.Address;
        dwDesiredAccess : DWORD;
        dwShareMode : DWORD;
        lpSecurityAttributes : System.Address;
        dwCreationDisposition : DWORD;
        dwFlagsAndAttributes : DWORD;
        hTemplateFile : System.Address) return HANDLE;
    pragma Import (Stdcall, CreateFileA, "CreateFileA");

    -- Windows publishes device paths in wide characters, so they are passed to this one unconverted
    function CreateFileW
       (lpFileName : System.Address;
        dwDesiredAccess : DWORD;
        dwShareMode : DWORD;
        lpSecurityAttributes : System.Address;
        dwCreationDisposition : DWORD;
        dwFlagsAndAttributes : DWORD;
        hTemplateFile : System.Address) return HANDLE;
    pragma Import (Stdcall, CreateFileW, "CreateFileW");

    -- One request to the driver; returns 0 on failure
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

    function CloseHandle (hObject : HANDLE) return BOOL;
    pragma Import (Stdcall, CloseHandle, "CloseHandle");

    function GetCurrentThread return HANDLE;
    pragma Import (Stdcall, GetCurrentThread, "GetCurrentThread");

    -- Which processors of which processor group a thread may run on
    type Reserved_Words is array (1 .. 3) of Interfaces.Unsigned_16;
    pragma Convention (C, Reserved_Words);

    type GROUP_AFFINITY is
       record
           Mask : DWORD_PTR;
           Group : Interfaces.Unsigned_16;
           Reserved : Reserved_Words;
       end record;
    pragma Convention (C, GROUP_AFFINITY);

    -- Pins the thread to the given group and mask, writes the previous affinity through the third argument (null to skip); 0 on failure
    function SetThreadGroupAffinity
       (hThread : HANDLE;
        GroupAffinity : System.Address;
        PreviousGroupAffinity : System.Address) return BOOL;
    pragma Import (Stdcall, SetThreadGroupAffinity, "SetThreadGroupAffinity");

end Joular_Core.Win32;
