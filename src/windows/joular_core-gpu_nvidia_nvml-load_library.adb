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

-- Windows, where the driver installs NVML in the system folder, or in the Nvidia folder of Program Files for older drivers
separate (Joular_Core.GPU_Nvidia_NVML)
function Load_Library return System.Address is

    function Program_Files_Folder return String is
        CSIDL_PROGRAM_FILES : constant int := 16#26#;

        -- SHGetFolderPathA writes at most this many characters
        MAX_PATH : constant := 260;

        S_OK : constant int := 0;

        type Get_Folder_Function is access function
           (Owner : System.Address;
            Folder : int;
            Token : System.Address;
            Flags : unsigned;
            Path : System.Address) return int;
        pragma Convention (Stdcall, Get_Folder_Function);

        function To_Get_Folder is
            new Ada.Unchecked_Conversion (System.Address, Get_Folder_Function);

        Shell : System.Address;
        Get_Folder : Get_Folder_Function;
        Buffer : aliased char_array (0 .. MAX_PATH) := (others => nul);
        Result : int;
    begin
        Shell := Load ("shell32.dll");

        if Shell = System.Null_Address then
            return "";
        end if;

        Get_Folder := To_Get_Folder (Find_Symbol (Shell, "SHGetFolderPathA"));

        if Get_Folder = null then
            Unload (Shell);
            return "";
        end if;

        Result := Get_Folder
           (Owner => System.Null_Address,
            Folder => CSIDL_PROGRAM_FILES,
            Token => System.Null_Address,
            Flags => 0,
            Path => Buffer'Address);

        Unload (Shell);

        if Result /= S_OK then
            return "";
        end if;

        return To_Ada (Buffer);
    end Program_Files_Folder;

    Library : constant System.Address := Load ("nvml.dll");
begin
    if Library /= System.Null_Address then
        return Library;
    end if;

    -- Older drivers put it under Program Files
    declare
        Folder : constant String := Program_Files_Folder;
    begin
        if Folder = "" then
            return System.Null_Address;
        end if;

        return Load (Folder & "\NVIDIA Corporation\NVSMI\nvml.dll");
    end;
end Load_Library;
