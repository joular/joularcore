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

-- Read the CPU and the GPU power of Apple Silicon Macs, from the powermetrics tool of macOS
-- powermetrics reports both in the same output, so one process serves both hardware sources: it is started by the first one asking for it, and killed once neither of them uses it any more
private package Joular_Core.Powermetrics is

    -- Start powermetrics if it is not started yet, and wait for its first sample
    -- Always returns False on other platforms, on Mac Intel, and when the program is not run as root
    function Is_Accessible return Boolean;

    -- Get the CPU power of the last sample, in watts
    -- Returns zero when powermetrics stops answering
    function Get_CPU_Power return Long_Float;

    -- Get the GPU power of the last sample, in watts
    -- Returns zero when powermetrics stops answering
    function Get_GPU_Power return Long_Float;

    -- Let go of the process, which is killed once neither the CPU nor the GPU uses it any more
    procedure Close;

end Joular_Core.Powermetrics;
