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

with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Joular_Core.CPU_Load;
with Joular_Core.File_Utils;

package body Joular_Core.RPI is

    -- File that holds the board model name on Linux
    Device_Tree_File : constant String := "/proc/device-tree/model";

    -- Check if we're on a 32 or 64 bits systems. Calculated on compile time
    Is_64_Bits : constant Boolean := Standard'Address_Size = 64;

    -- Supported SBC board models with a power model available
    type Model_Name is
       (None, -- Not an SBC board with a power model
        RPI_5B_64,
        RPI_400_64,
        RPI_4B_1_1,
        RPI_4B_1_1_64,
        RPI_4B_1_2,
        RPI_4B_1_2_64,
        RPI_3B_Plus,
        RPI_3B,
        RPI_2B,
        RPI_1B_Plus,
        RPI_1B,
        RPI_Zero_W,
        Tinker_Board);

    subtype Board_Model is Model_Name range Model_Name'Succ (None) .. Model_Name'Last;

    -- Model of the board used, None if none detected
    Current_Model : Model_Name := None;

    -- The coefficients of x^0 to x^9
    type Power_Model is array (0 .. 9) of Long_Float;

    -- Regression power models for supported boards
    -- One model per board. Boards with models fitted at a lower degree than 9, have their remaining coefficient at 0
    Models : constant array (Board_Model) of Power_Model :=

        (RPI_5B_64 => (3.482347585466841,
                       4.79754735,
                       -194.6728884,
                       2943.39811783,
                       -18701.88486195,
                       62067.07334862,
                       -115731.34642828,
                       122197.10885563,
                       -68266.30180963,
                       15687.86508083),

         RPI_400_64 => (2.6630056198236938,
                        0.82814554,
                        -112.17687631,
                        1753.99173239,
                        -10992.65341181,
                        35988.45610911,
                        -66254.20051068,
                        69071.21138567,
                        -38089.87171735,
                        8638.45610698),

         RPI_4B_1_1 => (2.5718068562852086,
                        2.794871,
                        -58.954883,
                        838.875781,
                        -5371.428686,
                        18168.842874,
                        -34369.583554,
                        36585.681749,
                        -20501.307640,
                        4708.331490),

         RPI_4B_1_1_64 => (3.405685008777926,
                           -11.834416,
                           137.312822,
                           -775.891511,
                           2563.399671,
                           -4783.024354,
                           4974.960753,
                           -2691.923074,
                           590.355251,
                           0.0),

         RPI_4B_1_2 => (2.58542069543335,
                        12.335449,
                        -248.010554,
                        2379.832320,
                        -11962.419149,
                        34444.268647,
                        -58455.266502,
                        57698.685016,
                        -30618.557703,
                        6752.265368),

         RPI_4B_1_2_64 => (3.039940056604439,
                           -3.074225,
                           47.753114,
                           -271.974551,
                           879.966571,
                           -1437.466442,
                           1133.325791,
                           -345.134888,
                           0.0,
                           0.0),

         RPI_3B_Plus => (2.484396997449118,
                         2.933542,
                         -150.400134,
                         2278.690310,
                         -15008.559279,
                         51537.315529,
                         -98756.887779,
                         106478.929766,
                         -60432.910139,
                         14053.677709),

         RPI_3B => (1.524116907651687,
                    10.053851,
                    -234.186930,
                    2516.322119,
                    -13733.555536,
                    41739.918887,
                    -73342.794259,
                    74062.644914,
                    -39909.425362,
                    8894.110508),

         RPI_2B => (1.3596870187778196,
                    5.135090,
                    -103.296366,
                    1027.169748,
                    -5323.639404,
                    15592.036875,
                    -26675.601585,
                    26412.963366,
                    -14023.471809,
                    3089.786200),

         RPI_1B_Plus => (1.2513999338064061,
                         1.857815,
                         -18.109537,
                         101.531231,
                         -346.386617,
                         749.560352,
                         -1028.802514,
                         863.877618,
                         -403.270951,
                         79.925932),

         RPI_1B => (2.826093843916506,
                    3.539891,
                    -43.586963,
                    282.488560,
                    -1074.116844,
                    2537.679443,
                    -3761.784242,
                    3391.045904,
                    -1692.840870,
                    357.800968),

         RPI_Zero_W => (0.8551610676717238,
                        7.207151,
                        -135.517893,
                        1254.808001,
                        -6329.450524,
                        18502.371291,
                        -32098.028941,
                        32554.679890,
                        -17824.350159,
                        4069.178175),

         Tinker_Board => (3.9146162374630173,
                          -19.85430796,
                          141.7306532,
                          -298.12713091,
                          -1115.76983141,
                          8238.27573132,
                          -20976.13898406,
                          27132.90930519,
                          -17741.01303757,
                          4640.69530931));

    --------------------------------------------------

    -- Get the board's model from its read name from device tree file
    -- Uses the model for the specific revision. If no model of revision exists, but a model exists for the same board on a different revision, use this one instead
    function Model_Of (Info : in String) return Model_Name is
    begin
        -- Revision 1.1 of the 4B was measured on its own, every other revision of that board uses the model measured on the 1.2
        if Index (Info, "Raspberry Pi 4 Model B Rev 1.1") > 0 then
            return (if Is_64_Bits then RPI_4B_1_1_64 else RPI_4B_1_1);
        end if;

        if Index (Info, "Raspberry Pi 4 Model B") > 0 then
            return (if Is_64_Bits then RPI_4B_1_2_64 else RPI_4B_1_2);
        end if;

        -- The 5B and the 400 were only measured on a 64 bits device, so a 32 bits ones are not supported
        if Index (Info, "Raspberry Pi 5 Model B") > 0 then
            return (if Is_64_Bits then RPI_5B_64 else None);
        end if;

        if Index (Info, "Raspberry Pi 400") > 0 then
            return (if Is_64_Bits then RPI_400_64 else None);
        end if;

        if Index (Info, "Raspberry Pi 3 Model B Plus") > 0 then
            return RPI_3B_Plus;
        end if;

        if Index (Info, "Raspberry Pi 3 Model B") > 0 then
            return RPI_3B;
        end if;

        if Index (Info, "Raspberry Pi 2 Model B") > 0 then
            return RPI_2B;
        end if;

        if Index (Info, "Raspberry Pi Model B Plus") > 0 then
            return RPI_1B_Plus;
        end if;

        if Index (Info, "Raspberry Pi Model B") > 0 then
            return RPI_1B;
        end if;

        if Index (Info, "Raspberry Pi Zero W") > 0 then
            return RPI_Zero_W;
        end if;

        -- Not Raspberry Pi, but we have regression models for Asus Tinker Board
        if Index (Info, "ASUS Tinker Board") > 0 then
            return Tinker_Board;
        end if;

        return None;
    end Model_Of;

    --------------------------------------------------

    -- Read and detect the board's model name from device tree file
    -- An unreadable or missing file gives an empty name, which no model matches
    function Detect_Model return Model_Name is
    begin
        return Model_Of (File_Utils.Read_First_Line (Device_Tree_File));
    end Detect_Model;

    --------------------------------------------------

    function Is_Accessible return Boolean is
    begin
        Current_Model := Detect_Model;

        if Current_Model = None then
            return False;
        end if;

        -- Take a first CPU load reading, so we can calculate CPU usage on next reading
        CPU_Load.Start;

        return True;
    end Is_Accessible;

    --------------------------------------------------

    function Get_Power return Long_Float is
        Usage : Long_Float;
        Power : Long_Float := 0.0;
    begin
        if Current_Model = None then
            return 0.0;
        end if;

        -- Calculate CPU usage
        Usage := Long_Float'Max (0.0, Long_Float'Min (1.0, CPU_Load.Usage));

        -- Calculate the power consumption, by using the formula and calculating every degree in the polynomial model
        for Degree in Power_Model'Range loop
            Power := Power + (Models (Current_Model) (Degree) * (Usage ** Degree));
        end loop;

        -- A regression model might dip below zero near the end of its range, so normalize to 0 in this case
        return Long_Float'Max (0.0, Power);
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        -- Reset current model to None
        Current_Model := None;
    end Close;

end Joular_Core.RPI;
