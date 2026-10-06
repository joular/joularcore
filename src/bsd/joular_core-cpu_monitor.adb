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

with Joular_Core.RAPL_CPUCTL;

-- BSD: RAPL through cpuctl (Intel and AMD, on FreeBSD and DragonFly); OpenBSD and NetBSD give no way to read the registers
package body Joular_Core.CPU_Monitor is

    function Open return Boolean is
    begin
        return RAPL_CPUCTL.Open;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        return (Available => True, Value => RAPL_CPUCTL.Get_Energy, Unit => Energy);
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        RAPL_CPUCTL.Close;
    end Close;

end Joular_Core.CPU_Monitor;
