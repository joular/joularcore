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
with Ada.Unchecked_Conversion;
with System; use System;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;

package body Joular_Core.GPU_Nvidia_NVML is

    -- NVML returns zero when a call succeeded
    NVML_SUCCESS : constant int := 0;

    -- The NVML functions used
    type Init_Function is access function return int;
    pragma Convention (C, Init_Function);

    type Shutdown_Function is access function return int;
    pragma Convention (C, Shutdown_Function);

    type Count_Function is access function (Count : access unsigned) return int;
    pragma Convention (C, Count_Function);

    type Handle_Function is access function (Index : unsigned; Device : access System.Address) return int;
    pragma Convention (C, Handle_Function);

    type Power_Function is access function (Device : System.Address; Milliwatts : access unsigned) return int;
    pragma Convention (C, Power_Function);

    -- Find_Symbol gives an address, so convert it to the function it points to
    function To_Init is new Ada.Unchecked_Conversion (System.Address, Init_Function);
    function To_Shutdown is new Ada.Unchecked_Conversion (System.Address, Shutdown_Function);
    function To_Count is new Ada.Unchecked_Conversion (System.Address, Count_Function);
    function To_Handle is new Ada.Unchecked_Conversion (System.Address, Handle_Function);
    function To_Power is new Ada.Unchecked_Conversion (System.Address, Power_Function);

    --------------------------------------------------

    NVML_Library : System.Address := System.Null_Address;

    -- Set once NVML is started, so Close knows whether to stop it
    NVML_Shutdown : Shutdown_Function := null;

    NVML_Device_Power : Power_Function := null;

    -- The cards that report power
    Max_Cards : constant := 16;

    Cards : array (1 .. Max_Cards) of System.Address := (others => System.Null_Address);
    Count : Natural := 0;

    --------------------------------------------------

    -- The library name and location depend on the OS, so the body is in src/posix and src/windows
    -- Returns the null address when the Nvidia driver is not installed
    function Load_Library return System.Address is separate;

    --------------------------------------------------

    function Open return Boolean is
        Start_NVML : Init_Function;
        Stop_NVML : Shutdown_Function;
        Get_Count : Count_Function;
        Get_Handle : Handle_Function;
        Found : aliased unsigned := 0;
        Card : aliased System.Address := System.Null_Address;
        Milliwatts : aliased unsigned := 0;
    begin
        -- Open may be called twice: close first so the library isn't loaded twice
        Close;

        NVML_Library := Load_Library;

        if NVML_Library = System.Null_Address then
            return False;
        end if;

        Start_NVML := To_Init (Find_Symbol (NVML_Library, "nvmlInit_v2"));
        Stop_NVML := To_Shutdown (Find_Symbol (NVML_Library, "nvmlShutdown"));
        Get_Count := To_Count (Find_Symbol (NVML_Library, "nvmlDeviceGetCount_v2"));
        Get_Handle := To_Handle (Find_Symbol (NVML_Library, "nvmlDeviceGetHandleByIndex_v2"));
        NVML_Device_Power := To_Power (Find_Symbol (NVML_Library, "nvmlDeviceGetPowerUsage"));

        if Start_NVML = null or else Stop_NVML = null or else Get_Count = null or else Get_Handle = null
           or else NVML_Device_Power = null
        then
            Close;
            return False;
        end if;

        if Start_NVML.all /= NVML_SUCCESS then
            Close;
            return False;
        end if;

        -- NVML started, so keep the function closing it
        NVML_Shutdown := Stop_NVML;

        -- Every card that reports power
        if Get_Count (Found'Access) = NVML_SUCCESS then
            for Index in 0 .. Natural'Min (Natural (Found), Max_Cards) - 1 loop
                if Get_Handle (unsigned (Index), Card'Access) = NVML_SUCCESS
                   and then NVML_Device_Power (Card, Milliwatts'Access) = NVML_SUCCESS
                then
                    Count := Count + 1;
                    Cards (Count) := Card;
                end if;
            end loop;
        end if;

        if Count = 0 then
            Close;
            return False;
        end if;

        return True;
    exception
        when others =>
            Close;
            return False;
    end Open;

    --------------------------------------------------

    function Get_Power return Long_Float is
        Milliwatts : aliased unsigned := 0;
        Watts : Long_Float := 0.0;
    begin
        -- A card that would not answer counts zero
        for Card of Cards (1 .. Count) loop
            if NVML_Device_Power (Card, Milliwatts'Access) = NVML_SUCCESS then
                Watts := Watts + Long_Float (Milliwatts) / 1_000.0;
            end if;
        end loop;

        return Watts;
    exception
        when others =>
            return 0.0;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
        Ignored : int;
    begin
        -- A crash of the driver while stopping must not prevent the library from being unloaded below
        if NVML_Shutdown /= null then
            begin
                Ignored := NVML_Shutdown.all;
            exception
                when others =>
                    null;
            end;

            NVML_Shutdown := null;
        end if;

        Cards := (others => System.Null_Address);
        Count := 0;
        NVML_Device_Power := null;

        if NVML_Library /= System.Null_Address then
            Unload (NVML_Library);
            NVML_Library := System.Null_Address;
        end if;
    end Close;

end Joular_Core.GPU_Nvidia_NVML;
