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

-- Estimate the CPU power consumption (in watts) of SBC boards (Raspberry Pi, Asus Tinker Board), using our regression power models
private package Joular_Core.RPI is

    -- Check if the device is a SBC board with a power model available for it
    -- Also takes a first reading of CPU load, so the next reading can calculate CPU usage, which is needed for the power models
    function Is_Accessible return Boolean;

    -- Get the average CPU power since the last reading, in watts
    -- Returns zero when the board model isn't supported
    function Get_Power return Long_Float;

    -- Forget the board model used, nothing else to do
    procedure Close;

end Joular_Core.RPI;
