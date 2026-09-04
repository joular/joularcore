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

with Joular_Core.OS_Utils; use Joular_Core.OS_Utils;
with Joular_Core.CPU_Monitor; use Joular_Core.CPU_Monitor;
with Joular_Core.GPU_Monitor; use Joular_Core.GPU_Monitor;

package body Joular_Core is

    -- Library version number
    -- Keep it the same as the version in alire.toml
    Version_Number : constant String := "0.0.3";

    -- Variable to check if Open was called and not yet closed
    Opened : Boolean := False;

    -- List of components that can be read/accessed from the asked ones
    Sources_List_Accessible : Source_List := (others => False);

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        -- Close existing CPU and GPU sources if opened before and not closed for any reason
        CPU_Monitor.Stop_Monitoring;
        GPU_Monitor.Stop_Monitoring;
        
        -- Start with no hardware component accessible
        Sources_List_Accessible := (others => False);

        -- Check and initialize CPU measurement
        if Sources (CPU) then
            -- Detect the CPU vendor or board, then check if CPU monitoring is available and accessible
            -- Also, this function will take a first reading on cumulative counters (i.e., RAPL)
            Sources_List_Accessible (CPU) := Detect_CPU (Get_Platform_CPU_Name);
        end if;

        -- Check and initialize GPU measurement
        if Sources (GPU) then
            -- Check if GPU monitoring is available and accessible
            -- Also, this function will load the libraries needed (NVML for Nvidia, ADLX for AMD) or check for GPU power files (hwmon sysfs for AMD)
            Sources_List_Accessible (GPU) := Detect_GPU;
        end if;

        Opened := True;
    exception
        when others =>
            -- If anything failed halfway, stop the monitors so any driver or library already opened is closed
            -- Both procedures do nothing when their monitor was not started
            CPU_Monitor.Stop_Monitoring;
            GPU_Monitor.Stop_Monitoring;
            Sources_List_Accessible := (others => False);
            Opened := False;
    end Open;

    --------------------------------------------------

    procedure Close is
    begin
        CPU_Monitor.Stop_Monitoring;
        GPU_Monitor.Stop_Monitoring;
        
        Opened := False;
        Sources_List_Accessible := (others => False);
    exception
        when others =>
            Opened := False;
            Sources_List_Accessible := (others => False);
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
