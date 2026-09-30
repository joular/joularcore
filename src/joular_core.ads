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

-- Joular Core measures the energy or power consumption of hardware components
-- The library is not task safe: call Open, Read and Close from a single task
package Joular_Core is

    -- The hardware sources to measure
    -- CPUs: Intel and AMD (RAPL), Apple Silicon and Mac Intel (powermetrics), Raspberry Pi and other boards
    -- GPUs: Nvidia, AMD, Apple Silicon
    -- Joular Core detects automatically the available sources and how to read them
    type Source is (CPU, GPU);

    -- Which sources to measure: only the ones set to True
    type Source_List is array (Source) of Boolean;

    All_Sources : constant Source_List := (others => True);

    -- Energy: joules consumed since the previous Read (the first Read counts from Open)
    -- Power: watts being drawn at the time of the Read
    type Measurement_Unit is (Energy, Power);

    -- Available : the source was requested and can be read
    -- Value : joules or watts, depending on Unit
    -- E.g. a CPU read through RAPL gives Energy, a Raspberry Pi gives Power
    type Measurement is
       record
           Available : Boolean := False;
           Value : Long_Float := 0.0;
           Unit : Measurement_Unit := Energy;
       end record;

    -- One measurement per hardware source
    type Reading is array (Source) of Measurement;

    -- Detect the hardware sources asked for, and open the files, drivers or processes needed to read them
    -- A source that is not there, or cannot be read, is reported as not available by Read
    procedure Open (Sources : in Source_List := All_Sources);

    -- Close what Open opened
    procedure Close;

    -- Take one reading of every source Open could open
    -- A source that fails to answer reports a value of zero, with Available still True
    -- Energy counters (e.g. RAPL) wrap after a few minutes under load, so read at least once per minute to not miss a wrap
    -- For Windows using EMI, the wrap is handled by EMI directly
    function Read return Reading;

    -- Return the version of the library as a String
    function Version return String;

end Joular_Core;
