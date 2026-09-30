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

package body Joular_Core.C_API is

    use type Interfaces.C.int;

    -- The version as a NUL terminated C string, built once
    Version_C : aliased constant Interfaces.C.char_array := Interfaces.C.To_C (Version);

    --------------------------------------------------

    function To_C (Item : in Measurement) return C_Measurement is
        ((Value => Interfaces.C.double (Item.Value),
          Available => (if Item.Available then 1 else 0),
          Unit => (case Item.Unit is when Energy => 0, when Power => 1)));

    --------------------------------------------------

    -- No Ada exception may cross into the C caller, hence the handlers below

    procedure C_Open (Measure_CPU : Interfaces.C.int; Measure_GPU : Interfaces.C.int) is
    begin
        Open ((CPU => Measure_CPU /= 0, GPU => Measure_GPU /= 0));
    exception
        when others =>
            null;
    end C_Open;

    --------------------------------------------------

    procedure C_Read (Result : access C_Reading) is
        Data : Reading;
    begin
        if Result = null then
            return;
        end if;

        -- Zeros if anything fails below
        Result.all := (others => <>);

        Data := Read;

        Result.all := (CPU => To_C (Data (CPU)), GPU => To_C (Data (GPU)));
    exception
        when others =>
            null;
    end C_Read;

    --------------------------------------------------

    procedure C_Close is
    begin
        Close;
    exception
        when others =>
            null;
    end C_Close;

    --------------------------------------------------

    function C_Version return System.Address is
    begin
        return Version_C'Address;
    end C_Version;

end Joular_Core.C_API;
