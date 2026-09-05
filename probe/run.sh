#!/usr/bin/env bash
#
# T2.2 -- compile and link header_probe.cpp against a Mitsuba 3 build.
#
#   MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh
#
# Exits 0 only if the probe compiles, links, and runs. Anything else means
# the C++ path is in doubt; read specs/002-mitsuba-backend/research.md D3
# before writing shim code.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if [ -z "${MITSUBA_DIR:-}" ]; then
    echo "MITSUBA_DIR is unset. Point it at the Mitsuba 3 build directory." >&2
    exit 2
fi

if [ ! -d "$MITSUBA_DIR" ]; then
    echo "MITSUBA_DIR=$MITSUBA_DIR is not a directory." >&2
    exit 2
fi

# The build tree sits inside the source tree, so the source root is its
# parent. Both are needed: mitsuba/core/config.h is generated into the
# build tree, every other header ships in the source tree.
src="$(cd "$MITSUBA_DIR/.." && pwd)"

includes=(
    -I"$MITSUBA_DIR/include"
    -I"$src/include"
    -I"$src/ext/drjit/include"
    -I"$src/ext/drjit/ext/drjit-core/include"
    -I"$src/ext/drjit/ext/nanothread/include"
)

libdir="$MITSUBA_DIR/lib"
out="$(mktemp -d)/header_probe"

echo "== compiling and linking =="
set -x
c++ -std=c++20 "${includes[@]}" \
    "$here/header_probe.cpp" \
    -L"$libdir" -lmitsuba -ldrjit-core -lnanothread \
    -Wl,-rpath,"$libdir" \
    -o "$out"
set +x

echo "== running =="
"$out"

echo
echo "T2.2 PASS: Mitsuba headers compile, link, and run outside the build tree."
