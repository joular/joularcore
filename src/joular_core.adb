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

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Joular_Core is

    -- Library version number
    Version_Number : constant String := "0.0.1";

    -- Variable to check if Open was called and not yet closed
    Opened : Boolean := False;

    -- List of components asked to be measured
    Sources_List_Asked : Source_List := (others => False);

    -- List of components that can be read/accessed from the asked ones
    Sources_List_Accessible : Source_List := (others => False);

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        -- Set the list of hardware components asked and accessible
        Sources_List_Asked := Sources;
        Sources_List_Accessible := (others => False);

        -- Check and initialize CPU measurement
        if Sources_List_Asked (CPU) then
            -- TODO: Detect CPU vendor
            -- TODO: set Sources_List_Accessible (CPU) to True
            null;
        end if;

        -- Check and initialize GPU measurement
        if Sources_List_Asked (GPU) then
            -- TODO: call GPU detection
            -- TODO: set Sources_List_Accessible (GPU) to True
            null;
        end if;

        Opened := True;
    exception
        when others =>
            Sources_List_Accessible := (others => False);
            Opened := True;
    end Open;

    --------------------------------------------------

    procedure Close is
    begin
        Opened := False;
        Sources_List_Asked := (others => False);
        Sources_List_Accessible := (others => False);
    exception
        when others =>
            Opened := False;
    end Close;

    --------------------------------------------------

    function Read (Sources : in Source_List := All_Sources) return Reading is
        Result : Reading := (others => (others => <>));
    begin
        return Result;
    exception
        when others =>
            return (others => (others => <>));
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
