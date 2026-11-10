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
 * C interface of Joular Core, a library measuring the energy or power consumption of the CPU and the GPU
 *
 * Use it with the relocatable (shared) build of the library (libjoularcore.so on Linux, libjoularcore.dll on Windows, libjoularcore.dylib on macOS), which starts itself up when loaded: no other initialization call is needed
 *
 * The library is not thread safe: call joularcore_open, joularcore_read and joularcore_close from a single thread
 *
 * Some hardware sources report energy consumed since the previous reading (unit 0, joules) and others report the power being drawn (unit 1, watts)
 * Energy counters (RAPL) wrap after a few minutes under load, so read at least once per minute to not miss a wrap
 */

#ifndef JOULARCORE_H
#define JOULARCORE_H

#ifdef __cplusplus
extern "C" {
#endif

/* One measurement of one hardware source */
typedef struct joularcore_measurement {
    double value;      /* energy or power value, see unit */
    int    available;  /* 1 when the source was requested and opened, 0 otherwise */
    int    unit;       /* 0 when value is energy in joules, 1 when it is power in watts */
} joularcore_measurement;

/* One reading of every hardware source */
typedef struct joularcore_reading {
    joularcore_measurement cpu;
    joularcore_measurement gpu;
} joularcore_reading;

/* Detect the hardware sources asked for (nonzero = measure it) and open any needed files or drivers
 * A source that is not there, or cannot be read, is simply reported as not available by joularcore_read */
void joularcore_open(int cpu, int gpu);

/* Take one reading of every hardware source opened by joularcore_open and write it into *out
 * A source that could not be opened has available = 0
 * A source that stops answering reports a value of 0 */
void joularcore_read(joularcore_reading *out);

/* Close the files or drivers opened by joularcore_open */
void joularcore_close(void);

/* Return the version of the library, owned by the library (do not free it) */
const char *joularcore_version(void);

#ifdef __cplusplus
}
#endif

#endif /* JOULARCORE_H */
