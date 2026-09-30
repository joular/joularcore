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

with Joular_Core.Powermetrics;

-- macOS: the GPU built in the chip of Apple Silicon Macs, through powermetrics (Mac Intel report none)
package body Joular_Core.GPU_Monitor is

    function Open return Boolean is
    begin
        return Powermetrics.Open (GPU);
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        return (Available => True, Value => Powermetrics.Get_Power (GPU), Unit => Power);
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        Powermetrics.Close (GPU);
    end Close;

end Joular_Core.GPU_Monitor;
