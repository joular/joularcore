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

-- Power of the AMD GPU on Linux, from the hwmon sysfs of the amdgpu kernel driver (nothing to install)
private package Joular_Core.GPU_AMD_Sysfs is

    -- Finds every amdgpu sensor with a readable power file, False when there is none
    function Open return Boolean;

    -- Power drawn by all the cards, in watts; a card that cannot be read counts zero
    function Get_Power return Long_Float;

    -- Forgets the cards found, nothing to release
    procedure Close;

end Joular_Core.GPU_AMD_Sysfs;
