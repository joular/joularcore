# <a href="https://www.noureddine.org/research/joular/"><img src="https://raw.githubusercontent.com/joular/.github/main/profile/joular.png" alt="Joular Project" width="64" /></a> Joular Core :zap:

[![License: LGPL v3](https://img.shields.io/badge/License-LGPLv3-blue)](https://www.gnu.org/licenses/lgpl-3.0) [![Ada](https://img.shields.io/badge/Made%20with-Ada-blue)](https://www.adaic.org)

![Joular Core Logo](joularcore.png)

Joular Core is an Ada library that measures the energy or power consumption of hardware components.
It detects on its own what the machine offers (which CPU, which GPU, and how to read them), and gives one simple interface: open, read, close.

It is written in Ada, and also provides a [C interface](include/joularcore.h) so it can be used from any language with a C FFI (C, C++, Java, Python, Rust, etc.).

> Joular Core is under active development and currently in beta quality. Expect rough edges and features still being worked on and polished.

## :satellite: Supported platforms

| Component | Hardware | OS | Method | Reports |
|---|---|---|---|---|
| CPU | Intel, AMD | Linux | RAPL through powercap sysfs | Energy (joules) |
| CPU | Intel, AMD | Windows | RAPL MSR through [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver) | Energy (joules) |
| CPU | Raspberry Pi (5B, 400, 4B, 3B+, 3B, 2B, 1B+, 1B, Zero W), Asus Tinker Board | Linux | Regression power models | Power (watts) |
| GPU | Nvidia cards | Linux, Windows | NVML (installed with the Nvidia driver) | Power (watts) |
| GPU | AMD cards | Linux | amdgpu hwmon sysfs | Power (watts) |
| GPU | AMD cards | Windows | ADLX (installed with the AMD driver) | Power (watts) |

macOS and BSD support is planned and will come in a future version.

## Required privileges

- **Linux CPU (RAPL)**: reading `energy_uj` needs elevated access (root or read permissions) on most kernels. Run your program with `sudo`, or give the powercap files read permission.
- **Windows CPU (RAPL)**: install [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver). The easiest way to install a signed version is through the [Scaphandre installer](https://github.com/hubblo-org/scaphandre/releases/download/v1.0.0/scaphandre_v1.0.0_installer.exe).
- Raspberry Pi models and GPU readings need no special privileges.

## Building

With [Alire](https://alire.ada.dev):

```bash
alr build
```

Or directly with GNAT:

```bash
gprbuild -P joularcore.gpr
```

The build produces a static library by default, and will detect the OS to compile the appropriate version. You can specify a specific OS to compile with `-XPJ_OS` (ex. `-XPJ_OS=windows`) to gprbuild (Alire sets it on its own).

For other library types (shared, etc.), set `-XJOULARCORE_LIBRARY_TYPE`:

```bash
gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
```

`relocatable` builds the shared library (`libJoular_Core.so` / `.dll`) that carries the C interface, is stand-alone (it starts itself up when loaded), and on Linux and Windows is encapsulated (it carries the Ada runtime too, so it is one self-contained file).

## Using from Ada

```ada
with Ada.Text_IO; use Ada.Text_IO;
with Joular_Core; use Joular_Core;

procedure Measure is
    Measurements : Reading;
begin
    Open; -- Detect and open every supported hardware source

    for I in 1 .. 5 loop
        delay 1.0;
        Measurements := Read;

        if Measurements (CPU).Available then
            Put_Line ("CPU:" & Long_Float'Image (Measurements (CPU).Value)
                      & (if Measurements (CPU).Unit = Energy then " J" else " W"));
        end if;
    end loop;

    Close;
end Measure;
```

A full example program is in [example/src/example_joular_core.adb](example/src/example_joular_core.adb). It reads once per second until stopped with Ctrl+C, which closes the sources cleanly:

```bash
gprbuild -P example/example.gpr
./example/example_joular_core
```

With Alire, add the library to your project with `alr with joularcore`.

## Using from C (and any other language)

The C declarations are in [include/joularcore.h](include/joularcore.h). Build the relocatable library, then:

```c
#include "joularcore.h"

joular_reading reading;

joular_open(1, 1);   /* measure the CPU and the GPU */
joular_read(&reading);
if (reading.cpu.available)
    printf("CPU: %f %s\n", reading.cpu.value, reading.cpu.unit == 0 ? "J" : "W");
joular_close();
```

A full example program is in [example/c/main.c](example/c/main.c). Like the Ada one, it reads once per second until stopped with Ctrl+C, which closes the sources cleanly. It comes with a [Makefile](example/c/Makefile) that builds the shared library and the program.

To build it by hand instead, from the root of the repository, first compile the library:

```bash
gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
```

Then compile the C program:

```bash
gcc example/c/main.c -Iinclude -Llib/relocatable -lJoular_Core -Wl,-rpath,"$PWD/lib/relocatable" -o example/c/example_c
```

`-I` is the folder holding `joularcore.h`, `-L` and `-l` the library to link with, and `-rpath` the folder where the program looks for the library when it runs. Without `-rpath`, the program still compiles but stops on start with a "library not loaded" error, unless you set `LD_LIBRARY_PATH` yourself. Windows has no `-rpath`: put a copy of the DLL next to the program instead.

## Using from Python

From Python, the same interface through ctypes:

```python
import ctypes

class Measurement(ctypes.Structure):
    _fields_ = [("available", ctypes.c_int), ("value", ctypes.c_double), ("unit", ctypes.c_int)]

class Reading(ctypes.Structure):
    _fields_ = [("cpu", Measurement), ("gpu", Measurement)]

lib = ctypes.CDLL("lib/relocatable/libJoular_Core.so")
lib.joular_read.argtypes = [ctypes.POINTER(Reading)]
lib.joular_version.restype = ctypes.c_char_p

lib.joular_open(1, 1)   # measure the CPU and the GPU
r = Reading()
lib.joular_read(ctypes.byref(r))
if r.cpu.available:
    print("CPU:", r.cpu.value, "J" if r.cpu.unit == 0 else "W")
lib.joular_close()
```

A full example program is in [example/python/main.py](example/python/main.py). Like the C one, it reads once per second until stopped with Ctrl+C, which closes the sources cleanly. It comes with a [Makefile](example/python/Makefile) that builds the shared library. Note that it puts Python's Ctrl+C handler back after loading the library: the Ada runtime installs its own while it starts up, and without that line Ctrl+C is ignored.

Java (through FFM or JNA), Rust (through `libloading` or FFI declarations), and every other language with a C FFI work the same way.

## How to read the measurements

- Some hardware reports **energy**: the joules consumed since the previous reading (mainly for RAPL on Linux and Windows).
- Others report **power**: the watts being drawn when read (Raspberry Pi models, GPUs).
- A source that is not present, not supported, or not accessible is reported as **not available**, which will not prevent other sources from working (i.e., CPU not available but GPU is available, the library will continue working as this is not an error).
- A source that was available but stops answering reports a value of **zero**.
- Energy counters (for RAPL) wrap after a few minutes under load, so **read frequently** to not miss a wrap (at least once per minute). The library handles the wrap directly.
- The library current only reads the **PKG domain of the main CPU socket**, and the **first GPU** found.
- The library is **not thread safe**: call open, read and close from a single thread, as one monitoring loop is the intended use for the current version.

## Adding new hardware or a new OS

Each hardware component is one package with three functions: `Is_Accessible` (detect and open), `Get_Power` or `Get_Energy` (one reading), and `Close`. The monitors ([CPU_Monitor](src/joular_core-cpu_monitor.adb), [GPU_Monitor](src/joular_core-gpu_monitor.adb)) try each package in order and keep the first one that answers. To support new hardware, write such a package and add it to the monitor's detection. OS specific code is selected with preprocessor symbols (`PJ_LINUX`, `PJ_WINDOWS`, `PJ_MACOS`, `PJ_BSD`) set by [joularcore.gpr](joularcore.gpr).

## 📜 License

Joular Core is licensed under the GNU Lesser General Public License 3 license only (LGPL-3.0-only).

Copyright © 2026, Adel Noureddine.
All rights reserved. This program and the accompanying materials are made available under the terms of the [GNU Lesser General Public License v3.0 (LGPL-3.0-only)](https://www.gnu.org/licenses/lgpl-3.0.en.html) which accompanies this distribution.

Author: Prof. Adel Noureddine
