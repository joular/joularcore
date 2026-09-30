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

-- Read the CPU and the GPU power of Macs, from the powermetrics tool of macOS (Mac Intel: the CPU only)
-- One powermetrics process serves both CPU and GPU: started by the first Open, killed by the last Close
private package Joular_Core.Powermetrics is

    -- Start powermetrics if it is not started yet, and wait for its first sample
    -- Returns False for the GPU on Mac Intel, and when the program is not run as root
    function Open (Item : in Source) return Boolean;

    -- Get the power of the source in the last sample, in watts
    -- Returns zero when powermetrics stops answering
    function Get_Power (Item : in Source) return Long_Float;

    -- Let go of the process
    procedure Close (Item : in Source);

end Joular_Core.Powermetrics;
