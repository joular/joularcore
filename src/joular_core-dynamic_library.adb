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

with Interfaces.C; use Interfaces.C;

package body Joular_Core.Dynamic_Library is

#if PJ_WINDOWS then

    -- Only look for the library in the Windows system folder (System32), where the GPU drivers install them
    -- A plain LoadLibraryA would look in the program's own folder first, where a malicious library with the same name could have been planted
    LOAD_LIBRARY_SEARCH_SYSTEM32 : constant unsigned := 16#800#;

    -- For a library given by its full path: look in the folder, and in the folders the system trusts
    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR : constant unsigned := 16#100#;
    LOAD_LIBRARY_SEARCH_DEFAULT_DIRS : constant unsigned := 16#1000#;

    -- Windows specific functions to load libraries
    function LoadLibraryExA
       (lpLibFileName : System.Address;
        hFile : System.Address;
        dwFlags : unsigned) return System.Address;
    pragma Import (Stdcall, LoadLibraryExA, "LoadLibraryExA");

    function GetProcAddress (hModule : System.Address; lpProcName : System.Address) return System.Address;
    pragma Import (Stdcall, GetProcAddress, "GetProcAddress");

    function FreeLibrary (hLibModule : System.Address) return int;
    pragma Import (Stdcall, FreeLibrary, "FreeLibrary");

    --------------------------------------------------

    function Load (Name : in String) return System.Address is
        C_Name : aliased char_array := To_C (Name);
    begin
        return LoadLibraryExA (C_Name'Address, System.Null_Address, LOAD_LIBRARY_SEARCH_SYSTEM32);
    exception
        when others =>
            return System.Null_Address;
    end Load;

    --------------------------------------------------

    function Load_From_Path (Path : in String) return System.Address is
        C_Path : aliased char_array := To_C (Path);
    begin
        return LoadLibraryExA
           (C_Path'Address,
            System.Null_Address,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR or LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    exception
        when others =>
            return System.Null_Address;
    end Load_From_Path;

    --------------------------------------------------

    function Find_Symbol (Library : in System.Address; Name : in String) return System.Address is
        C_Name : aliased char_array := To_C (Name);
    begin
        return GetProcAddress (Library, C_Name'Address);
    exception
        when others =>
            return System.Null_Address;
    end Find_Symbol;

    --------------------------------------------------

    procedure Unload (Library : in System.Address) is
        Ignored : int;
    begin
        Ignored := FreeLibrary (Library);
    exception
        when others =>
            null;
    end Unload;

#else

    -- Functions from the C interface on Linux, macOS and BSD, needed to load libraries

    -- Flag given to dlopen (2 is the value of RTLD_NOW)
    -- It resolves every symbol of the library while it is being loaded (instead of the first call made to each of them, which is the case if the value was 1)
    -- Hence, a library missing a symbol would fail here instead of when calling that specific symbol later on
    RTLD_NOW : constant int := 2;

    function dlopen (filename : System.Address; flag : int) return System.Address;
    pragma Import (C, dlopen, "dlopen");

    function dlsym (handle : System.Address; symbol : System.Address) return System.Address;
    pragma Import (C, dlsym, "dlsym");

    function dlclose (handle : System.Address) return int;
    pragma Import (C, dlclose, "dlclose");

    -- On Linux specifically, dlopen used to be in libdl (before glibc 2.34), and in the C library after that
    -- Load libdl here so it will link and work on older glibc version
#if PJ_LINUX then
    pragma Linker_Options ("-ldl");
#end if;

    --------------------------------------------------

    function Load (Name : in String) return System.Address is
        C_Name : aliased char_array := To_C (Name);
    begin
        return dlopen (C_Name'Address, RTLD_NOW);
    exception
        when others =>
            return System.Null_Address;
    end Load;

    --------------------------------------------------

    -- A full path is what dlopen takes, and giving it one is what stops it from looking through the folders it would otherwise search
    -- Handing dlopen a full path is all Load already does here, unlike on Windows where the two need different flags
    function Load_From_Path (Path : in String) return System.Address is (Load (Path));

    --------------------------------------------------

    function Find_Symbol (Library : in System.Address; Name : in String) return System.Address is
        C_Name : aliased char_array := To_C (Name);
    begin
        return dlsym (Library, C_Name'Address);
    exception
        when others =>
            return System.Null_Address;
    end Find_Symbol;

    --------------------------------------------------

    procedure Unload (Library : in System.Address) is
        Ignored : int;
    begin
        Ignored := dlclose (Library);
    exception
        when others =>
            null;
    end Unload;

#end if;

end Joular_Core.Dynamic_Library;
