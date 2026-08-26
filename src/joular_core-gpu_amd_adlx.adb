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

#if PJ_WINDOWS then
with Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Unchecked_Conversion;
with System; use System;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;
#end if;

package body Joular_Core.GPU_AMD_ADLX is

#if PJ_WINDOWS then

    -- ADLX_RESULT is a C enumeration, and ADLX_OK is its first value
    subtype ADLX_RESULT is int;
    ADLX_OK : constant ADLX_RESULT := 0;

    -- Library DLL name
    Library_Name : constant String := (if Standard'Address_Size = 64 then "amdadlx64.dll" else "amdadlx32.dll");

    -- Functions the ADLX library exports
    type Query_Full_Version_Function is access function (Version : access Interfaces.Unsigned_64) return ADLX_RESULT;
    pragma Convention (C, Query_Full_Version_Function);

    type Initialize_Function is access function (Version : Interfaces.Unsigned_64; ADLX_System : access System.Address) return ADLX_RESULT;
    pragma Convention (C, Initialize_Function);

    type Terminate_Function is access function return ADLX_RESULT;
    pragma Convention (C, Terminate_Function);

    -- Drops a reference on an object, and is the second slot of every interface but IADLXSystem
    type Release_Method is access function (This : System.Address) return long;
    pragma Convention (Stdcall, Release_Method);

    -- Returns an object, and covers GetGPUs and GetPerformanceMonitoringServices
    type Get_Object_Method is access function (This : System.Address; Item : access System.Address) return ADLX_RESULT;
    pragma Convention (Stdcall, Get_Object_Method);

    -- Returns the index the list starts at, which is Begin of a list
    type Index_Method is access function (This : System.Address) return unsigned;
    pragma Convention (Stdcall, Index_Method);

    -- Returns the card at one place of the list
    type At_GPUList_Method is access function (This : System.Address; Location : unsigned; Item : access System.Address) return ADLX_RESULT;
    pragma Convention (Stdcall, At_GPUList_Method);

    -- Returns a sample of the measures of one card
    type Get_GPU_Metrics_Method is access function (This : System.Address; GPU : System.Address; Metrics : access System.Address) return ADLX_RESULT;
    pragma Convention (Stdcall, Get_GPU_Metrics_Method);

    -- Returns one measure out of a sample
    type Metric_Method is access function (This : System.Address; Data : access double) return ADLX_RESULT;
    pragma Convention (Stdcall, Metric_Method);

    --------------------------------------------------

    -- The method tables, in the order of the SDK headers
    -- Every interface, with the exception of IADLXSystem, begins with Acquire then Release, so this table is enough to give back an object of any of them

    type Object_Vtbl is
       record
           Acquire : System.Address;
           Release : Release_Method;
       end record;
    pragma Convention (C, Object_Vtbl);

    -- ISystem.h, IADLXSystemVtbl
    type System_Vtbl is
       record
           GetHybridGraphicsType : System.Address;
           GetGPUs : Get_Object_Method;
           QueryInterface : System.Address;
           GetDisplaysServices : System.Address;
           GetDesktopsServices : System.Address;
           GetGPUsChangedHandling : System.Address;
           EnableLog : System.Address;
           Get3DSettingsServices : System.Address;
           GetGPUTuningServices : System.Address;
           GetPerformanceMonitoringServices : Get_Object_Method;
           TotalSystemRAM : System.Address;
           GetI2C : System.Address;
       end record;
    pragma Convention (C, System_Vtbl);

    -- ISystem.h, IADLXGPUListVtbl
    type GPU_List_Vtbl is
       record
           Acquire : System.Address;
           Release : Release_Method;
           QueryInterface : System.Address;
           Size : System.Address;
           Empty : System.Address;
           List_Begin : Index_Method; -- Begin in the header, which is a reserved word here
           List_End : System.Address;
           At_Item : System.Address;
           Clear : System.Address;
           Remove_Back : System.Address;
           Add_Back : System.Address;
           At_GPUList : At_GPUList_Method;
           Add_Back_GPUList : System.Address;
       end record;
    pragma Convention (C, GPU_List_Vtbl);

    -- IPerformanceMonitoring.h, IADLXPerformanceMonitoringServicesVtbl
    type Perf_Services_Vtbl is
       record
           Acquire : System.Address;
           Release : Release_Method;
           QueryInterface : System.Address;
           GetSamplingIntervalRange : System.Address;
           SetSamplingInterval : System.Address;
           GetSamplingInterval : System.Address;
           GetMaxPerformanceMetricsHistorySizeRange : System.Address;
           SetMaxPerformanceMetricsHistorySize : System.Address;
           GetMaxPerformanceMetricsHistorySize : System.Address;
           ClearPerformanceMetricsHistory : System.Address;
           GetCurrentPerformanceMetricsHistorySize : System.Address;
           StartPerformanceMetricsTracking : System.Address;
           StopPerformanceMetricsTracking : System.Address;
           GetAllMetricsHistory : System.Address;
           GetGPUMetricsHistory : System.Address;
           GetSystemMetricsHistory : System.Address;
           GetFPSHistory : System.Address;
           GetCurrentAllMetrics : System.Address;
           GetCurrentGPUMetrics : Get_GPU_Metrics_Method;
           GetCurrentSystemMetrics : System.Address;
           GetCurrentFPS : System.Address;
           GetSupportedGPUMetrics : System.Address;
           GetSupportedSystemMetrics : System.Address;
       end record;
    pragma Convention (C, Perf_Services_Vtbl);

    -- IPerformanceMonitoring.h, IADLXGPUMetricsVtbl
    type GPU_Metrics_Vtbl is
       record
           Acquire : System.Address;
           Release : Release_Method;
           QueryInterface : System.Address;
           TimeStamp : System.Address;
           GPUUsage : System.Address;
           GPUClockSpeed : System.Address;
           GPUVRAMClockSpeed : System.Address;
           GPUTemperature : System.Address;
           GPUHotspotTemperature : System.Address;
           GPUPower : Metric_Method;
           GPUTotalBoardPower : Metric_Method;
           GPUFanSpeed : System.Address;
           GPUVRAM : System.Address;
           GPUVoltage : System.Address;
           GPUIntakeTemperature : System.Address;
       end record;
    pragma Convention (C, GPU_Metrics_Vtbl);

    --------------------------------------------------

    -- Reaching the method table of an object, which is an address to convert to the table

    type Address_Access is access all System.Address;
    type Object_Vtbl_Access is access all Object_Vtbl;
    type System_Vtbl_Access is access all System_Vtbl;
    type GPU_List_Vtbl_Access is access all GPU_List_Vtbl;
    type Perf_Services_Vtbl_Access is access all Perf_Services_Vtbl;
    type GPU_Metrics_Vtbl_Access is access all GPU_Metrics_Vtbl;

    function To_Address_Access is new Ada.Unchecked_Conversion (System.Address, Address_Access);
    function To_Object_Vtbl is new Ada.Unchecked_Conversion (System.Address, Object_Vtbl_Access);
    function To_System_Vtbl is new Ada.Unchecked_Conversion (System.Address, System_Vtbl_Access);
    function To_GPU_List_Vtbl is new Ada.Unchecked_Conversion (System.Address, GPU_List_Vtbl_Access);
    function To_Perf_Services_Vtbl is new Ada.Unchecked_Conversion (System.Address, Perf_Services_Vtbl_Access);
    function To_GPU_Metrics_Vtbl is new Ada.Unchecked_Conversion (System.Address, GPU_Metrics_Vtbl_Access);

    function To_Query_Full_Version is new Ada.Unchecked_Conversion (System.Address, Query_Full_Version_Function);
    function To_Initialize is new Ada.Unchecked_Conversion (System.Address, Initialize_Function);
    function To_Terminate is new Ada.Unchecked_Conversion (System.Address, Terminate_Function);

    --------------------------------------------------

    -- The loaded library
    ADLX_Library : System.Address := System.Null_Address;

    -- The function stopping ADLX
    ADLX_Terminate : Terminate_Function := null;

    -- The objects ADLX answered with
    Perf_Services : aliased System.Address := System.Null_Address;
    GPU_List : aliased System.Address := System.Null_Address;

    -- The card being read
    Card : aliased System.Address := System.Null_Address;

    --------------------------------------------------

    -- Get the method table of an object
    -- The first field of an object is the pointer to its table, so the table is the machine word the object points at
    function Vtbl_Of (Object : in System.Address) return System.Address is
    begin
        if Object = System.Null_Address then
            return System.Null_Address;
        end if;

        return To_Address_Access (Object).all;
    end Vtbl_Of;

    --------------------------------------------------

    -- Drop the reference held on an ADLX object, and forget it
    -- An object answering with no method table is forgotten rather than called into
    procedure Release_Object (Object : in out System.Address) is
        Table : Object_Vtbl_Access;
        Ignored : long;
    begin
        Table := To_Object_Vtbl (Vtbl_Of (Object));

        if Table /= null and then Table.Release /= null then
            Ignored := Table.Release (Object);
        end if;

        Object := System.Null_Address;
    exception
        when others =>
            Object := System.Null_Address;
    end Release_Object;

    --------------------------------------------------

    -- Read the power of the card, in watts
    -- Returns False when the card doesn't report a power value
    function Read_Card_Power (Power : out Long_Float) return Boolean is
        Metrics : aliased System.Address := System.Null_Address;
        Value : aliased double := 0.0;
        Services : Perf_Services_Vtbl_Access;
        Table : GPU_Metrics_Vtbl_Access;
        Found : Boolean := False;
    begin
        Power := 0.0;

        Services := To_Perf_Services_Vtbl (Vtbl_Of (Perf_Services));

        if Services = null or else Services.GetCurrentGPUMetrics = null then
            return False;
        end if;

        -- Take one sample of the measures of the card
        if Services.GetCurrentGPUMetrics (Perf_Services, Card, Metrics'Access) /= ADLX_OK then
            return False;
        end if;

        Table := To_GPU_Metrics_Vtbl (Vtbl_Of (Metrics));

        if Table /= null then
            -- The whole board is asked for first, as that is what the card really draws (and similar to what NVML reports for Nvidia cards)
            -- The power of the processor of the card alone is the fallback for a card not offering the first
            -- ADLX already reports power in watts
            if Table.GPUTotalBoardPower /= null
               and then Table.GPUTotalBoardPower (Metrics, Value'Access) = ADLX_OK
            then
                Power := Long_Float (Value);
                Found := True;
            elsif Table.GPUPower /= null
               and then Table.GPUPower (Metrics, Value'Access) = ADLX_OK
            then
                Power := Long_Float (Value);
                Found := True;
            end if;

            -- The object is ours, so it has to be given back on every reading
            -- Otherwise ADLX is left holding one per reading and refuses to stop cleanly
            Release_Object (Metrics);
        end if;

        return Found;
    exception
        when others =>
            Power := 0.0;
            return False;
    end Read_Card_Power;

    --------------------------------------------------

    function Is_Accessible return Boolean is
        Query_Version : Query_Full_Version_Function;
        Start_ADLX : Initialize_Function;
        Stop_ADLX : Terminate_Function;
        Version : aliased Interfaces.Unsigned_64 := 0;
        ADLX_System : aliased System.Address := System.Null_Address;
        System_Table : System_Vtbl_Access;
        List_Table : GPU_List_Vtbl_Access;
        Power : Long_Float;
    begin
        -- Start from nothing, so that detecting twice doesn't load the library a second time
        Close;

        -- First, load the library, which is only there if the AMD driver is installed
        ADLX_Library := Load (Library_Name);

        if ADLX_Library = System.Null_Address then
            return False;
        end if;

        -- Then, find the functions needed in it
        Query_Version := To_Query_Full_Version (Find_Symbol (ADLX_Library, "ADLXQueryFullVersion"));
        Start_ADLX := To_Initialize (Find_Symbol (ADLX_Library, "ADLXInitialize"));
        Stop_ADLX := To_Terminate (Find_Symbol (ADLX_Library, "ADLXTerminate"));

        -- Every function has to be found, otherwise the driver is too old to be used here, so we return False
        if Query_Version = null or else Start_ADLX = null or else Stop_ADLX = null then
            Close;
            return False;
        end if;

        -- Then, start ADLX with the version the library itself reports, so it works with the driver installed
        if Query_Version (Version'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        if Start_ADLX (Version, ADLX_System'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        -- ADLX is started from here on, and keeping the function that stops it
        ADLX_Terminate := Stop_ADLX;

        -- Then, ask ADLX for the measures service and for the list of the cards
        System_Table := To_System_Vtbl (Vtbl_Of (ADLX_System));

        if System_Table = null
           or else System_Table.GetPerformanceMonitoringServices = null
           or else System_Table.GetGPUs = null
        then
            Close;
            return False;
        end if;

        if System_Table.GetPerformanceMonitoringServices (ADLX_System, Perf_Services'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        if System_Table.GetGPUs (ADLX_System, GPU_List'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        List_Table := To_GPU_List_Vtbl (Vtbl_Of (GPU_List));

        if List_Table = null
           or else List_Table.At_GPUList = null
           or else List_Table.List_Begin = null
        then
            Close;
            return False;
        end if;

        -- Then, get the main card, which is the first one of the list
        if List_Table.At_GPUList (GPU_List, List_Table.List_Begin (GPU_List), Card'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        -- Then, take a first reading
        -- If reading fails, then we can't use this card
        if not Read_Card_Power (Power) then
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
        Power : Long_Float;
    begin
        -- If card stops answering, then return 0
        if not Read_Card_Power (Power) then
            return 0.0;
        end if;

        return Power;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
        Ignored : ADLX_RESULT;
    begin
        -- Release the card and the ADLX objects
        Release_Object (Card);
        Release_Object (GPU_List);
        Release_Object (Perf_Services);

        -- Stop ADLX
        if ADLX_Terminate /= null then
            Ignored := ADLX_Terminate.all;
            ADLX_Terminate := null;
        end if;

        -- Unload the ADLX library
        if ADLX_Library /= System.Null_Address then
            Unload (ADLX_Library);
            ADLX_Library := System.Null_Address;
        end if;
    exception
        when others =>
            ADLX_Terminate := null;
            ADLX_Library := System.Null_Address;
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

end Joular_Core.GPU_AMD_ADLX;
