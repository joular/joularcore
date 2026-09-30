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
 * Prints the energy or power consumed by the CPU and the GPU, once per second, until stopped with Ctrl+C, using the C interface of Joular Core
 *
 * Build it with the Makefile next to this file, which builds the shared library of Joular Core as well:
 *   make
 *   ./example_c
 *
 * It takes an optional number of readings to take before stopping on its own, for scripted runs:
 *   ./example_c 10
 *
 * Or by hand, against the relocatable (shared) library, from the root of the repository:
 *   gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
 *   gcc example/c/main.c -Iinclude -Llib/relocatable -ljoularcore -Wl,-rpath,"$PWD/lib/relocatable" -o example/c/example_c
 *
 * -I is the folder holding joularcore.h, -L and -l the library to link with, and -rpath the folder where the program looks for the library when it runs
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#define sleep_one_second() Sleep(1000)
#else
#include <unistd.h>
#define sleep_one_second() sleep(1)
#endif

#include "joularcore.h"

/* Set to 1 when Ctrl+C is pressed, so the reading loop stops
 * volatile sig_atomic_t is the only type a signal handler may safely write */
static volatile sig_atomic_t stop_asked = 0;

/* Only sets the flag: printing and closing files are not safe from a signal handler */
static void on_ctrl_c(int signal_number)
{
    (void) signal_number;
    stop_asked = 1;
}

/* Prints one measurement with its unit, or n/a when the source has none */
static void print_measurement(const char *name, const joularcore_measurement *m)
{
    if (m->available)
        printf("%s %.2f %s", name, m->value, m->unit == 0 ? "J" : "W");
    else
        printf("%s n/a", name);
}

/* Reads how many readings to take before stopping (zero runs until Ctrl+C) into *wanted
 * Returns 0 when text is not a whole number of zero or more, 1 otherwise */
static int wanted_readings(const char *text, long *wanted)
{
    char *end = NULL;

    errno = 0;
    *wanted = strtol(text, &end, 10);

    if (end == text || *end != '\0' || errno == ERANGE || *wanted < 0)
        return 0;

    return 1;
}

int main(int argc, char **argv)
{
    joularcore_reading reading;
    long wanted = 0;
    long taken = 0;

    if (argc > 1 && !wanted_readings(argv[1], &wanted)) {
        fprintf(stderr, "usage: %s [number of readings]\n", argv[0]);
        return 1;
    }

    printf("Joular Core %s\n", joularcore_version());

    signal(SIGINT, on_ctrl_c);

    joularcore_open(1, 1);

    while (!stop_asked) {
        sleep_one_second();

        /* Ctrl+C interrupts the sleep above, so don't print one last reading after it */
        if (stop_asked)
            break;

        joularcore_read(&reading);

        print_measurement("CPU", &reading.cpu);
        printf(" | ");
        print_measurement("GPU", &reading.gpu);
        printf("\n");

        taken++;
        if (wanted > 0 && taken >= wanted)
            break;
    }

    printf("Stopping\n");
    joularcore_close();
    return 0;
}
