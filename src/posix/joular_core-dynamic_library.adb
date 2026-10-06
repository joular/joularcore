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

-- Linux, macOS and FreeBSD
package body Joular_Core.Dynamic_Library is

    -- Resolve every symbol at load, so a library missing one fails in dlopen rather than on a later call
    RTLD_NOW : constant int := 2;

    function dlopen (filename : char_array; flag : int) return System.Address;
    pragma Import (C, dlopen, "dlopen");

    function dlsym (handle : System.Address; symbol : char_array) return System.Address;
    pragma Import (C, dlsym, "dlsym");

    function dlclose (handle : System.Address) return int;
    pragma Import (C, dlclose, "dlclose");

    -- dlopen moved from libdl into libc in glibc 2.34; link libdl so older glibc still links
#if PJ_LINUX then
    pragma Linker_Options ("-ldl");
#end if;

    --------------------------------------------------

    -- A full path stops dlopen from looking through the folders it would otherwise search
    function Load (Name : in String) return System.Address is
    begin
        return dlopen (To_C (Name), RTLD_NOW);
    end Load;

    --------------------------------------------------

    function Find_Symbol (Library : in System.Address; Name : in String) return System.Address is
    begin
        return dlsym (Library, To_C (Name));
    end Find_Symbol;

    --------------------------------------------------

    procedure Unload (Library : in System.Address) is
        Ignored : int;
    begin
        Ignored := dlclose (Library);
    end Unload;

end Joular_Core.Dynamic_Library;
