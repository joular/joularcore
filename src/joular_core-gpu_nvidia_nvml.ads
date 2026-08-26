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

-- Read the power consumption of an Nvidia GPU through NVML
-- Requires the Nvidia driver, on Linux, Windows or BSD
private package Joular_Core.GPU_Nvidia_NVML is

    -- Checks if an Nvidia card can be read on the system
    -- Loads NVML, starts it and takes one reading
    -- Always returns false on unsupported systems (i.e., macOS)
    function Is_Accessible return Boolean;

    -- Get a power reading in watts
    -- Returns zero if the GPU power cannot be read
    function Get_Power return Long_Float;

    -- Stop NVML and unload the library
    procedure Close;

end Joular_Core.GPU_Nvidia_NVML;
