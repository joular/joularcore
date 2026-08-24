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

with Joular_Core.RAPL_Type; use Joular_Core.RAPL_Type;

with Ada.Text_IO; use Ada.Text_IO;

package body Joular_Core.RAPL_Powercap is

    -- RAPL files in powercap sysfs
    RAPL_Path : constant String := "/sys/class/powercap/intel-rapl:0";
    Energy_File : constant String := RAPL_Path & "/energy_uj";
    Max_Range_File : constant String := RAPL_Path & "/max_energy_range_uj";
    Name_File : constant String := RAPL_Path & "/name";

    --------------------------------------------------

    function Is_Accessible return Boolean is
        F_Name : File_Type;
    begin
        Open (F_Name, In_File, Name_File);
        declare
            Domain_Name : constant String := Get_Line (F_Name);
        begin
            Close (F_Name);
            -- If not PKG, return false
            if Domain_Name /= "package-0" then
                return False;
            end if;
        end;

        -- It is PKG, so check if energy file can be read
        Open (F_Name, In_File, Energy_File);
        declare
            Energy_Value : constant String := Get_Line (F_Name);
        begin
            Close (F_Name);
            return Energy_Value /= "";
        end;
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            return False;
    end Is_Accessible;

    --------------------------------------------------

    procedure Get_Max_Energy_Range (RAPL_Data_Element : in out RAPL_Data) is
        F_Name : File_Type;
    begin
        Open (F_Name, In_File, Max_Range_File);
        RAPL_Data_Element.PKG_Max_Energy_Range := Long_Long_Integer'Value (Get_Line (F_Name));
        Close (F_Name);
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            RAPL_Data_Element.PKG_Max_Energy_Range := 0;
    end Get_Max_Energy_Range;
    
    --------------------------------------------------

    procedure Get_Energy (RAPL_Data_Element : in out RAPL_Data) is
        F_Name : File_Type;
        New_Raw_Energy : Long_Long_Integer;
    begin
        Open (F_Name, In_File, Energy_File);
        New_Raw_Energy := Long_Long_Integer'Value (Get_Line (F_Name));
        Close (F_Name);

        -- Calculate energy since last reading
        RAPL_Data_Element.PKG_Energy := New_Raw_Energy - RAPL_Data_Element.PKG_Raw_Energy;

        -- If negative energy, then it means RAPL counter wrapped, so correct it with max energy range
        if RAPL_Data_Element.PKG_Energy < 0 then
            RAPL_Data_Element.PKG_Energy := RAPL_Data_Element.PKG_Energy + RAPL_Data_Element.PKG_Max_Energy_Range;
        end if;

        -- Store the raw value measured, for the next reading
        RAPL_Data_Element.PKG_Raw_Energy := New_Raw_Energy;
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            RAPL_Data_Element.PKG_Energy := 0;
    end Get_Energy;

end Joular_Core.RAPL_Powercap;