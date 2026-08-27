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
    """One measurement of one hardware source, matches struct joular_measurement."""

    _fields_ = [
        ("available", ctypes.c_int),  # 1 when the source was requested and read, 0 otherwise
        ("value", ctypes.c_double),   # energy or power value, see unit
        ("unit", ctypes.c_int),       # 0 when value is energy in joules, 1 when it is power in watts
    ]


class Reading(ctypes.Structure):
    """One reading of every hardware source, matches struct joular_reading."""

    _fields_ = [
        ("cpu", Measurement),
        ("gpu", Measurement),
    ]


def library_names():
    """The name the shared library takes on this OS."""
    if sys.platform == "win32":
        return ("libJoular_Core.dll", "Joular_Core.dll")
    if sys.platform == "darwin":
        return ("libJoular_Core.dylib",)
    return ("libJoular_Core.so",)


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
        # The library is there, but something it needs is not: on macOS that is the Ada runtime, which the library carries on Linux and Windows but not there, so it has to be found when loading
        # Only the first line, which names what is missing: the loader follows it with every folder it looked into, which is pages long
        message = ["Joular Core shared library found, but could not be loaded:",
                   "    {}".format(str(error).splitlines()[0])]

        if sys.platform == "darwin":
            message.append("\nRun it with 'make run' here, which sets the folder of the Ada runtime, or set it yourself:\n"
                           "    DYLD_LIBRARY_PATH=$(gnatls -v | grep adalib | tr -d ' ') python3 main.py")

        sys.exit("\n".join(message))

    library.joular_open.argtypes = [ctypes.c_int, ctypes.c_int]
    library.joular_open.restype = None

    library.joular_read.argtypes = [ctypes.POINTER(Reading)]
    library.joular_read.restype = None

    library.joular_close.argtypes = []
    library.joular_close.restype = None

    library.joular_is_open.argtypes = []
    library.joular_is_open.restype = ctypes.c_int

    library.joular_version.argtypes = []
    library.joular_version.restype = ctypes.c_char_p

    return library


def measurement_text(name, measurement):
    """One measurement with its unit, or n/a when the source has none.

    A source that is missing is not printed as 0, which would claim the device idles rather than say the reading could not be taken.
    """
    if not measurement.available:
        return "{} n/a".format(name)

    unit = "J" if measurement.unit == UNIT_JOULES else "W"
    return "{} {:.2f} {}".format(name, measurement.value, unit)


def main():
    library = load_library()
    reading = Reading()

    # The Ada runtime inside the shared library installs its own Ctrl+C handler while it starts up, which takes the place of the one Python installed before it
    # Putting Python's back here, after the library is loaded, is what makes Ctrl+C raise KeyboardInterrupt and stop the loop below
    signal.signal(signal.SIGINT, signal.default_int_handler)

    print("Joular Core", library.joular_version().decode())

    # Detect and open every supported hardware source (CPU and GPU)
    library.joular_open(1, 1)

    try:
        while True:
            time.sleep(1.0)

            # Take one reading of all the hardware sources opened above
            library.joular_read(ctypes.byref(reading))

            # flush so the readings still come out one per second when the output is piped into another program or into a file
            print(measurement_text("CPU", reading.cpu),
                  measurement_text("GPU", reading.gpu),
                  sep=" | ", flush=True)
    except KeyboardInterrupt:
        # Ctrl+C interrupts the sleep above, so the loop stops here instead of being killed on the spot, and the sources are closed below
        print("\nStopping")
    finally:
        # Close the sources whatever stopped the loop, so the files and drivers the library opened are released
        library.joular_close()


if __name__ == "__main__":
    main()
