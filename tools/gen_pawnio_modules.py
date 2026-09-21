#!/usr/bin/env python3
#
#  Copyright (c) 2026, Adel Noureddine.
#  All rights reserved. This program and the accompanying materials
#  are made available under the terms of the
#  GNU Lesser General Public License v3.0 only (LGPL-3.0-only)
#  which accompanies this distribution, and is available at:
#  https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Author : Adel Noureddine
#

"""Turn the PawnIO modules into the Ada package that carries them.

The PawnIO driver has no way of its own to read a model specific register: it runs modules, and every module is signed and checked by the driver, so they are taken as they are from the official release and cannot be rebuilt here.

Usage, from the root of the repository:

    python3 tools/gen_pawnio_modules.py > src/joular_core-pawnio_modules.ads

It reads the modules from tools/pawnio, whose contents come from:
https://github.com/namazso/PawnIO.Modules/releases/tag/0.2.11

The SHA-256 of each module is pinned below and checked before anything is written, so a module that was replaced, truncated or picked up from another
release is refused rather than carried into the library.
The driver checks the modules' signature of its own when it loads them, which is what actually keeps an unsigned module out.
The check here is what keeps the file committed to this repository the one that was reviewed.

    python3 tools/gen_pawnio_modules.py --check

checks the same digests and then compares the generated package against the one committed, without writing anything, and exits non zero if they differ.
That is what CI runs, so the modules, their digests and the committed package cannot drift apart unnoticed.
"""

import hashlib
import pathlib
import sys

RELEASE = "0.2.11"
UPSTREAM = "https://github.com/namazso/PawnIO.Modules"

#  The Ada name of each module, the file it is taken from, and the SHA-256 that file is expected to have
#  Intel and AMD each need the module written for them: the other one refuses to load, as every module checks the processor it runs on before accepting
MODULES = [
    ("Intel_MSR", "IntelMSR.bin",
     "d6ed85d65ab17a22f813ef98207d6d537155ee2ded5976a21cb48413c9b92e5f"),
    ("AMD_Family17", "AMDFamily17.bin",
     "dae74615761b78bdf064dfb3e136252ddcc6fc727d88f14738d0e5800d427a91"),
]

#  The package this script writes, relative to the root of the repository
GENERATED = "src/joular_core-pawnio_modules.ads"

BYTES_PER_LINE = 12


def read_modules(tools_dir):
    """Read every module and check it against its pinned digest.

    Gives back the list of (ada_name, file_name, blob, digest), or None after having said on standard error what is wrong with the ones on disk.
    """
    blobs = []

    for ada_name, file_name, expected in MODULES:
        path = tools_dir / "pawnio" / file_name

        if not path.is_file():
            sys.stderr.write(
                "missing %s\n"
                "Download release %s from %s/releases and unzip the modules "
                "into tools/pawnio\n" % (path, RELEASE, UPSTREAM)
            )
            return None

        blob = path.read_bytes()
        digest = hashlib.sha256(blob).hexdigest()

        if digest != expected:
            sys.stderr.write(
                "%s is not the module this repository carries\n"
                "  expected sha256 %s\n"
                "  found    sha256 %s\n"
                "Take it again from release %s at %s/releases, and if it is "
                "meant to be a newer release, update RELEASE and MODULES in "
                "this script along with it\n"
                % (path, expected, digest, RELEASE, UPSTREAM)
            )
            return None

        blobs.append((ada_name, file_name, blob, digest))

    return blobs


def render(blobs):
    """Build the whole Ada package as one string."""
    out = []

    out.append("""--
--  Copyright (c) 2026, Adel Noureddine.
--  All rights reserved. This program and the accompanying materials
--  are made available under the terms of the
--  GNU Lesser General Public License v3.0 only (LGPL-3.0-only)
--  which accompanies this distribution, and is available at:
--  https://www.gnu.org/licenses/lgpl-3.0.en.html
--
--  Author : Adel Noureddine
--
--  GENERATED FILE, DO NOT EDIT BY HAND
--  Regenerate it with: python3 tools/gen_pawnio_modules.py > src/joular_core-pawnio_modules.ads
--
--  The modules below are taken byte for byte from release %s of
--  %s
--  They are signed, and the PawnIO driver checks that signature before running
--  them, so they cannot be rebuilt, trimmed or edited here.
--
--  They are licensed under the GNU Lesser General Public License version 2.1
--  or later, copyright namazso and contributors. Their source is at the
--  address above, and a copy of the license is in tools/pawnio/COPYING
--
""" % (RELEASE, UPSTREAM))

    for ada_name, file_name, blob, digest in blobs:
        out.append("--  %-13s %-16s %6d bytes  sha256 %s\n"
                   % (ada_name, file_name, len(blob), digest))

    out.append("""--

#if PJ_WINDOWS then
with System.Storage_Elements; use System.Storage_Elements;
#end if;

-- The PawnIO modules that read the registers, one for each CPU vendor
-- They are given to the driver as they are, which checks their signature and
-- runs their main, and that main refuses a machine the module was not made for
private package Joular_Core.PawnIO_Modules is

#if PJ_WINDOWS then

""")

    for index, (ada_name, file_name, blob, digest) in enumerate(blobs):
        out.append("    -- %s\n" % file_name)
        out.append("    %s : aliased constant Storage_Array (1 .. %d) :=\n"
                   % (ada_name, len(blob)))
        out.append("       (\n")
        for start in range(0, len(blob), BYTES_PER_LINE):
            row = blob[start:start + BYTES_PER_LINE]
            last = start + BYTES_PER_LINE >= len(blob)
            out.append("        %s%s\n"
                       % (", ".join("16#%02X#" % value for value in row),
                          "" if last else ","))
        out.append("       );\n")
        if index + 1 < len(blobs):
            out.append("\n")

    out.append("""
#end if;

end Joular_Core.PawnIO_Modules;
""")

    return "".join(out)


def main(argv) -> int:
    checking = "--check" in argv[1:]
    unknown = [argument for argument in argv[1:] if argument != "--check"]

    if unknown:
        sys.stderr.write("usage: %s [--check]\n" % argv[0])
        return 2

    tools_dir = pathlib.Path(__file__).resolve().parent
    blobs = read_modules(tools_dir)

    if blobs is None:
        return 1

    rendered = render(blobs)

    if not checking:
        sys.stdout.write(rendered)
        return 0

    committed = tools_dir.parent / GENERATED

    if not committed.is_file():
        sys.stderr.write("missing %s\n" % committed)
        return 1

    if committed.read_bytes() != rendered.encode("utf-8"):
        sys.stderr.write(
            "%s is not what the modules in tools/pawnio produce\n"
            "Regenerate it with: python3 tools/gen_pawnio_modules.py > %s\n"
            % (GENERATED, GENERATED)
        )
        return 1

    sys.stdout.write("%s matches the modules in tools/pawnio\n" % GENERATED)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
