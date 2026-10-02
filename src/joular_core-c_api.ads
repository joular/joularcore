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

-- The program loading the shared library owns the signals, not the library: the JVM relies on SIGSEGV and SIGBUS for null checks and safepoints, and Python expects its handlers to stay in place
-- Without this pragma, the Ada runtime would install its own handlers for SIGSEGV, SIGBUS, SIGFPE, SIGILL and SIGABRT when the library starts
-- It only applies where this unit is bound (the shared library), not to Ada programs using Joular_Core directly
-- The cost: a stack overflow or a bad memory access inside the library ends the process instead of raising an exception
pragma Interrupts_System_By_Default;

with Interfaces.C;
with System;

-- The C interface of the library, for any language with a C FFI (C, C++, Java, Python, Rust, etc.)
-- The C declarations are in include/joularcore.h
-- Ada programs use the Joular_Core package directly
package Joular_Core.C_API is

    -- Matches struct joularcore_measurement in joularcore.h
    -- Value first, so the record has no padding and the same layout on every target
    type C_Measurement is
       record
           Value : Interfaces.C.double := 0.0; -- Energy or power value
           Available : Interfaces.C.int := 0; -- 1 when the source was requested and opened, 0 otherwise
           Unit : Interfaces.C.int := 0; -- 0 when Value is energy in joules, 1 when it is power in watts
       end record
       with Convention => C;

    -- Matches struct joularcore_reading in joularcore.h
    type C_Reading is
       record
           CPU : C_Measurement;
           GPU : C_Measurement;
       end record
       with Convention => C;

    -- Same as Joular_Core.Open: a hardware source is measured when its flag is not zero
    procedure C_Open (Measure_CPU : Interfaces.C.int; Measure_GPU : Interfaces.C.int)
       with Export, Convention => C, External_Name => "joularcore_open";

    -- Same as Joular_Core.Read: writes one reading of every source into Result
    procedure C_Read (Result : access C_Reading)
       with Export, Convention => C, External_Name => "joularcore_read";

    -- Same as Joular_Core.Close
    procedure C_Close
       with Export, Convention => C, External_Name => "joularcore_close";

    -- Same as Joular_Core.Version: a C string owned by the library (the caller must not free it)
    function C_Version return System.Address
       with Export, Convention => C, External_Name => "joularcore_version";

end Joular_Core.C_API;
