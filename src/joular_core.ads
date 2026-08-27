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
-- The library is not task safe: call Open, Read and Close from a single task/thread
package Joular_Core is

    -- The type for the hardware sources to measure
    -- Currently we support CPUs (Intel, AMD, Raspberry Pi) and GPUs (Nvidia, AMD)
    -- Joular Core detects the proper CPU or GPU model in the device
    type Source is (CPU, GPU);

    -- List of hardware sources to measure
    -- Only the ones set to True will be measured
    type Source_List is array (Source) of Boolean;

    -- A constant that sets all hardware sources to True
    -- Useful to simplify using Source_List
    All_Sources : constant Source_List := (others => True);

    --  The unit of the measurement
    type Measurement_Unit is (Energy, Power);

    -- The type for a measurement
    -- Available : if hardware source has been requested and can be read, otherwise False
    -- Value : energy or power value
    -- Example: CPU using RAPL will give Energy, while Raspberry Pi models will give Power
    type Measurement is
       record
           Available : Boolean := False;
           Value : Long_Float := 0.0;
           Unit : Measurement_Unit := Energy;
       end record;

    -- The type for the list of measurements for each hardware source
    type Reading is array (Source) of Measurement;

    -- Check the list of hardware sources if available and can be read
    -- Open any needed files or drivers
    procedure Open (Sources : in Source_List := All_Sources);

    -- Close opened files or drivers that were already opened in Open procedure or during reading
    procedure Close;

    -- Take one reading for each of the hardware sources set to True in Sources
    -- Returns a Reading type: a list of measurement (value, unit) for each hardware source
    -- A source that fails to answer reports a value of zero (with Available still True)
    -- Energy counters (i.e., RAPL) wrap after a few minutes under load, so read at least once per minute to not miss a wrap
    function Read (Sources : in Source_List := All_Sources) return Reading;

    -- Return True if Open procedure was already called and not closed
    function Is_Open return Boolean;

    -- Return the version of the library as a String
    function Version return String;

end Joular_Core;
