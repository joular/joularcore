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

package body Joular_Core.File_Utils is

    function Read_First_Line (File_Name : in String) return String is
        F_Name : File_Type;
    begin
        Open (F_Name, In_File, File_Name);

        if End_Of_File (F_Name) then
            Close (F_Name);
            return "";
        end if;

        declare
            Value : constant String := Get_Line (F_Name);
        begin
            Close (F_Name);
            return Value;
        end;
    exception
        when others =>
            if Is_Open (F_Name) then
                Close (F_Name);
            end if;
            return "";
    end Read_First_Line;

end Joular_Core.File_Utils;
