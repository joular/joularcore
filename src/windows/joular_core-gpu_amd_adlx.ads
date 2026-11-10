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

-- Power of the AMD GPU on Windows, through ADLX, which comes with the AMD driver
private package Joular_Core.GPU_AMD_ADLX is

    -- Loads ADLX, starts it and takes one reading of every card; False if any step fails or no card reports power
    function Open return Boolean;

    -- Power drawn by all the cards, in watts; a card that cannot be read counts zero
    function Get_Power return Long_Float;

    -- Stop ADLX and unload the library
    procedure Close;

end Joular_Core.GPU_AMD_ADLX;
