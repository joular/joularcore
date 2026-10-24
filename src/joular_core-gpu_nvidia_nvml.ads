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

private package Joular_Core.GPU_Nvidia_NVML is

    -- Load NVML, start it and take one reading of every card
    -- Returns False when the driver is not installed or no card answers
    function Open return Boolean;

    -- Power drawn by all the cards, in watts; a card that cannot be read counts zero
    function Get_Power return Long_Float;

    -- Stop NVML and unload the library
    procedure Close;

end Joular_Core.GPU_Nvidia_NVML;
