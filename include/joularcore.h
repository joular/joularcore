/*
 * Copyright (c) 2026, Adel Noureddine.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the
 * GNU Lesser General Public License v3.0 only (LGPL-3.0-only)
 * which accompanies this distribution, and is available at:
 * https://www.gnu.org/licenses/lgpl-3.0.en.html
 *
 * Author : Adel Noureddine
 */

/*
 * C interface of Joular Core, a library measuring the energy or power consumption of hardware components (CPU and GPU)
 *
 * Use it with the relocatable (shared) build of the library (libJoular_Core.so on Linux, Joular_Core.dll on Windows, libJoular_Core.dylib on macOS), which starts itself up when loaded: no other initialization call is needed
 *
 * The library is not thread safe: call joular_open, joular_read and joular_close from a single thread
 *
 * Some hardware sources report energy consumed since the previous reading (unit 0, joules) and others report the power being drawn (unit 1, watts)
 * Energy counters wrap after a few minutes under load, so read at least once per minute to not miss a wrap (for RAPL)
 */

#ifndef JOULARCORE_H
#define JOULARCORE_H

#ifdef __cplusplus
extern "C" {
#endif

/* One measurement of one hardware source */
typedef struct joular_measurement {
    int    available;  /* 1 when the source was requested and read, 0 otherwise */
    double value;      /* energy or power value, see unit */
    int    unit;       /* 0 when value is energy in joules, 1 when it is power in watts */
} joular_measurement;

/* One reading of every hardware source */
typedef struct joular_reading {
    joular_measurement cpu;
    joular_measurement gpu;
} joular_reading;

/* Check the hardware sources asked for (nonzero = measure it) and open any needed files or drivers
 * Sources that are not present or not accessible are simply reported as not available by joular_read */
void joular_open(int cpu, int gpu);

/* Take one reading of every hardware source opened by joular_open and write it into *out
 * A source that could not be opened has available = 0
 * a source that stops answering reports a value of 0 */
void joular_read(joular_reading *out);

/* Close the files or drivers opened by joular_open */
void joular_close(void);

/* Return 1 when joular_open was called and not yet closed, 0 otherwise */
int joular_is_open(void);

/* Return the version of the library, owned by the library (do not free it) */
const char *joular_version(void);

#ifdef __cplusplus
}
#endif

#endif /* JOULARCORE_H */
