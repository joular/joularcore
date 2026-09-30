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

-- Linux and BSD, where the versioned name is the one always present
separate (Joular_Core.GPU_Nvidia_NVML)
function Load_Library return System.Address is
    Library : constant System.Address := Load ("libnvidia-ml.so.1");
begin
    if Library /= System.Null_Address then
        return Library;
    end if;

    return Load ("libnvidia-ml.so");
end Load_Library;
