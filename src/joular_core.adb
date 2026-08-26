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

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Joular_Core.OS_Utils; use Joular_Core.OS_Utils;
with Joular_Core.CPU_Monitor; use Joular_Core.CPU_Monitor;
with Joular_Core.GPU_Monitor; use Joular_Core.GPU_Monitor;


package body Joular_Core is

    -- Library version number
    Version_Number : constant String := "0.0.1";

    -- Variable to check if Open was called and not yet closed
    Opened : Boolean := False;

    -- List of components asked to be measured
    Sources_List_Asked : Source_List := (others => False);

    -- List of components that can be read/accessed from the asked ones
    Sources_List_Accessible : Source_List := (others => False);

    -- CPU Platform
    Platform : Unbounded_String;

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        -- Set the list of hardware components asked and accessible
        Sources_List_Asked := Sources;
        Sources_List_Accessible := (others => False);

        -- Check and initialize CPU measurement
        if Sources_List_Asked (CPU) then
            -- Detect CPU vendor
            Platform := To_Unbounded_String (Get_Platform_CPU_Name);

            -- Check if CPU monitoring is available and accessible
            -- Also, this function will take a first reading on cumulative counters (i.e., RAPL)
            Sources_List_Accessible (CPU) := Detect_CPU (To_String (Platform));
        end if;

        -- Check and initialize GPU measurement
        if Sources_List_Asked (GPU) then
            -- Check if GPU monitoring is available and accessible
            -- Also, this function will load the libraries needed (NVML for Nvidia, ADLX for AMD) or check for GPU power files (hwmon sysfs for AMD)
            Sources_List_Accessible (GPU) := Detect_GPU;
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
        if Sources_List_Accessible (CPU) then
            CPU_Monitor.Stop_Monitoring;
        end if;
        
        if Sources_List_Accessible (GPU) then
            GPU_Monitor.Stop_Monitoring;
        end if;
        
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
        if Sources (CPU) and then Sources_List_Accessible (CPU) then
            Result (CPU) := Get_CPU_Reading;
        end if;
        
        if Sources (GPU) and then Sources_List_Accessible (GPU) then
            Result (GPU) := Get_GPU_Reading;
        end if;
        
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
