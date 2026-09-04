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

-- Variables and functions in Win32 needed to talk to a driver, shared by the drivers that read the registers on Windows
private package Joular_Core.Win32 is

    -- Win32 types and flags
    subtype HANDLE is System.Address; -- Win32 kernel object handle
    subtype DWORD is Interfaces.Unsigned_32; -- Win32 32 bits unsigned
    subtype BOOL is Interfaces.C.int; -- Win32 boolean, where zero is false

    -- Win32 unsigned that is as wide as a pointer: 64 bits on x64, 32 bits on x86
    type DWORD_PTR is mod 2 ** Standard'Address_Size;

    -- What CreateFileA returns when it could not open what was asked of it, which is the handle (HANDLE) -1 rather than a null pointer
    INVALID_HANDLE_VALUE : constant HANDLE := To_Address (Integer_Address'Last); -- (HANDLE) -1

    -- Flags for opening the device
    FILE_GENERIC_READ : constant DWORD := 16#0012_0089#;
    FILE_GENERIC_WRITE : constant DWORD := 16#0012_0116#;
    FILE_SHARE_READ : constant DWORD := 16#0000_0001#;
    FILE_SHARE_WRITE : constant DWORD := 16#0000_0002#;
    OPEN_EXISTING : constant DWORD := 3;

#if PJ_WINDOWS then

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

    --  Sends one request to the driver: the control code says what to do, the input buffer carries what the request needs, and the driver writes its answer into the output buffer. Returns zero when the request failed
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

    --  The handle of the thread calling it
    function GetCurrentThread return HANDLE;
    pragma Import (Stdcall, GetCurrentThread, "GetCurrentThread");

    --  Restricts the thread to the processors of the given mask, and gives back the mask it was restricted to before, or zero when it failed
    function SetThreadAffinityMask
       (hThread : HANDLE;
        dwThreadAffinityMask : DWORD_PTR) return DWORD_PTR;
    pragma Import (Stdcall, SetThreadAffinityMask, "SetThreadAffinityMask");

#end if;

end Joular_Core.Win32;
