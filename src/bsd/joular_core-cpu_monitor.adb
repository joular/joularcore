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

-- BSD: no CPU is supported yet
package body Joular_Core.CPU_Monitor is

    function Open return Boolean is
    begin
        return False;
    end Open;

    --------------------------------------------------

    function Read return Measurement is
    begin
        return (others => <>);
    end Read;

    --------------------------------------------------

    procedure Close is
    begin
        null;
    end Close;

end Joular_Core.CPU_Monitor;
