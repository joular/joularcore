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

--  Prints the energy and power consumed by the CPU and the GPU every second, until stopped with Ctrl+C
--  Works on Linux (Intel/AMD RAPL, Raspberry Pi models), Windows (RAPL MSR), macOS (Apple Silicon through powermetrics), and with Nvidia (NVML) and AMD (sysfs, ADLX) GPUs

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with GNAT.Ctrl_C;

with Joular_Core; use Joular_Core;

procedure Example_Joular_Core is

    --  Time between two readings
    Interval : constant Duration := 1.0;

    --  Set to True when Ctrl+C is pressed, so the reading loop stops
    --  Volatile, as it is written while the loop below is running
    Stop_Asked : Boolean := False;
    pragma Volatile (Stop_Asked);

    --  Called when Ctrl+C is pressed
    --  It only asks the loop to stop: the sources are closed by the main part below, as printing and closing files are not safe to do from a handler
    procedure On_Ctrl_C is
    begin
        Stop_Asked := True;
    end On_Ctrl_C;

    --  Prints floats in plain digits rather than in exponent notation
    package Value_IO is new Ada.Text_IO.Float_IO (Long_Float);

    --  ANSI escape sequences:  cyan for the CPU, magenta for the GPU, green for the start up message
    Escape : constant Character := ASCII.ESC;
    Reset : constant String := Escape & "[0m";
    CPU_Colour : constant String := Escape & "[1;36m";
    GPU_Colour : constant String := Escape & "[1;35m";
    Ready_Colour : constant String := Escape & "[1;32m";

    --  Goes back to the beginning of the line and erases it, so each reading overwrites the previous one instead of scrolling
    Clear_Line : constant String := ASCII.CR & Escape & "[2K";

    --  Formats one value with two decimals and no leading blank
    function Image (Value : in Long_Float) return String is
        Buffer : String (1 .. 12);
    begin
        Value_IO.Put (To => Buffer, Item => Value, Aft => 2, Exp => 0);
        return Trim (Buffer, Left);
    exception
        --  The value does not fit in the buffer
        when others =>
            return "n/a";
    end Image;

    --  Formats one hardware source as both energy (joules) and power (watts)
    function Image (Colour : in String;
                    Name : in String;
                    Data : in Measurement) return String is
        Joules : Long_Float;
        Watts : Long_Float;
    begin
        --  The source was not requested, or is not supported on this device
        --  It is not printed as 0, which would claim the device idles
        if not Data.Available then
            return Colour & Name & " n/a" & Reset;
        end if;

        --  Depending on the hardware, the library gives either the energy consumed since the last reading (i.e., RAPL), or the power drawn (i.e., Raspberry Pi models and GPUs)
        --  Calculate Power and Energy according to the time interval
        case Data.Unit is
            when Energy =>
                Joules := Data.Value;
                Watts := Data.Value / Long_Float (Interval);
            when Power =>
                Watts := Data.Value;
                Joules := Data.Value * Long_Float (Interval);
        end case;

        return Colour & Name
               & " " & Image (Joules) & " J"
               & " " & Image (Watts) & " W"
               & Reset;
    end Image;

    Measurements : Reading;

begin
    Put_Line (Ready_Colour & "Joular Core " & Version & Reset);

    --  Stop cleanly on Ctrl+C, instead of being killed on the spot
    --  Unrestricted_Access is needed as the handler is declared inside this procedure rather than on its own
    GNAT.Ctrl_C.Install_Handler (On_Ctrl_C'Unrestricted_Access);

    --  Detect and open every supported hardware source (CPU and GPU)
    Open;

    while not Stop_Asked loop
        delay Interval;

        exit when Stop_Asked;

        --  Take one reading of all the hardware sources opened above
        Measurements := Read;

        Put (Clear_Line
             & Image (CPU_Colour, "CPU", Measurements (CPU))
             & " | "
             & Image (GPU_Colour, "GPU", Measurements (GPU)));
        Flush;
    end loop;

    --  Ctrl+C was pressed, so close the sources opened above
    --  The readings are printed on a single line, so end it before printing anything else
    New_Line;
    Put_Line (Ready_Colour & "Stopping" & Reset);
    Close;
end Example_Joular_Core;
