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

private package Joular_Core.File_Utils is

    -- Read the first line of a file (system files holding a value are usually one line)
    -- Returns an empty String when the file doesn't exist, is empty, or cannot be read
    function Read_First_Line (File_Name : in String) return String;

end Joular_Core.File_Utils;
