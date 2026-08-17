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

package body Joular_Core is

    -- Library version number
    Version_Number : constant String := "0.0.1";

    -- Variable to check if Open was called and not yet closed
    Opened : Boolean := False;

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        Opened := True;
    end Open;

    --------------------------------------------------

    procedure Close is
    begin
        Opened := False;
    end Close;

    --------------------------------------------------

    function Read (Sources : in Source_List := All_Sources) return Reading is
        Result : Reading := (others => (others => <>));
    begin
        return Result;
    end Read;

    --------------------------------------------------

    function Is_Open return Boolean is
    begin
        return Opened;
    end Is_Open;

    --------------------------------------------------

    function Version return String is
    begin
        return Version_Number;
    end Version;

end Joular_Core;
