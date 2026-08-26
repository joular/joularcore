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

-- Read the power consumption of the AMD GPU on Linux and BSD
-- Read it from hwmon sysfs, with amdgpu kernel driver (already installed on Linux, so nothing to install)
private package Joular_Core.GPU_AMD_Sysfs is

    -- Checks if an AMD card can be read on the system
    -- Look for the power files and keeps the one answering with a value
    -- Always returns false on unsupported systems (i.e., Windows, macOS)
    function Is_Accessible return Boolean;

    -- Get a power reading in watts
    -- Returns zero if the GPU power cannot be read
    function Get_Power return Long_Float;

    -- Forget the card found, nothing else to do
    procedure Close;

end Joular_Core.GPU_AMD_Sysfs;
