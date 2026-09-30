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

-- CPU power of SBC boards (Raspberry Pi, Asus Tinker Board) from our regression power models, in watts
private package Joular_Core.RPI is

    -- True when the board has a power model; also takes the first CPU load reading
    function Open return Boolean;

    -- Average CPU power since the last reading, in watts; zero without a board model or a measured interval
    function Get_Power return Long_Float;

    -- Forgets the board model, nothing to release
    procedure Close;

end Joular_Core.RPI;
