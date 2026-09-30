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

with Joular_Core.CPU_Monitor;
with Joular_Core.GPU_Monitor;

package body Joular_Core is

    -- Keep it the same as the version in alire.toml
    Version_Number : constant String := "0.0.4";

    -- The sources asked for in Open that could be opened
    Opened_Sources : Source_List := (others => False);

    --------------------------------------------------

    -- Each source is closed on its own, so a crash on one doesn't prevent the other from closing
    procedure Close_Source (Item : in Source) is
    begin
        case Item is
            when CPU => CPU_Monitor.Close;
            when GPU => GPU_Monitor.Close;
        end case;
    exception
        when others =>
            null;
    end Close_Source;

    --------------------------------------------------

    -- If anything fails halfway, close it so a driver or library already opened is not left behind
    function Open_Source (Item : in Source) return Boolean is
    begin
        case Item is
            when CPU => return CPU_Monitor.Open;
            when GPU => return GPU_Monitor.Open;
        end case;
    exception
        when others =>
            Close_Source (Item);
            return False;
    end Open_Source;

    --------------------------------------------------

    -- A source that fails to answer reports zero, and is still available
    function Read_Source (Item : in Source) return Measurement is
    begin
        case Item is
            when CPU => return CPU_Monitor.Read;
            when GPU => return GPU_Monitor.Read;
        end case;
    exception
        when others =>
            return (Available => True, others => <>);
    end Read_Source;

    --------------------------------------------------

    procedure Open (Sources : in Source_List := All_Sources) is
    begin
        -- Start from nothing, in case Open is called twice
        Close;

        -- Each monitor detects the hardware, and takes a first reading of cumulative counters (e.g. RAPL)
        for Item in Source loop
            Opened_Sources (Item) := Sources (Item) and then Open_Source (Item);
        end loop;
    end Open;

    --------------------------------------------------

    procedure Close is
    begin
        for Item in Source loop
            Close_Source (Item);
        end loop;

        Opened_Sources := (others => False);
    end Close;

    --------------------------------------------------

    function Read return Reading is
        Result : Reading;
    begin
        for Item in Source loop
            if Opened_Sources (Item) then
                Result (Item) := Read_Source (Item);
            end if;
        end loop;

        return Result;
    end Read;

    --------------------------------------------------

    function Version return String is
    begin
        return Version_Number;
    end Version;

end Joular_Core;
