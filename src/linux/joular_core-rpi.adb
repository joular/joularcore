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

    Device_Tree_File : constant String := "/proc/device-tree/model";

    -- Some boards have separate models for 32 and 64 bits systems
    Is_64_Bits : constant Boolean := Standard'Address_Size = 64;

    type Model_Name is
       (None,
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

    Current_Model : Model_Name := None;

    -- Coefficients of x^0 to x^9, x being the CPU usage
    type Power_Model is array (0 .. 9) of Long_Float;

    -- Models fitted at a lower degree have their remaining coefficients at 0
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

    -- Model of the board named in the device tree, None when it has no power model
    function Model_Of (Info : in String) return Model_Name is
    begin
        -- Only rev 1.1 of the 4B was measured on its own, other revisions use the 1.2 model
        if Index (Info, "Raspberry Pi 4 Model B Rev 1.1") > 0 then
            return (if Is_64_Bits then RPI_4B_1_1_64 else RPI_4B_1_1);
        end if;

        if Index (Info, "Raspberry Pi 4 Model B") > 0 then
            return (if Is_64_Bits then RPI_4B_1_2_64 else RPI_4B_1_2);
        end if;

        -- The 5B and the 400 were only measured on 64 bits
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

        if Index (Info, "Tinker Board") > 0 then
            return Tinker_Board;
        end if;

        return None;
    end Model_Of;

    --------------------------------------------------

    function Open return Boolean is
    begin
        -- A missing or unreadable file gives an empty name, which no model matches
        Current_Model := Model_Of (File_Utils.Read_First_Line (Device_Tree_File));

        if Current_Model = None then
            return False;
        end if;

        CPU_Load.Start;

        return True;
    end Open;

    --------------------------------------------------

    function Get_Power return Long_Float is
        Usage : Long_Float;
        Power : Long_Float := 0.0;
    begin
        if Current_Model = None then
            return 0.0;
        end if;

        Usage := CPU_Load.Usage;

        -- Not measured: report 0 W, not the idle power the model gives for a usage of 0
        if Usage < 0.0 then
            return 0.0;
        end if;

        Usage := Long_Float'Min (1.0, Usage);

        for Degree in Power_Model'Range loop
            Power := Power + (Models (Current_Model) (Degree) * (Usage ** Degree));
        end loop;

        -- A model can dip below zero near the end of its range
        return Long_Float'Max (0.0, Power);
    end Get_Power;

    --------------------------------------------------

    procedure Close is
    begin
        Current_Model := None;
    end Close;

end Joular_Core.RPI;
