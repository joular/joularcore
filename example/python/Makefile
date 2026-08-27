# Builds the shared library the Python example of Joular Core needs, on Linux and Windows
#
#   make          builds the shared library
#   make run      builds it, then runs the example (stop it with Ctrl+C)
#   make clean    removes what was built here
#
# The example itself is not compiled: ctypes calls the shared library directly

# The root of the repository, holding the library
ROOT = ../..
LIB_DIR = $(ROOT)/lib/relocatable

# Set when the library has to be told where the Ada runtime is, see below
RUN_ENV =

# Windows sets OS=Windows_NT, Linux and the others leave it unset
ifeq ($(OS),Windows_NT)

    PJ_OS = windows
    PYTHON = python

    # Windows has no way to record where the library is, but looks for it next to the program, so put a copy there
    COPY_LIBRARY = cp $(LIB_DIR)/*.dll .

else

    PJ_OS = linux
    PYTHON = python3

    # Linux records the folder of the Ada runtime inside the library, so nothing to copy or to set
    COPY_LIBRARY = true

    # On macOS only, build the macOS version of the library, and point the loader at the Ada runtime, as the library does not carry it there
    ifeq ($(shell uname),Darwin)
        PJ_OS = macos
        RUN_ENV = DYLD_LIBRARY_PATH=$(shell gnatls -v | grep adalib | tr -d ' ')
    endif

endif

all: library

# Build the shared library of Joular Core, which is the one holding the C interface ctypes calls
library:
	gprbuild -P $(ROOT)/joularcore.gpr -XPJ_OS=$(PJ_OS) -XJOULARCORE_LIBRARY_TYPE=relocatable -p
	$(COPY_LIBRARY)

run: all
	$(RUN_ENV) $(PYTHON) main.py

clean:
	rm -f *.dll
	rm -rf __pycache__

.PHONY: all library run clean
