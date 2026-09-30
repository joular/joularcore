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

with Ada.Strings.Fixed;
with Interfaces.C; use Interfaces.C;

-- Windows
package body Joular_Core.Dynamic_Library is

    -- Only look in System32, where the GPU drivers install their libraries
    -- A plain LoadLibraryA looks in the program's own folder first, where a library of the same name could be planted
    LOAD_LIBRARY_SEARCH_SYSTEM32 : constant unsigned := 16#800#;

    -- For a library given by its full path: look in its own folder and in System32
    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR : constant unsigned := 16#100#;

    function LoadLibraryExA
       (lpLibFileName : char_array;
        hFile : System.Address;
        dwFlags : unsigned) return System.Address;
    pragma Import (Stdcall, LoadLibraryExA, "LoadLibraryExA");

    function GetProcAddress (hModule : System.Address; lpProcName : char_array) return System.Address;
    pragma Import (Stdcall, GetProcAddress, "GetProcAddress");

    function FreeLibrary (hLibModule : System.Address) return int;
    pragma Import (Stdcall, FreeLibrary, "FreeLibrary");

    --------------------------------------------------

    function Load (Name : in String) return System.Address is
        Is_Path : constant Boolean := Ada.Strings.Fixed.Index (Name, "\") > 0;
    begin
        return LoadLibraryExA
           (To_C (Name),
            System.Null_Address,
            (if Is_Path
             then LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR or LOAD_LIBRARY_SEARCH_SYSTEM32
             else LOAD_LIBRARY_SEARCH_SYSTEM32));
    end Load;

    --------------------------------------------------

    function Find_Symbol (Library : in System.Address; Name : in String) return System.Address is
    begin
        return GetProcAddress (Library, To_C (Name));
    end Find_Symbol;

    --------------------------------------------------

    procedure Unload (Library : in System.Address) is
        Ignored : int;
    begin
        Ignored := FreeLibrary (Library);
    end Unload;

end Joular_Core.Dynamic_Library;
