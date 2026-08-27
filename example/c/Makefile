# Builds the C example of Joular Core, on Linux and Windows
#
#   make          builds the shared library and the example
#   make run      builds it, then runs it (stop it with Ctrl+C)
#   make clean    removes what was built here

# The root of the repository, holding the header and the library
ROOT = ../..
LIB_DIR = $(ROOT)/lib/relocatable

CC = gcc
CFLAGS = -O2 -Wall -I$(ROOT)/include
LDFLAGS = -L$(LIB_DIR) -lJoular_Core

# Windows sets OS=Windows_NT, Linux and the others leave it unset
ifeq ($(OS),Windows_NT)

    PJ_OS = windows
    EXE = example_c.exe

    # Windows has no way to record where the library is, but looks for it next to the program, so put a copy there
    COPY_LIBRARY = cp $(LIB_DIR)/*.dll .

else

    PJ_OS = linux
    EXE = example_c

    # Linux records the folder of the library inside the program, so it is found when running
    LDFLAGS += -Wl,-rpath,$(abspath $(LIB_DIR))

    # Nothing to copy
    COPY_LIBRARY = true

    # On macOS only, build the macOS version of the library, and record the folder of the Ada runtime too, as the library does not carry it there
    ifeq ($(shell uname),Darwin)
        PJ_OS = macos
        LDFLAGS += -Wl,-rpath,$(shell gnatls -v | grep adalib | tr -d ' ')
    endif

endif

all: library $(EXE)

# Build the shared library of Joular Core, which is the one holding the C interface
library:
	gprbuild -P $(ROOT)/joularcore.gpr -XPJ_OS=$(PJ_OS) -XJOULARCORE_LIBRARY_TYPE=relocatable -p

$(EXE): main.c $(ROOT)/include/joularcore.h
	$(CC) $(CFLAGS) main.c $(LDFLAGS) -o $(EXE)
	$(COPY_LIBRARY)

run: all
	./$(EXE)

clean:
	rm -f example_c example_c.exe *.dll

# Build the library before the example, even when asked to run several jobs at once
.NOTPARALLEL:

.PHONY: all library run clean
