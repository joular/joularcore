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

    type CPU_Backend is (No_CPU_Backend, RAPL, Raspberry_Pi);

    Detected_CPU_Backend : CPU_Backend := No_CPU_Backend;

    function Is_Raspberry_Pi return Boolean is
        Model_File : Ada.Text_IO.File_Type;
    begin
        if Ada.Directories.Exists ("/sys/firmware/devicetree/base/model") then
            Ada.Text_IO.Open
              (Model_File,
               Ada.Text_IO.In_File,
               "/sys/firmware/devicetree/base/model");
        elsif Ada.Directories.Exists ("/proc/device-tree/model") then
            Ada.Text_IO.Open
              (Model_File, Ada.Text_IO.In_File, "/proc/device-tree/model");
        else
            return False;
        end if;

        declare
            Model : constant String := Ada.Text_IO.Get_Line (Model_File);
        begin
            Ada.Text_IO.Close (Model_File);
            return Ada.Strings.Fixed.Index (Model, "Raspberry Pi") /= 0;
        end;
    exception
        when others =>
            if Ada.Text_IO.Is_Open (Model_File) then
                Ada.Text_IO.Close (Model_File);
            end if;
            return False;
    end Is_Raspberry_Pi;

    function Detect_CPU return CPU_Backend is
    begin
        if Ada.Directories.Exists ("/sys/class/powercap/intel-rapl")
          or else Ada.Directories.Exists ("/sys/class/powercap/intel-rapl:0")
          or else Ada.Directories.Exists ("/sys/class/powercap/amd-rapl")
          or else Ada.Directories.Exists ("/sys/class/powercap/amd-rapl:0")
        then
            return RAPL;
        elsif Is_Raspberry_Pi then
            return Raspberry_Pi;
        else
            return No_CPU_Backend;
        end if;
    end Detect_CPU;

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        -- Set the list of hardware components asked and accessible
        Sources_List_Asked := Sources;
        Sources_List_Accessible := (others => False);

        -- Check and initialize CPU measurement
        if Sources_List_Asked (CPU) then
            Detected_CPU_Backend := Detect_CPU;
            -- TODO: set Sources_List_Accessible (CPU) to True
        end if;

        -- Check and initialize GPU measurement
        if Sources_List_Asked (GPU) then
            null;
            -- TODO: call GPU detection
            -- TODO: set Sources_List_Accessible (GPU) to True
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
