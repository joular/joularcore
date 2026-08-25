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

with Ada.Text_IO; use Ada.Text_IO;

package body Joular_Core.RAPL_Powercap is

    -- RAPL files in powercap sysfs
    RAPL_Path : constant String := "/sys/class/powercap/intel-rapl:0";
    Energy_File : constant String := RAPL_Path & "/energy_uj";
    Max_Range_File : constant String := RAPL_Path & "/max_energy_range_uj";
    -- Name_File : constant String := RAPL_Path & "/name";
    
    --------------------------------------------------
    
    -- Util function to read RAPL files (energy or max range file)
    function Read_Value (File_Name : in String) return Long_Long_Integer is
        F_Name : File_Type;
        Value : Long_Long_Integer;
    begin
        Open (F_Name, In_File, File_Name);
        Value := Long_Long_Integer'Value (Get_Line (F_Name));
        Close (F_Name);
        return Value;
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            return 0;
    end Read_Value;
    
    --------------------------------------------------
    
    function Open return Boolean is
    begin
        -- On Linux, nothing to do (no drivers to open)
        -- Just take first reading and check it is not zero
        return Read_Value (Energy_File) /= 0;
    end Open;

    --------------------------------------------------
    
    function Max_Energy_Range return Long_Long_Integer is
    begin
        return Read_Value (Max_Range_File);
    end Max_Energy_Range;
    
    --------------------------------------------------

    function Read_Counter return Long_Long_Integer is
    begin
        return Read_Value (Energy_File);
    end Read_Counter;
    
    --------------------------------------------------
    
    procedure Close is
    begin
        -- Nothing to do on Linux
        null;
    end Close;

end Joular_Core.RAPL_Powercap;
