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
--
--  On Windows the RAPL registers are reached through one of two drivers, and naming one on the command line tries that one alone:
--      example_joular_core pawnio
--      example_joular_core hubblo
--  Naming one sets JOULARCORE_WINDOWS_RAPL before the library is opened, so it does not try PawnIO first and fall back to Hubblo's driver
--  PawnIO only answers a program running as administrator, so trying it needs an elevated terminal, while Hubblo's driver works from any terminal
--
--  A number stops the program after that many readings instead of running until Ctrl+C, which is what makes the run scriptable:
--      example_joular_core pawnio 10
--
--  A summary is printed when the program stops, whichever way it stopped, saying whether the driver opened, how many of its readings came back empty, and what range of power it reported

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with GNAT.Ctrl_C;

with Joular_Core; use Joular_Core;

procedure Example_Joular_Core is

    --  Time between two readings
    Interval : constant Duration := 1.0;

    --  The variable the library reads on Windows to use one RAPL driver instead of trying both
    --  It is read when Open is called, so it is set before that
    Driver_Variable : constant String := "JOULARCORE_WINDOWS_RAPL";

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

    --  ANSI escape sequences:  cyan for the CPU, magenta for the GPU, green for the start up message, red for a source that gave nothing
    Escape : constant Character := ASCII.ESC;
    Reset : constant String := Escape & "[0m";
    CPU_Colour : constant String := Escape & "[1;36m";
    GPU_Colour : constant String := Escape & "[1;35m";
    Ready_Colour : constant String := Escape & "[1;32m";
    Failed_Colour : constant String := Escape & "[1;31m";

    --  Goes back to the beginning of the line and erases it, so each reading overwrites the previous one instead of scrolling
    Clear_Line : constant String := ASCII.CR & Escape & "[2K";

    --  What the readings of one source amounted to, kept so the summary can say whether the driver held up rather than only whether it opened
    --  A driver that opens and then answers nothing is what a broken one looks like from here, and that only shows over several readings
    type Statistics is
       record
           Available : Boolean := False; --  Whether the source was opened at all
           Readings : Natural := 0; --  How many readings were taken from it
           Answered : Natural := 0; --  How many of them came back with something other than zero
           Total : Long_Float := 0.0; --  Watts added up, to give the average
           Lowest : Long_Float := Long_Float'Last;
           Highest : Long_Float := 0.0;
       end record;

    CPU_Stats : Statistics;
    GPU_Stats : Statistics;

    --  The driver named on the command line, or nothing when both are to be tried
    function Named_Driver return String is
       (if Ada.Environment_Variables.Exists (Driver_Variable)
        then Ada.Environment_Variables.Value (Driver_Variable)
        else "");

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

    --  Depending on the hardware, the library gives either the energy consumed since the last reading (i.e., RAPL), or the power drawn (i.e., Raspberry Pi models and GPUs)
    --  Each is turned into the other here, according to the time interval, so a reading is printed and compared the same way whichever unit it came in

    function Joules (Data : in Measurement) return Long_Float is
       (case Data.Unit is
           when Energy => Data.Value,
           when Power => Data.Value * Long_Float (Interval));

    function Watts (Data : in Measurement) return Long_Float is
       (case Data.Unit is
           when Energy => Data.Value / Long_Float (Interval),
           when Power => Data.Value);

    --  Formats one hardware source as both energy (joules) and power (watts)
    function Image (Colour : in String;
                    Name : in String;
                    Data : in Measurement) return String is
    begin
        --  The source was not requested, or is not supported on this device
        --  It is not printed as 0, which would claim the device idles
        if not Data.Available then
            return Colour & Name & " n/a" & Reset;
        end if;

        return Colour & Name
               & " " & Image (Joules (Data)) & " J"
               & " " & Image (Watts (Data)) & " W"
               & Reset;
    end Image;

    --  Adds one reading to what is known of a source
    procedure Record_Reading (Stats : in out Statistics; Data : in Measurement) is
        Power : Long_Float;
    begin
        if not Data.Available then
            return;
        end if;

        Stats.Readings := Stats.Readings + 1;
        Power := Watts (Data);

        --  A reading of zero is the library saying it could not read the counter, not a device drawing no power at all, so it counts as a reading but is left out of the numbers below
        if Power <= 0.0 then
            return;
        end if;

        Stats.Answered := Stats.Answered + 1;
        Stats.Total := Stats.Total + Power;

        if Power < Stats.Lowest then
            Stats.Lowest := Power;
        end if;

        if Power > Stats.Highest then
            Stats.Highest := Power;
        end if;
    end Record_Reading;

    --  Prints what one source gave over the whole run
    procedure Put_Summary (Colour : in String; Name : in String; Stats : in Statistics) is
    begin
        Put (Colour & Name & Reset & " ");

        if not Stats.Available then
            Put_Line ("not available on this device");
            return;
        end if;

        if Stats.Readings = 0 then
            Put_Line ("opened, but stopped before a reading was taken");
            return;
        end if;

        if Stats.Answered = 0 then
            Put_Line (Natural'Image (Stats.Readings) & " readings, all of them zero");
            return;
        end if;

        Put_Line (Natural'Image (Stats.Readings) & " readings,"
                  & Natural'Image (Stats.Readings - Stats.Answered) & " of them zero"
                  & " | " & Image (Stats.Lowest) & " W lowest"
                  & " | " & Image (Stats.Total / Long_Float (Stats.Answered)) & " W average"
                  & " | " & Image (Stats.Highest) & " W highest");
    end Put_Summary;

    --  Says in one line what the run showed of the driver reading the CPU, which is the point of naming one on the command line
    procedure Put_Verdict (Stats : in Statistics) is
        Driver : constant String := Named_Driver;
        Which : constant String := (if Driver = "" then "The CPU" else Driver);
    begin
        if not Stats.Available then
            Put_Line (Failed_Colour & Which & " did not open" & Reset);

            --  The two Windows drivers do not ask for the same rights, so what to try next depends on which one was asked for
            --  PawnIO only answers a program running as administrator, which is the usual reason it does not answer while being installed and running, while Hubblo's driver reads from any terminal and is never held back by that
            if To_Lower (Driver) = "pawnio" then
                Put_Line ("PawnIO only answers a program running as administrator, so run this from an elevated terminal");
                Put_Line ("Failing that, it is not installed, is not running, or its module turned this processor down");
                Put_Line ("Trying hubblo instead reads without an elevated terminal, if that driver is installed");
            elsif To_Lower (Driver) = "hubblo" then
                Put_Line ("Hubblo's driver needs no elevation, so it is not installed, is not running, or this processor has no RAPL counter to read");
            else
                Put_Line ("On Windows, PawnIO is tried first and only answers an elevated terminal, and Hubblo's driver is tried after it and needs none");
                Put_Line ("So neither is installed, neither is running, or this processor has no RAPL counter to read");
            end if;

            return;
        end if;

        if Stats.Readings = 0 then
            Put_Line (Which & " opened, but no reading was taken: let it run a few seconds to tell whether it reads");
            return;
        end if;

        if Stats.Answered = 0 then
            Put_Line (Failed_Colour & Which & " opened but read nothing: every reading came back zero" & Reset);
            return;
        end if;

        if Stats.Answered < Stats.Readings then
            Put_Line (Failed_Colour & Which & " reads, but not every time:"
                      & Natural'Image (Stats.Readings - Stats.Answered) & " of"
                      & Natural'Image (Stats.Readings) & " readings came back zero" & Reset);
            return;
        end if;

        Put_Line (Ready_Colour & Which & " reads:"
                  & Natural'Image (Stats.Readings) & " readings, none of them zero" & Reset);
    end Put_Verdict;

    --  How many readings to take before stopping on its own, or zero to run until Ctrl+C
    Wanted_Readings : Natural := 0;

    --  Reads the command line: the driver to use alone, and how many readings to take
    --  Either can be given, in any order, as they cannot be mistaken for one another
    procedure Read_Arguments is
    begin
        for I in 1 .. Argument_Count loop
            declare
                Wanted : constant String := To_Lower (Argument (I));
            begin
                if Wanted = "pawnio" or else Wanted = "hubblo" then
                    --  The library reads this when it is opened, which has not happened yet
                    Ada.Environment_Variables.Set (Driver_Variable, Wanted);
                    Put_Line ("Windows RAPL driver: " & Wanted & ", and not the other one");
                else
                    --  Anything that is not a driver is a count of readings, and anything that is neither is pointed out rather than passed over
                    Wanted_Readings := Natural'Value (Wanted);
                    Put_Line ("Stopping after" & Natural'Image (Wanted_Readings) & " readings");
                end if;
            exception
                when others =>
                    Put_Line ("Ignoring " & Argument (I) & ", expected pawnio, hubblo, or a number of readings");
            end;
        end loop;
    end Read_Arguments;

    --  How many readings the loop below took, which is what stops it when a count was asked for
    --  Counted apart from the statistics, as those only follow a source that opened, while the loop runs either way
    Taken : Natural := 0;

    Measurements : Reading;

begin
    Put_Line (Ready_Colour & "Joular Core " & Version & Reset);

    --  Before Open, as that is when the library looks at which driver it is asked for
    Read_Arguments;

    --  Stop cleanly on Ctrl+C, instead of being killed on the spot
    --  Unrestricted_Access is needed as the handler is declared inside this procedure rather than on its own
    GNAT.Ctrl_C.Install_Handler (On_Ctrl_C'Unrestricted_Access);

    --  Detect and open every supported hardware source (CPU and GPU)
    Open;

    --  Which sources came up, taken from a reading, as Open reports nothing
    --  This first reading is thrown away rather than counted: it covers the moment since Open rather than a whole interval, so its value means nothing, while whether the source is there at all is already settled by then
    Measurements := Read;
    CPU_Stats.Available := Measurements (CPU).Available;
    GPU_Stats.Available := Measurements (GPU).Available;

    Put_Line ("CPU " & (if CPU_Stats.Available then Ready_Colour & "opened" else Failed_Colour & "not available") & Reset
              & " | GPU " & (if GPU_Stats.Available then Ready_Colour & "opened" else Failed_Colour & "not available") & Reset);

    while not Stop_Asked loop
        delay Interval;

        exit when Stop_Asked;

        --  Take one reading of all the hardware sources opened above
        Measurements := Read;

        Record_Reading (CPU_Stats, Measurements (CPU));
        Record_Reading (GPU_Stats, Measurements (GPU));
        Taken := Taken + 1;

        Put (Clear_Line
             & Image (CPU_Colour, "CPU", Measurements (CPU))
             & " | "
             & Image (GPU_Colour, "GPU", Measurements (GPU)));
        Flush;

        --  Only when a count was asked for, as zero means running until Ctrl+C
        exit when Wanted_Readings > 0 and then Taken >= Wanted_Readings;
    end loop;

    --  Ctrl+C was pressed, or the readings asked for were taken, so close the sources opened above
    --  The readings are printed on a single line, so end it before printing anything else
    New_Line;
    Put_Line (Ready_Colour & "Stopping" & Reset);
    Close;

    --  What the run added up to, which is what tells a driver that reads from one that only opens
    New_Line;
    Put_Summary (CPU_Colour, "CPU", CPU_Stats);
    Put_Summary (GPU_Colour, "GPU", GPU_Stats);
    New_Line;
    Put_Verdict (CPU_Stats);
end Example_Joular_Core;
