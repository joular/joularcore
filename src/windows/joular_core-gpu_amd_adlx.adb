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

with Interfaces;
with Interfaces.C; use Interfaces.C;
with Ada.Unchecked_Conversion;
with System; use System;

with Joular_Core.Dynamic_Library; use Joular_Core.Dynamic_Library;

package body Joular_Core.GPU_AMD_ADLX is

    -- ADLX_RESULT is a C enumeration, and ADLX_OK is its first value
    subtype ADLX_RESULT is int;
    ADLX_OK : constant ADLX_RESULT := 0;

    Library_Name : constant String := (if Standard'Address_Size = 64 then "amdadlx64.dll" else "amdadlx32.dll");

    -- Functions the ADLX library exports
    type Query_Full_Version_Function is access function (Version : access Interfaces.Unsigned_64) return ADLX_RESULT;
    pragma Convention (C, Query_Full_Version_Function);

    type Initialize_Function is access function (Version : Interfaces.Unsigned_64; ADLX_System : access System.Address) return ADLX_RESULT;
    pragma Convention (C, Initialize_Function);

    type Terminate_Function is access function return ADLX_RESULT;
    pragma Convention (C, Terminate_Function);

    -- Drops a reference on an object
    type Release_Method is access function (This : System.Address) return long;
    pragma Convention (Stdcall, Release_Method);

    -- Returns an object, and covers GetGPUs and GetPerformanceMonitoringServices
    type Get_Object_Method is access function (This : System.Address; Item : access System.Address) return ADLX_RESULT;
    pragma Convention (Stdcall, Get_Object_Method);

    -- Begin of a list
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
    -- Every interface but IADLXSystem starts with Acquire then Release, so this table releases any of them

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
           List_Begin : Index_Method; -- Begin in the header, a reserved word here
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

    ADLX_Library : System.Address := System.Null_Address;

    ADLX_Terminate : Terminate_Function := null;

    Perf_Services : aliased System.Address := System.Null_Address;
    GPU_List : aliased System.Address := System.Null_Address;

    Card : aliased System.Address := System.Null_Address;

    -- Board is what the card really draws (what NVML reports for Nvidia); Chip alone is a smaller quantity, the fallback
    type Metric_Kind is (None, Board, Chip);

    -- Settled once in Open
    Metric : Metric_Kind := None;

    --------------------------------------------------

    -- The first word of an object points at its method table
    function Vtbl_Of (Object : in System.Address) return System.Address is
    begin
        if Object = System.Null_Address then
            return System.Null_Address;
        end if;

        return To_Address_Access (Object).all;
    end Vtbl_Of;

    --------------------------------------------------

    -- Drop the reference held on an ADLX object, and forget it
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

    -- Read one power out of a fresh sample of the card; False when the card does not offer it or would not answer
    function Sample_Power (Kind : in Metric_Kind; Power : out Long_Float) return Boolean is
        Services : constant Perf_Services_Vtbl_Access := To_Perf_Services_Vtbl (Vtbl_Of (Perf_Services));
        Metrics : aliased System.Address := System.Null_Address;
        Table : GPU_Metrics_Vtbl_Access;
        Method : Metric_Method;
        Value : aliased double := 0.0;
        Found : Boolean := False;
    begin
        Power := 0.0;

        if Services = null or else Services.GetCurrentGPUMetrics = null then
            return False;
        end if;

        -- Own block, so the sample is always released below
        begin
            if Services.GetCurrentGPUMetrics (Perf_Services, Card, Metrics'Access) = ADLX_OK then
                Table := To_GPU_Metrics_Vtbl (Vtbl_Of (Metrics));

                if Table /= null then
                    Method := (case Kind is
                                  when Board => Table.GPUTotalBoardPower,
                                  when Chip => Table.GPUPower,
                                  when None => null);

                    Found := Method /= null and then Method (Metrics, Value'Access) = ADLX_OK;
                end if;
            end if;
        exception
            when others =>
                Found := False;
        end;

        -- Unreleased samples pile up in ADLX and block ADLXTerminate
        Release_Object (Metrics);

        -- ADLX already reports power in watts
        if Found then
            Power := Long_Float (Value);
        end if;

        return Found;
    end Sample_Power;

    --------------------------------------------------

    function Open return Boolean is
        Query_Version : Query_Full_Version_Function;
        Start_ADLX : Initialize_Function;
        Stop_ADLX : Terminate_Function;
        Version : aliased Interfaces.Unsigned_64 := 0;
        ADLX_System : aliased System.Address := System.Null_Address;
        System_Table : System_Vtbl_Access;
        List_Table : GPU_List_Vtbl_Access;
        Power : Long_Float;
    begin
        -- So opening twice doesn't load the library twice
        Close;

        -- Only there if the AMD driver is installed
        ADLX_Library := Load (Library_Name);

        if ADLX_Library = System.Null_Address then
            return False;
        end if;

        Query_Version := To_Query_Full_Version (Find_Symbol (ADLX_Library, "ADLXQueryFullVersion"));
        Start_ADLX := To_Initialize (Find_Symbol (ADLX_Library, "ADLXInitialize"));
        Stop_ADLX := To_Terminate (Find_Symbol (ADLX_Library, "ADLXTerminate"));

        -- A missing one means a driver too old
        if Query_Version = null or else Start_ADLX = null or else Stop_ADLX = null then
            Close;
            return False;
        end if;

        -- Start with the version the library reports, so it matches the driver installed
        if Query_Version (Version'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        if Start_ADLX (Version, ADLX_System'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        -- Started from here on, so Close must stop it
        ADLX_Terminate := Stop_ADLX;

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

        -- The first card of the list is the one read
        if List_Table.At_GPUList (GPU_List, List_Table.List_Begin (GPU_List), Card'Access) /= ADLX_OK then
            Close;
            return False;
        end if;

        -- The first reading settles the metric: board, else chip, else the card is unusable
        if Sample_Power (Board, Power) then
            Metric := Board;
        elsif Sample_Power (Chip, Power) then
            Metric := Chip;
        else
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
        Power : Long_Float;
    begin
        if Metric = None or else not Sample_Power (Metric, Power) then
            return 0.0;
        end if;

        return Power;
    end Get_Power;

    --------------------------------------------------

    procedure Close is
        Ignored : ADLX_RESULT;
    begin
        Metric := None;

        Release_Object (Card);
        Release_Object (GPU_List);
        Release_Object (Perf_Services);

        if ADLX_Terminate /= null then
            begin
                Ignored := ADLX_Terminate.all;
            exception
                when others =>
                    null;
            end;

            ADLX_Terminate := null;
        end if;

        if ADLX_Library /= System.Null_Address then
            Unload (ADLX_Library);
            ADLX_Library := System.Null_Address;
        end if;
    end Close;

end Joular_Core.GPU_AMD_ADLX;
