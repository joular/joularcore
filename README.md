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
| CPU | Intel, AMD | Windows | RAPL through the [Energy Meter Interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface) (nothing to install), or the RAPL MSR through [PawnIO](https://pawnio.eu) or [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver) | Energy (joules) |
| CPU | Apple Silicon | macOS | powermetrics (installed with macOS) | Power (watts) |
| CPU | Raspberry Pi | Linux | Regression power models | Power (watts) |
| GPU | Nvidia cards | Linux, Windows | NVML (installed with the Nvidia driver) | Power (watts) |
| GPU | AMD cards | Linux | amdgpu hwmon sysfs | Power (watts) |
| GPU | AMD cards | Windows | ADLX (installed with the AMD driver) | Power (watts) |
| GPU | Apple Silicon | macOS | powermetrics (installed with macOS) | Power (watts) |

For Raspberry Pi, we support these models: 5B, 400, 4B, 3B+, 3B, 2B, 1B+, 1B, Zero W, and Asus Tinker Board.
On macOS, only Apple Silicon Macs are supported: their CPU and the GPU built in the same chip are both read from powermetrics, one reading each.
Mac Intel are not supported. BSD support is planned and will come in a future version.

## Required privileges

- **Linux CPU (RAPL)**: reading `energy_uj` needs elevated access (root or read permissions) on most kernels. Run your program with `sudo`, or give the powercap files read permission.
- **Windows CPU (RAPL)**: if using EMI interface, then there is no special privileges or driver needed. Otherwise, we need specific RAPL driver.
  - The [Energy Meter Interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface) is the one used by default and checked first, and needs **no install and no elevated access**. Windows 11 publishes the RAPL domains of the processor on it, so it works out of the box on those machines. Windows 10 only publishes a meter when the machine carries one of its own, and such a meter rarely measures the processor package, in which case Joular Core turns it down and uses the RAPL drivers below rather than reporting something else as the CPU.
  - [PawnIO](https://pawnio.eu) is the main RAPL driver used (after EMI): it is maintained and properly signed, and its installer is all that is needed, as Joular Core carries the modules it loads. This is the one used when both drivers are installed. It needs elevated access, so run the program using the library with such access (i.e., from a terminal with administrative rights).
  - [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver) still works and is used when PawnIO is not there. It does not require elevated access, but its development has paused and not actively maintained by their authors. The easiest way to install a signed version is through the [Scaphandre installer](https://github.com/hubblo-org/scaphandre/releases/download/v1.0.0/scaphandre_v1.0.0_installer.exe).
- **macOS CPU and GPU (powermetrics)**: `powermetrics` only runs as the superuser, so run your program with `sudo`. Without it, both sources are simply reported as not available.
- Raspberry Pi models, and GPU readings on Linux and Windows, need no special privileges.

### Choosing how the Windows RAPL counter is read

Joular Core tries the Energy Meter Interface first, then PawnIO, then Hubblo's driver, keeping the first that answers. Nothing has to be configured for that.
All three end up on the same package counter of the processor, so they report the same energy. Setting `JOULARCORE_WINDOWS_RAPL` picks one instead of trying them in turn.

```
set JOULARCORE_WINDOWS_RAPL=emi
set JOULARCORE_WINDOWS_RAPL=pawnio
set JOULARCORE_WINDOWS_RAPL=hubblo
```

Any other value, including not setting it at all, tries the Energy Meter Interface first, then PawnIO, then Hubblo.

## Building

With [Alire](https://alire.ada.dev):

```bash
alr build
```

Or directly with GNAT:

```bash
gprbuild -P joularcore.gpr
```

The build produces a static library by default, and detects the OS on its own to compile the appropriate version: Linux, Windows, macOS and the BSDs are each recognised from the target gprbuild reports, so nothing has to be passed. `-XPJ_OS` still overrides it when the version to build is not the one of the machine building it (ex. `-XPJ_OS=windows`). Alire sets it too.

For other library types (shared, etc.), set `-XJOULARCORE_LIBRARY_TYPE`:

```bash
gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
```

`relocatable` builds the shared library (`libJoular_Core.so` / `.dll` / `.dylib`) that carries the C interface, is stand-alone (it starts itself up when loaded), and on Linux and Windows is encapsulated (it carries the Ada runtime too, so it is one self-contained file). On macOS it cannot be encapsulated, so the Ada runtime stays a file of its own that has to be found when the library is loaded: the Makefiles of the examples take care of it, as shown below.

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

Reading the CPU needs root on Linux (the RAPL counter in `/sys/class/powercap/intel-rapl` is only readable by root on most distributions) and on macOS (`powermetrics` only answers root), so run it with `sudo` there. On Windows it depends on the reader: the Energy Meter Interface and Hubblo's driver read from any terminal, PawnIO only from an elevated one. When the CPU does not open, the example says what applies to the OS it was built for.

It takes two optional arguments, in any order. On Windows, `emi`, `pawnio` or `hubblo` indicates how the RAPL counter is to be read (rather than trying them in turn), and a number stops the program after that many readings instead of running until Ctrl+C. A summary is printed at the end.

```bash
./example/example_joular_core emi 10
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

`-I` is the folder holding `joularcore.h`, `-L` and `-l` the library to link with, and `-rpath` the folder where the program looks for the library when it runs. Without `-rpath`, the program still compiles but stops on start with a "library not loaded" error, unless you set `LD_LIBRARY_PATH` yourself. Windows has no `-rpath`: put a copy of the DLL next to the program instead. On macOS, add a second `-rpath` for the folder of the Ada runtime (`gnatls -v | grep adalib`), which the library does not carry there.

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

On macOS, the loader is told where the Ada runtime is through `DYLD_LIBRARY_PATH`, which `sudo` drops for the Python shipped with the system. Reading the CPU and the GPU there needs both, so run it as root with a Python of your own (Homebrew's, for example), or with `sudo env DYLD_LIBRARY_PATH=...`.

Java (through FFM or JNA), Rust (through `libloading` or FFI declarations), and every other language with a C FFI work the same way.

## How to read the measurements

- Some hardware reports **energy**: the joules consumed since the previous reading (mainly for RAPL on Linux and Windows).
- Others report **power**: the watts being drawn when read (Raspberry Pi models, GPUs).
- A source that is not present, not supported, or not accessible is reported as **not available**, which will not prevent other sources from working (i.e., CPU not available but GPU is available, the library will continue working as this is not an error).
- A source that was available but stops answering reports a value of **zero**.
- Energy counters (for RAPL) wrap after a few minutes under load, so **read frequently** to not miss a wrap (at least once per minute). The library handles the wrap directly. The exception is the Energy Meter Interface (EMI) on Windows, where Windows hands over a counter it has already added up across those wraps.
- On macOS, the value is the **average power over the last second**, the interval powermetrics samples at. Opening the sources waits for that first sample, so it takes about a second there.
- The library current only reads the **PKG domain of the main CPU socket**, and the **first GPU** found.
- The library is **not thread safe**: call open, read and close from a single thread, as one monitoring loop is the intended use for the current version.

## Adding new hardware or a new OS

Each hardware component is one package with three functions: `Is_Accessible` (detect and open), `Get_Power` or `Get_Energy` (one reading), and `Close`. The monitors ([CPU_Monitor](src/joular_core-cpu_monitor.adb), [GPU_Monitor](src/joular_core-gpu_monitor.adb)) try each package in order and keep the first one that answers. To support new hardware, write such a package and add it to the monitor's detection. OS specific code is selected with preprocessor symbols (`PJ_LINUX`, `PJ_WINDOWS`, `PJ_MACOS`, `PJ_BSD`) set by [joularcore.gpr](joularcore.gpr).

Windows RAPL splits this further, as the same counter is reached in several ways. [RAPL_Windows](src/joular_core-rapl_windows.adb) tries each way in order and keeps the first that answers: [RAPL_EMI_Windows](src/joular_core-rapl_emi_windows.adb), which read RAPL from EMI interface, then [RAPL_MSR_Windows](src/joular_core-rapl_msr_windows.adb), which reads the MSR registers with a driver. That second one keeps the vendor detection and the counter abstract, and hands the reading of a single register to one of two interchangeable packages, [MSR_PawnIO](src/joular_core-msr_pawnio.adb) and [MSR_Hubblo](src/joular_core-msr_hubblo.adb). All of them share the small set of Win32 bindings in [Win32](src/joular_core-win32.ads). Supporting another driver means writing another such package with `Open`, `Read` and `Close`, and adding it to the list tried in `Open`.

## Third party components

Joular Core carries two [PawnIO modules](https://github.com/namazso/PawnIO.Modules), `IntelMSR.bin` and `AMDFamily17.bin`, taken byte for byte from release 0.2.11. The PawnIO driver reads no register on its own: it runs modules, and checks their signature before doing so, so they are shipped as they are and cannot be rebuilt here.

They are licensed under the GNU Lesser General Public License version 2.1 or later, copyright namazso and contributors. A copy of that license is in [tools/pawnio/COPYING](tools/pawnio/COPYING), next to the modules themselves.

They are turned into [joular_core-pawnio_modules.ads](src/joular_core-pawnio_modules.ads) by [tools/gen_pawnio_modules.py](tools/gen_pawnio_modules.py), which is also how that file is regenerated when a newer release is taken:

```bash
python3 tools/gen_pawnio_modules.py > src/joular_core-pawnio_modules.ads
```

The SHA-256 of each module is pinned in that script, which refuses to write anything when a module on disk is not the one it expects, so taking a newer release means updating those digests along with the files. Running it with `--check` writes nothing and only reports whether the modules, their digests and the committed package still agree, which is what CI runs on every push:

```bash
python3 tools/gen_pawnio_modules.py --check
```

## 📜 License

Joular Core is licensed under the GNU Lesser General Public License 3 license only (LGPL-3.0-only).

Copyright © 2026, Adel Noureddine.
All rights reserved. This program and the accompanying materials are made available under the terms of the [GNU Lesser General Public License v3.0 (LGPL-3.0-only)](https://www.gnu.org/licenses/lgpl-3.0.en.html) which accompanies this distribution.

Author: Prof. Adel Noureddine
