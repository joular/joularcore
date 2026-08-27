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

with Interfaces.C;
with System;

-- The C interface of the library, so it can be used from any language with a C FFI (C, C++, Java, Python, Rust, etc.)
-- The C declarations of these functions are in include/joularcore.h
-- Ada programs should use the Joular_Core package directly instead of this one
package Joular_Core.C_API is

    -- One measurement in C, matches struct joular_measurement in joularcore.h
    type C_Measurement is
       record
           Available : Interfaces.C.int := 0; -- 1 when the source was requested and read, 0 otherwise
           Value : Interfaces.C.double := 0.0; -- Energy or power value
           Unit : Interfaces.C.int := 0; -- 0 when Value is energy in joules, 1 when it is power in watts
       end record
       with Convention => C;

    -- One reading of every hardware source in C, matches struct joular_reading in joularcore.h
    type C_Reading is
       record
           CPU : C_Measurement;
           GPU : C_Measurement;
       end record
       with Convention => C;

    -- Same as Joular_Core.Open: a hardware source is measured when its flag is not zero
    procedure C_Open (Measure_CPU : Interfaces.C.int; Measure_GPU : Interfaces.C.int)
       with Export, Convention => C, External_Name => "joular_open";

    -- Same as Joular_Core.Read: writes one reading of every source into Result
    procedure C_Read (Result : access C_Reading)
       with Export, Convention => C, External_Name => "joular_read";

    -- Same as Joular_Core.Close
    procedure C_Close
       with Export, Convention => C, External_Name => "joular_close";

    -- Same as Joular_Core.Is_Open: returns 1 when open, 0 otherwise
    function C_Is_Open return Interfaces.C.int
       with Export, Convention => C, External_Name => "joular_is_open";

    -- Same as Joular_Core.Version: returns the version as a C string owned by the library (the caller must not free it)
    function C_Version return System.Address
       with Export, Convention => C, External_Name => "joular_version";

end Joular_Core.C_API;
