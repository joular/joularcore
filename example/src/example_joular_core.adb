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
--  Works on Linux (Intel/AMD RAPL, Raspberry Pi models), Windows (RAPL through Windows' Energy Meter Interface or through the MSR registers), macOS (Apple Silicon through powermetrics), and with Nvidia (NVML) and AMD (sysfs, ADLX) GPUs
--
--  On Windows the RAPL counter is reached in one of three ways, and naming one on the command line tries that one alone:
--      example_joular_core emi
--      example_joular_core pawnio
--      example_joular_core hubblo
--  emi is the meter that doesn't need a driver or admin rights
--  PawnIO only answers a program running as administrator, so trying it needs an elevated terminal, while Hubblo's driver works from any terminal
--
--  A number stops the program after that many readings, for scripted runs:
--      example_joular_core pawnio 10
--
--  Prints a summary on exit: per source, whether it opened, how many readings were zero, and the power range

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings; use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with GNAT.Ctrl_C;

with Joular_Core; use Joular_Core;

procedure Example_Joular_Core is

    --  Time asked for between two readings
    Interval : constant Duration := 1.0;

    --  Read by the library on Windows to use one RAPL reader instead of trying them in turn
    Driver_Variable : constant String := "JOULARCORE_WINDOWS_RAPL";

    --  Set to True when Ctrl+C is pressed, so the reading loop stops
    --  Atomic, as the handler runs in another thread on Windows
    Stop_Asked : Boolean := False with Atomic;

    --  Only sets the flag: printing and closing files are not safe from a handler
    procedure On_Ctrl_C is
    begin
        Stop_Asked := True;
    end On_Ctrl_C;

    package Value_IO is new Ada.Text_IO.Float_IO (Long_Float);

    --  ANSI escape sequences: cyan for the CPU, magenta for the GPU, green for what worked, red for what did not
    Escape : constant Character := ASCII.ESC;
    Reset : constant String := Escape & "[0m";
    CPU_Colour : constant String := Escape & "[1;36m";
    GPU_Colour : constant String := Escape & "[1;35m";
    Ready_Colour : constant String := Escape & "[1;32m";
    Failed_Colour : constant String := Escape & "[1;31m";

    --  Each reading overwrites the previous one instead of scrolling
    Clear_Line : constant String := ASCII.CR & Escape & "[2K";

    type Statistics is
       record
           Available : Boolean := False; --  Whether the source was opened at all
           Readings : Natural := 0; --  How many readings were taken from it
           Answered : Natural := 0; --  How many of them came back with something other than zero
           Energy : Long_Float := 0.0; --  Joules added up
           Seconds : Long_Float := 0.0; --  Time for the energy measurement
           Lowest : Long_Float := Long_Float'Last;
           Highest : Long_Float := 0.0;
       end record;

    CPU_Stats : Statistics;
    GPU_Stats : Statistics;

    --  How many readings to take before stopping on its own, or zero to run until Ctrl+C
    Wanted_Readings : Natural := 0;

    --  The RAPL reader named on the command line, or "" to try them all
    function Named_Reader return String is
       (To_Lower (Ada.Environment_Variables.Value (Driver_Variable, Default => "")));

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

    --  The library gives energy (RAPL) or power (boards, GPUs); each is converted to the other over the measured interval

    function Joules (Data : in Measurement; Over : in Duration) return Long_Float is
       (case Data.Unit is
           when Energy => Data.Value,
           when Power => Data.Value * Long_Float (Over));

    function Watts (Data : in Measurement; Over : in Duration) return Long_Float is
       (case Data.Unit is
           when Energy => (if Over > 0.0 then Data.Value / Long_Float (Over) else 0.0),
           when Power => Data.Value);

    --  A source that is not available is not printed as 0, which would claim the device idles
    function Image (Colour : in String; Name : in String; Data : in Measurement; Over : in Duration) return String is
       (if not Data.Available
        then Colour & Name & " n/a" & Reset
        else Colour & Name & " " & Image (Joules (Data, Over)) & " J " & Image (Watts (Data, Over)) & " W" & Reset);

    --  A zero reading is the library failing to read the counter, not an idle device, so it is counted but left out of the numbers
    procedure Record_Reading (Stats : in out Statistics; Data : in Measurement; Over : in Duration) is
        Power : constant Long_Float := Watts (Data, Over);
    begin
        if not Data.Available then
            return;
        end if;

        Stats.Readings := Stats.Readings + 1;

        if Power <= 0.0 then
            return;
        end if;

        Stats.Answered := Stats.Answered + 1;
        Stats.Energy := Stats.Energy + Joules (Data, Over);
        Stats.Seconds := Stats.Seconds + Long_Float (Over);
        Stats.Lowest := Long_Float'Min (Stats.Lowest, Power);
        Stats.Highest := Long_Float'Max (Stats.Highest, Power);
    end Record_Reading;

    procedure Put_Summary (Colour : in String; Name : in String; Stats : in Statistics) is
        Zeros : constant Natural := Stats.Readings - Stats.Answered;
    begin
        Put (Colour & Name & Reset & " ");

        if not Stats.Available then
            Put_Line (Failed_Colour & "not available on this device" & Reset);
        elsif Stats.Readings = 0 then
            Put_Line ("opened, but stopped before a reading was taken");
        elsif Stats.Answered = 0 then
            Put_Line (Failed_Colour & "opened but read nothing:" & Natural'Image (Stats.Readings) & " readings, all of them zero" & Reset);
        else
            Put_Line ((if Zeros = 0 then Ready_Colour else Failed_Colour)
                      & Trim (Natural'Image (Stats.Readings), Left) & " readings,"
                      & Natural'Image (Zeros) & " of them zero" & Reset
                      & " | " & Image (Stats.Lowest) & " W lowest"
                      & " | " & Image (if Stats.Seconds > 0.0 then Stats.Energy / Stats.Seconds else 0.0) & " W average"
                      & " | " & Image (Stats.Highest) & " W highest");
        end if;
    end Put_Summary;

    --  What to check when the CPU did not open, per OS
    procedure Put_CPU_Hint is
    begin
#if PJ_WINDOWS then
        if Named_Reader = "emi" then
            Put_Line ("The Energy Meter Interface needs no driver or elevated terminal, so this machine publishes no meter holding a RAPL package counter (Windows 11 does on most processors)");
            Put_Line ("Try pawnio or hubblo to read the registers directly, if either driver is installed");
        elsif Named_Reader = "pawnio" then
            Put_Line ("PawnIO only answers a program running as administrator, so run this from an elevated terminal");
            Put_Line ("Failing that, it is not installed, is not running, or its module turned this processor down");
        elsif Named_Reader = "hubblo" then
            Put_Line ("Hubblo's driver needs no elevation, so it is not installed, is not running, or this processor has no RAPL counter to read");
        else
            Put_Line ("Tried the Energy Meter Interface, then PawnIO (which only answers an elevated terminal), then Hubblo's driver");
            Put_Line ("So this machine publishes no such meter, neither driver is installed and running, or this processor has no RAPL counter to read");
        end if;
#elsif PJ_MACOS then
        Put_Line ("macOS reports the power of the chip through /usr/bin/powermetrics, which only answers a program running as root, so run this with sudo");
        Put_Line ("Failing that, this is an Intel Mac: only Apple Silicon is supported");
#elsif PJ_LINUX then
        Put_Line ("The RAPL counter in /sys/class/powercap/intel-rapl is only readable by root on most distributions, so run this with sudo");
        Put_Line ("Raspberry Pi and other supported boards have no counter, and are read from a model of the board named in /proc/device-tree/model");
#else
        Put_Line ("BSD systems are not supported yet");
#end if;
    end Put_CPU_Hint;

    --  Reads the command line: the RAPL reader to use alone, and how many readings to take
    procedure Read_Arguments is
    begin
        for I in 1 .. Argument_Count loop
            declare
                Wanted : constant String := To_Lower (Argument (I));
            begin
                if Wanted = "emi" or else Wanted = "pawnio" or else Wanted = "hubblo" then
                    Ada.Environment_Variables.Set (Driver_Variable, Wanted);
                    Put_Line ("Windows RAPL reader: " & Wanted & ", and not the others");
                else
                    Wanted_Readings := Natural'Value (Wanted);
                    Put_Line ("Stopping after" & Natural'Image (Wanted_Readings) & " readings");
                end if;
            exception
                when others =>
                    Put_Line ("Ignoring " & Argument (I) & ", expected emi, pawnio, hubblo, or a number of readings");
            end;
        end loop;
    end Read_Arguments;

    Measurements : Reading;
    Taken : Natural := 0; --  How many readings the loop below took
    Previous_Time : Time; --  When the reading before this one was taken
    Next_Time : Time; --  When the next one is due
    Now : Time;
    Covered : Duration; --  How long the reading just taken actually covers

begin
    Put_Line (Ready_Colour & "Joular Core " & Version & Reset);

    --  Before Open, which reads the RAPL reader variable
    Read_Arguments;

    --  'Access is not allowed here as the handler is nested
    GNAT.Ctrl_C.Install_Handler (On_Ctrl_C'Unrestricted_Access);

    Open;

    --  First reading only covers the time since Open, so it is not counted
    Measurements := Read;
    CPU_Stats.Available := Measurements (CPU).Available;
    GPU_Stats.Available := Measurements (GPU).Available;

    Put_Line ("CPU " & (if CPU_Stats.Available then Ready_Colour & "opened" else Failed_Colour & "not available") & Reset
              & " | GPU " & (if GPU_Stats.Available then Ready_Colour & "opened" else Failed_Colour & "not available") & Reset);

    Previous_Time := Clock;
    Next_Time := Previous_Time;

    while not Stop_Asked loop
        Next_Time := Next_Time + To_Time_Span (Interval);
        delay until Next_Time;

        exit when Stop_Asked;

        Measurements := Read;

        Now := Clock;
        Covered := To_Duration (Now - Previous_Time);
        Previous_Time := Now;

        Record_Reading (CPU_Stats, Measurements (CPU), Covered);
        Record_Reading (GPU_Stats, Measurements (GPU), Covered);
        Taken := Taken + 1;

        Put (Clear_Line
             & Image (CPU_Colour, "CPU", Measurements (CPU), Covered)
             & " | "
             & Image (GPU_Colour, "GPU", Measurements (GPU), Covered));
        Flush;

        exit when Wanted_Readings > 0 and then Taken >= Wanted_Readings;
    end loop;

    --  The readings share one line, so end it first
    New_Line;
    Put_Line (Ready_Colour & "Stopping" & Reset);
    Close;

    New_Line;
    Put_Summary (CPU_Colour, (if Named_Reader = "" then "CPU" else "CPU (" & Named_Reader & ")"), CPU_Stats);
    Put_Summary (GPU_Colour, "GPU", GPU_Stats);

    if not CPU_Stats.Available then
        New_Line;
        Put_CPU_Hint;
    end if;
end Example_Joular_Core;
