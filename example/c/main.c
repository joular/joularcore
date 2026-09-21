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
 * It takes an optional number of readings to take before stopping on its own, which is what makes a run scriptable:
 *   ./example_c 10
 *
 * Or by hand, against the relocatable (shared) library, from the root of the repository:
 *   gprbuild -P joularcore.gpr -XJOULARCORE_LIBRARY_TYPE=relocatable
 *   gcc example/c/main.c -Iinclude -Llib/relocatable -lJoular_Core -Wl,-rpath,"$PWD/lib/relocatable" -o example/c/example_c
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

/* Called when Ctrl+C is pressed
 * It only asks the loop to stop: the sources are closed by main, as printing and closing files are not safe to do from a signal handler */
static void on_ctrl_c(int signal_number)
{
    (void) signal_number;
    stop_asked = 1;
}

/* Prints one measurement with its unit, or n/a when the source has none */
static void print_measurement(const char *name, const joular_measurement *m)
{
    if (m->available)
        printf("%s %.2f %s", name, m->value, m->unit == 0 ? "J" : "W");
    else
        printf("%s n/a", name);
}

/* How many readings to take before stopping, or zero to run until Ctrl+C
 */
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
    joular_reading reading;
    long wanted = 0;
    long taken = 0;

    if (argc > 1 && !wanted_readings(argv[1], &wanted)) {
        fprintf(stderr, "usage: %s [number of readings]\n", argv[0]);
        return 1;
    }

    printf("Joular Core %s\n", joular_version());

    /* Stop cleanly on Ctrl+C, instead of being killed on the spot */
    signal(SIGINT, on_ctrl_c);

    /* Detect and open every supported hardware source (CPU and GPU) */
    joular_open(1, 1);

    while (!stop_asked) {
        sleep_one_second();

        /* Ctrl+C interrupts the sleep above, so don't print one last reading after it */
        if (stop_asked)
            break;

        /* Take one reading of all the hardware sources opened above */
        joular_read(&reading);

        print_measurement("CPU", &reading.cpu);
        printf(" | ");
        print_measurement("GPU", &reading.gpu);
        printf("\n");

        /* Only when a count was asked for, as zero means running until Ctrl+C */
        taken++;
        if (wanted > 0 && taken >= wanted)
            break;
    }

    /* Ctrl+C was pressed, so close the sources opened above */
    printf("Stopping\n");
    joular_close();
    return 0;
}
