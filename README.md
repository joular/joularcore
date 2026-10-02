# <a href="https://www.noureddine.org/research/joular/"><img src="https://raw.githubusercontent.com/joular/.github/main/profile/joular.png" alt="Joular Project" width="64" /></a> Joular Core :zap:

[![License: LGPL v3](https://img.shields.io/badge/License-LGPLv3-blue)](https://www.gnu.org/licenses/lgpl-3.0) [![Ada](https://img.shields.io/badge/Made%20with-Ada-blue)](https://www.adaic.org)

![Joular Core Logo](joularcore.png)

Joular Core is an Ada library that measures the energy or power consumption of hardware components.
It detects automatically what the machine offers (which CPU, which GPU, and how to read them), and gives one simple interface: open, read, close.

It is written in Ada, and also provides a [C interface](include/joularcore.h) so it can be used from any language with a C FFI (C, C++, Java, Python, Rust, etc.).

## :satellite: Supported platforms

| Component | Hardware | OS | Method | Reports |
|---|---|---|---|---|
| CPU | Intel, AMD | Linux | RAPL through powercap sysfs | Energy (joules) |
| CPU | Intel, AMD | Windows | RAPL through the [Energy Meter Interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface) (nothing to install), or the RAPL MSR through [PawnIO](https://pawnio.eu) or [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver) | Energy (joules) |
| CPU | Apple Silicon, Intel Macs | macOS | powermetrics (installed with macOS) | Power (watts) |
| CPU | Raspberry Pi | Linux | Regression power models | Power (watts) |
| GPU | Nvidia cards | Linux, Windows, BSD | NVML (installed with the Nvidia driver) | Power (watts) |
| GPU | AMD cards | Linux | amdgpu hwmon sysfs | Power (watts) |
| GPU | AMD cards | Windows | ADLX (installed with the AMD driver) | Power (watts) |
| GPU | Apple Silicon | macOS | powermetrics (installed with macOS) | Power (watts) |

For Raspberry Pi, we support these models: 5B, 400, 4B, 3B+, 3B, 2B, 1B+, 1B, Zero W, and Asus Tinker Board.
On macOS, Apple Silicon Macs give their CPU and the GPU built in the same chip, both read from powermetrics, one reading each.
Intel Macs give the CPU only. On BSD, only Nvidia GPUs are implemented for now (CPU support is planned).

## Required privileges

Joular Core is a library, so the privileges below are needed for the *program using it*.

- **Linux CPU (RAPL)**: reading `energy_uj` needs elevated access (root or read permissions) on most kernels. Run your program with `sudo`, or give the powercap files read permission.
- **Windows CPU (RAPL)**: if using EMI interface, then there is no special privileges or driver needed. Otherwise, we need specific RAPL driver.
  - The [Energy Meter Interface](https://learn.microsoft.com/en-us/windows-hardware/drivers/powermeter/energy-meter-interface) is the one used by default and checked first, and needs **no installation and no elevated access**, and works only on Windows 11.
  - [PawnIO](https://pawnio.eu) is the main RAPL driver used (after EMI): it is maintained and properly signed, and its installer is all that is needed, as Joular Core carries the modules it loads. It needs elevated access, so run the program using the library with such access (i.e., from a terminal with administrative rights).
  - [Hubblo's RAPL driver](https://github.com/hubblo-org/windows-rapl-driver) still works and is used when PawnIO is not there. It does not require elevated access, but its development has paused and not actively maintained by their authors. The easiest way to install a signed version is through the [Scaphandre installer](https://github.com/hubblo-org/scaphandre/releases/download/v1.0.0/scaphandre_v1.0.0_installer.exe).
- **macOS CPU and GPU (powermetrics)**: `powermetrics` only runs as the superuser, so run your program with `sudo`. Without it, both sources are simply reported as not available.
- Raspberry Pi models, and GPU readings on Linux, Windows and BSD, need no special privileges.

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

The build produces a static library by default, and detects the OS on its own to compile the appropriate version: Linux, Windows, macOS, and BSD systems are each recognised from the target gprbuild reports.
`-XPJ_OS` overrides it when the version to build is not the one of the machine building it (e.g. `-XPJ_OS=windows`).

For other library types (shared, etc.), set `-XJOULARCORE_LIBRARY_TYPE`:

```bash
gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
```

`relocatable` builds the shared library (`libjoularcore.so` / `.dll` / `.dylib`) that carries the C interface, is stand-alone (it starts itself up when loaded), and on Linux and Windows is encapsulated (it carries the Ada runtime too, so it is one self-contained file). On macOS it cannot be encapsulated, so the Ada runtime stays a file of its own: the library records the folder of the runtime of the compiler that built it, and loads it from there with nothing to set (no `DYLD_LIBRARY_PATH`, so it also works under `sudo` and from `/usr/bin/java` or the system's Python).

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

It takes two optional arguments, in any order. On Windows, `emi`, `pawnio` or `hubblo` indicates how the RAPL counter is to be read (rather than trying them in turn), and a number of readings to do before stopping the program. A summary is printed at the end.

```bash
./example/example_joular_core emi 10
```

With Alire, add the library to your project with `alr with joularcore`.

## Using from C (and any other language)

The C declarations are in [include/joularcore.h](include/joularcore.h). Build the relocatable (shared) library, then:

```c
#include "joularcore.h"

joularcore_reading reading;

joularcore_open(1, 1);   /* measure the CPU and the GPU */
joularcore_read(&reading);
if (reading.cpu.available)
    printf("CPU: %f %s\n", reading.cpu.value, reading.cpu.unit == 0 ? "J" : "W");
joularcore_close();
```

A full example program is in [example/c/main.c](example/c/main.c). Like the Ada one, it reads once per second until stopped with Ctrl+C, which closes the sources cleanly. It comes with a [Makefile](example/c/Makefile) that builds the shared library and the program.

To build it by hand instead, from the root of the repository, first compile the library:

```bash
gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
```

Then compile the C program:

```bash
gcc example/c/main.c -Iinclude -Llib/relocatable -ljoularcore -Wl,-rpath,"$PWD/lib/relocatable" -o example/c/example_c
```

`-I` is the folder holding `joularcore.h`, `-L` and `-l` the library to link with, and `-rpath` the folder where the program looks for the library when it runs. Without `-rpath`, the program still compiles but stops on start with a "library not loaded" error, unless you set `LD_LIBRARY_PATH` yourself. Windows has no `-rpath`: put a copy of the DLL next to the program instead.

## Using from Python

From Python, the same interface through ctypes:

```python
import ctypes

class Measurement(ctypes.Structure):
    _fields_ = [("value", ctypes.c_double), ("available", ctypes.c_int), ("unit", ctypes.c_int)]

class Reading(ctypes.Structure):
    _fields_ = [("cpu", Measurement), ("gpu", Measurement)]

lib = ctypes.CDLL("lib/relocatable/libjoularcore.so")
lib.joularcore_read.argtypes = [ctypes.POINTER(Reading)]
lib.joularcore_version.restype = ctypes.c_char_p

lib.joularcore_open(1, 1)   # measure the CPU and the GPU
r = Reading()
lib.joularcore_read(ctypes.byref(r))
if r.cpu.available:
    print("CPU:", r.cpu.value, "J" if r.cpu.unit == 0 else "W")
lib.joularcore_close()
```

A full example program is in [example/python/main.py](example/python/main.py). Like the C one, it reads once per second until stopped with Ctrl+C, which closes the sources cleanly. It comes with a [Makefile](example/python/Makefile) that builds the shared library.

Java (through FFM or JNA), Rust (through `libloading` or FFI declarations), and every other language with a C FFI work the same way.

## How to read the measurements

- Some hardware reports **energy**: the joules consumed since the previous reading (mainly for RAPL on Linux and Windows).
- Others report **power**: the watts being drawn when read (Raspberry Pi models, GPUs).
- A source that is not present, not supported, or not accessible is reported as **not available**, which will not prevent other sources from working (i.e., CPU not available but GPU is available, the library will continue working as this is not an error).
- A source that was available but stops answering reports a value of **zero**.
- On macOS, the value is the **average power since the previous reading**: we ask powermetrics for a sample at each reading. Opening the sources waits for its first sample. If powermetrics stops answering, its sources read zero, and it is started again around ten seconds later.
- The library is **not thread safe**: call open, read and close from a single thread, as one monitoring loop is the intended use for the current version.

### What each source actually measures

| Source | What the number covers |
|---|---|
| RAPL on Linux | **One** package of powercap, the first one whose name begins with `package` |
| RAPL on Windows | The package domain of the first socket |
| Raspberry Pi | A model-based estimate: a regression on CPU load, evaluated over the interval between two readings. It is not a reading of the board's actual draw |
| Nvidia (NVML) | What the card reports for the whole GPU board. Depending on the architecture and driver, this is an average over about a second rather than an instant value. |
| AMD on Linux (hwmon) | Whole GPU board power, not the graphics processor alone. On an APU that includes the CPU cores, so work done on the CPU raises what this library calls the GPU, and adding CPU and GPU together counts some of it twice. |
| AMD on Windows (ADLX) | Whole GPU board power where the card offers it, and the graphics processor alone where it does not. Which of the two is choosen when the card is opened and does not change while the program runs, so a series of measurements always means one thing |
| macOS | Apple Silicon: the CPU and the GPU parts of the same chip, from the same sample, as powermetrics estimates them. Intel Macs: the whole chip (cores, integrated GPU and system agent), like the RAPL package on Linux and Windows |

RAPL counters wrap when they fill, and the library corrects that. The correction only works if less energy was used between two readings than the counter holds. How long the counter takes to fill depends on the energy unit of the processor.
The Energy Meter Interface (EMI) on Windows corrects for the wrap by itself, so Joular Core doesn't need to do the correction.

## Adding new hardware or a new OS

Each hardware component is one package with three functions: `Open` (detect and open, returning `False` when the hardware is not there or cannot be read), `Get_Power` or `Get_Energy` (one reading, in watts or joules), and `Close`.

The code shared by every OS is in [src](src), and the code of each OS is in its own folder, picked by [joularcore.gpr](joularcore.gpr) from `PJ_OS`: [src/linux](src/linux), [src/windows](src/windows), [src/macos](src/macos) and [src/bsd](src/bsd), with [src/posix](src/posix) holding what Linux, macOS and the BSDs do the same way (loading a shared library). Each OS folder has its own body of the two monitors, `CPU_Monitor` and `GPU_Monitor` (for example [src/linux/joular_core-cpu_monitor.adb](src/linux/joular_core-cpu_monitor.adb)), which lists the packages that can read that hardware on that OS, tries them in order and keeps the first one that answers. To support new hardware, write such a package in the folder of the OS it runs on (or in `src` if it is portable, like [NVML](src/joular_core-gpu_nvidia_nvml.adb)), and add it to the monitor of that OS. To support a new OS, add its folder with its two monitors, and add it to `PJ_OS` in the project file.

Windows RAPL splits this further, as the same counter is reached in several ways. [RAPL_Windows](src/windows/joular_core-rapl_windows.adb) tries each way in order and keeps the first that answers: [RAPL_EMI_Windows](src/windows/joular_core-rapl_emi_windows.adb), which read RAPL from EMI interface, then [RAPL_MSR_Windows](src/windows/joular_core-rapl_msr_windows.adb), which reads the MSR registers with a driver. That second one keeps the vendor detection and the counter abstract, and hands the reading of a single register to one of two interchangeable packages, [MSR_PawnIO](src/windows/joular_core-msr_pawnio.adb) and [MSR_Hubblo](src/windows/joular_core-msr_hubblo.adb). All of them share the small set of Win32 bindings in [Win32](src/windows/joular_core-win32.ads). Supporting another driver means writing another such package with `Open`, `Read` and `Close`, adding it to `Driver_Kind` in `RAPL_MSR_Windows`, and to the list tried in `RAPL_Windows.Open`.

The RAPL counters of Linux and Windows wrap the same way, so the energy between two readings is shared in [Energy_Counters](src/joular_core-energy_counters.adb).

## Third party components

Joular Core carries two [PawnIO modules](https://github.com/namazso/PawnIO.Modules), `IntelMSR.bin` and `AMDFamily17.bin`, taken byte for byte from release 0.2.11. The PawnIO driver reads no register on its own: it runs modules, and checks their signature before doing so, so they are shipped as they are and cannot be rebuilt here.

They are licensed under the GNU Lesser General Public License version 2.1 or later, copyright namazso and contributors. A copy of that license is in [tools/pawnio/COPYING](tools/pawnio/COPYING), next to the modules themselves.

They are turned into [joular_core-pawnio_modules.ads](src/windows/joular_core-pawnio_modules.ads) by [tools/gen_pawnio_modules.py](tools/gen_pawnio_modules.py), which is also how that file is regenerated when a newer release is taken:

```bash
python3 tools/gen_pawnio_modules.py
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
