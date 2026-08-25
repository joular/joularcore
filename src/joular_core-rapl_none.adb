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

package body Joular_Core.RAPL_None is

    function Open return Boolean is
    begin
        return False;
    end Open;
    
    --------------------------------------------------
    
    function Max_Energy_Range return Long_Long_Integer is
    begin
        return 0;
    end Max_Energy_Range;
    
    --------------------------------------------------
    
    function Read_Counter return Long_Long_Integer is
    begin
        return 0;
    end Read_Counter;
    
    --------------------------------------------------
    
    procedure Close is
    begin
        null;
    end Close;

end Joular_Core.RAPL_None;
