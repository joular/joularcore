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

#if PJ_LINUX or PJ_WINDOWS or PJ_BSD then
with Interfaces.C; use Interfaces.C;
with Ada.Unchecked_Conversion;
with System; use System;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;
#end if;

package body Joular_Core.GPU_Nvidia_NVML is

#if PJ_LINUX or PJ_WINDOWS or PJ_BSD then

    -- NVML returns zero when a call succeeded
    NVML_SUCCESS : constant int := 0;

    -- Functions needed for NVML
    type Init_Function is access function return int;
    pragma Convention (C, Init_Function);

    type Shutdown_Function is access function return int;
    pragma Convention (C, Shutdown_Function);

    type Handle_Function is access function (Index : unsigned; Device : access System.Address) return int;
    pragma Convention (C, Handle_Function);

    type Power_Function is access function (Device : System.Address; Milliwatts : access unsigned) return int;
    pragma Convention (C, Power_Function);

    -- A function found in the NVML library is an address, so needs to be converted to the function it is
    function To_Init is new Ada.Unchecked_Conversion (System.Address, Init_Function);
    function To_Shutdown is new Ada.Unchecked_Conversion (System.Address, Shutdown_Function);
    function To_Handle is new Ada.Unchecked_Conversion (System.Address, Handle_Function);
    function To_Power is new Ada.Unchecked_Conversion (System.Address, Power_Function);

    --------------------------------------------------

    -- The loaded NVML library
    NVML_Library : System.Address := System.Null_Address;

    -- The function stopping NVML
    NVML_Shutdown : Shutdown_Function := null;

    -- The function reading the power consumption of the GPU card
    NVML_Device_Power : Power_Function := null;

    -- The GPU card being read
    Card : aliased System.Address := System.Null_Address;

    --------------------------------------------------

    -- Load NVML (requires the Nvidia driver being installed)
    -- Return the null address when the driver is not installed in the machine
    function Load_NVML return System.Address is
    begin
#if PJ_WINDOWS then
        -- On Windows, the library is in the system folder as a DLL
        return Load ("nvml.dll");
#else
        -- On Linux and BSD, the versioned name is the one always present
        declare
            Library : constant System.Address := Load ("libnvidia-ml.so.1");
        begin
            if Library /= System.Null_Address then
                return Library;
            end if;

            return Load ("libnvidia-ml.so");
        end;
#end if;
    end Load_NVML;

    --------------------------------------------------

    function Is_Accessible return Boolean is
        Start_NVML : Init_Function;
        Stop_NVML : Shutdown_Function;
        Get_Handle : Handle_Function;
        Milliwatts : aliased unsigned := 0;
    begin
        -- Just in case detecting is called twice, then close previous one so the library isn't loaded multiple times
        Close;

        -- Load NVML library
        NVML_Library := Load_NVML;

        if NVML_Library = System.Null_Address then
            return False;
        end if;

        -- Then, find the functions needed in the library
        Start_NVML := To_Init (Find_Symbol (NVML_Library, "nvmlInit_v2"));
        Stop_NVML := To_Shutdown (Find_Symbol (NVML_Library, "nvmlShutdown"));
        Get_Handle := To_Handle (Find_Symbol (NVML_Library, "nvmlDeviceGetHandleByIndex_v2"));
        NVML_Device_Power := To_Power (Find_Symbol (NVML_Library, "nvmlDeviceGetPowerUsage"));

        -- Verify that all needed functions are found
        if Start_NVML = null or else Stop_NVML = null or else Get_Handle = null or else NVML_Device_Power = null
        then
            Close;
            return False;
        end if;

        -- Then, start NVML
        if Start_NVML.all /= NVML_SUCCESS then
            Close;
            return False;
        end if;

        -- NVML started, so keep the function closing it
        NVML_Shutdown := Stop_NVML;

        -- Then, get the main card (first one listed by NVML)
        -- Verify that is can reported power consumption
        if Get_Handle (0, Card'Access) /= NVML_SUCCESS or else NVML_Device_Power (Card, Milliwatts'Access) /= NVML_SUCCESS
        then
            Close;
            return False;
        end if;

        return True;
    exception
        when others =>
            Close;
            return False;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Power return Long_Float is
        Milliwatts : aliased unsigned := 0;
    begin
        -- Check that the GPU card still answers, if not return 0
        -- Get power consumption
        if Card = System.Null_Address or else NVML_Device_Power (Card, Milliwatts'Access) /= NVML_SUCCESS
        then
            return 0.0;
        end if;

        -- NVML reports power in milliwatts, so convert it to watts
        return Long_Float (Milliwatts) / 1_000.0;
    exception
        when others =>
            return 0.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
        Ignored : int;
    begin
        -- Stops NVML
        if NVML_Shutdown /= null then
            Ignored := NVML_Shutdown.all;
            NVML_Shutdown := null;
        end if;

        -- Reset the variables and functions and forget the card
        Card := System.Null_Address;
        NVML_Device_Power := null;

        -- Unload the library
        if NVML_Library /= System.Null_Address then
            Unload (NVML_Library);
            NVML_Library := System.Null_Address;
        end if;
    exception
        when others =>
            NVML_Shutdown := null;
            NVML_Library := System.Null_Address;
    end Close;

#else

    -- On unsupported systems, return False and zeros

    function Is_Accessible return Boolean is
    begin
        return False;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Power return Long_Float is
    begin
        return 0.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

#end if;

end Joular_Core.GPU_Nvidia_NVML;
