#!/usr/bin/env python3
#
# Copyright (c) 2026, Adel Noureddine.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the
# GNU Lesser General Public License v3.0 only (LGPL-3.0-only)
# which accompanies this distribution, and is available at:
# https://www.gnu.org/licenses/lgpl-3.0.en.html
#
# Author : Adel Noureddine
#

"""Prints the energy or power consumed by the CPU and the GPU, once per second, until stopped with Ctrl+C, using the C interface of Joular Core through ctypes.

Build the shared library first, from the root of the repository:

    gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable

Then run this program:

    python3 example/python/main.py

It takes an optional number of readings to take before stopping on its own:

    python3 example/python/main.py 10

Nothing has to be compiled here: ctypes calls the shared library directly.
The C declarations these classes mirror are in include/joularcore.h.
"""

import ctypes
import signal
import sys
import time
from pathlib import Path

# The root of the repository, holding the shared library built by gprbuild
ROOT = Path(__file__).resolve().parents[2]
LIBRARY_DIR = ROOT / "lib" / "relocatable"

# The two units a measurement can carry, as joularcore.h defines them
UNIT_JOULES = 0
UNIT_WATTS = 1


class Measurement(ctypes.Structure):
    """One measurement of one hardware source, matches struct joularcore_measurement."""

    _fields_ = [
        ("value", ctypes.c_double),   # energy or power value, see unit
        ("available", ctypes.c_int),  # 1 when the source was requested and read, 0 otherwise
        ("unit", ctypes.c_int),       # 0 when value is energy in joules, 1 when it is power in watts
    ]


class Reading(ctypes.Structure):
    """One reading of every hardware source, matches struct joularcore_reading."""

    _fields_ = [
        ("cpu", Measurement),
        ("gpu", Measurement),
    ]


def library_names():
    """The name the shared library takes on this OS."""
    if sys.platform == "win32":
        return ("libjoularcore.dll", "joularcore.dll")
    if sys.platform == "darwin":
        return ("libjoularcore.dylib",)
    return ("libjoularcore.so",)


def find_library():
    """The file holding the shared library, or a message on how to build it when there is none."""
    # Look next to this program first, as Windows has no rpath and wants a copy
    # of the DLL there, then in the folder gprbuild builds the library into
    for folder in (Path(__file__).resolve().parent, LIBRARY_DIR):
        for name in library_names():
            candidate = folder / name
            if candidate.exists():
                return candidate

    sys.exit(
        "Joular Core shared library not found in {}\n"
        "Build it first, from the root of the repository:\n"
        "    gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable".format(LIBRARY_DIR)
    )


def load_library():
    """Loads the shared library, and declares the types of its functions.

    ctypes assumes every function returns an int and takes anything, which would silently truncate the double values on the way back, so each one is declared.
    """
    library_file = find_library()

    try:
        library = ctypes.CDLL(str(library_file))
    except OSError as error:
        # On macOS the library does not carry the Ada runtime and looks for it in the folder of the compiler that built it
        # Only the first line: the loader follows it with every folder it looked into
        message = ["Joular Core shared library found, but could not be loaded:",
                   "    {}".format(str(error).splitlines()[0])]

        if sys.platform == "darwin":
            message.append("\nThe Ada runtime is no longer in the folder of the compiler that built the library, so rebuild it with the GNAT of this machine:\n"
                           "    gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable")

        sys.exit("\n".join(message))

    library.joularcore_open.argtypes = [ctypes.c_int, ctypes.c_int]
    library.joularcore_open.restype = None

    library.joularcore_read.argtypes = [ctypes.POINTER(Reading)]
    library.joularcore_read.restype = None

    library.joularcore_close.argtypes = []
    library.joularcore_close.restype = None

    library.joularcore_version.argtypes = []
    library.joularcore_version.restype = ctypes.c_char_p

    return library


def measurement_text(name, measurement):
    """One measurement with its unit, or n/a when the source has none.

    A source that is missing is not printed as 0, which would claim the device idles rather than say the reading could not be taken.
    """
    if not measurement.available:
        return "{} n/a".format(name)

    unit = "J" if measurement.unit == UNIT_JOULES else "W"
    return "{} {:.2f} {}".format(name, measurement.value, unit)


def wanted_readings(argv):
    """How many readings to take before stopping, or zero to run until Ctrl+C."""
    if len(argv) <= 1:
        return 0

    try:
        wanted = int(argv[1])
    except ValueError:
        wanted = -1

    if wanted < 0:
        sys.exit("usage: main.py [number of readings]")

    return wanted


def main():
    library = load_library()
    reading = Reading()
    wanted = wanted_readings(sys.argv)
    taken = 0

    # The Ada runtime in the library installs its own Ctrl+C handler on load, replacing Python's
    # Put Python's back so Ctrl+C raises KeyboardInterrupt
    signal.signal(signal.SIGINT, signal.default_int_handler)

    print("Joular Core", library.joularcore_version().decode())

    library.joularcore_open(1, 1)

    try:
        while True:
            time.sleep(1.0)

            library.joularcore_read(ctypes.byref(reading))

            # Flushed so the readings still come out one per second when piped
            print(measurement_text("CPU", reading.cpu),
                  measurement_text("GPU", reading.gpu),
                  sep=" | ", flush=True)

            taken += 1
            if wanted and taken >= wanted:
                break
    except KeyboardInterrupt:
        # Ctrl+C interrupts the sleep above; the sources are closed below
        print("\nStopping")
    finally:
        library.joularcore_close()


if __name__ == "__main__":
    main()
