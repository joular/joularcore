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

package Joular_Core.RAPL_Powercap is

    -- Checks if RAPL files exist and are accessible
    -- Checks only PKG domains, on the main CPU socket only
    function Is_Accessible return Boolean;

    -- Get maximum energy range for the RAPL counter and stores it in the supplied data structure
    procedure Get_Max_Energy_Range (RAPL_Data_Element : in out RAPL_Data);

    -- Get energy reading for RAPL
    procedure Get_Energy (RAPL_Data_Element : in out RAPL_Data);

end Joular_Core.RAPL_Powercap;