#!/usr/bin/env bash
#
# T2.2 -- compile and link header_probe.cpp against a Mitsuba 3 build.
#
#   MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh
#
# Exits 0 only if the probe compiles, links, and runs. Anything else means
# the C++ path needs the shim moved inside Mitsuba's own CMake tree; read
# specs/002-mitsuba-backend/research.md D3 before changing course. It does
# not mean leaving C++.
#
# The include set comes from Mitsuba's own compile_commands.json rather
# than a hand-maintained list. Mitsuba's public headers reach into a dozen
# bundled third-party trees (tinyformat, nanobind's intrusive refcounting,
# drjit, robin_map, ...), and that set is a property of the Mitsuba commit,
# not something to rediscover one -fatal-error at a time. `mitsuba-sys`
# will need the same list for bindgen at T1.2, so deriving it is the
# reusable answer.

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

# Mitsuba emits its shared libraries into the build root, not a lib/
# subdirectory. Accept either, so this keeps working if that changes.
if [ -e "$MITSUBA_DIR/libmitsuba.so" ]; then
    libdir="$MITSUBA_DIR"
elif [ -e "$MITSUBA_DIR/lib/libmitsuba.so" ]; then
    libdir="$MITSUBA_DIR/lib"
else
    echo "No libmitsuba.so under $MITSUBA_DIR. Build Mitsuba first." >&2
    exit 2
fi

db="$MITSUBA_DIR/compile_commands.json"
if [ ! -e "$db" ]; then
    echo "== generating compile_commands.json =="
    cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$MITSUBA_DIR" >/dev/null
fi

# Take the compiler, the language standard and the include flags from a
# core translation unit: whatever libmitsuba itself compiles against is
# exactly what its public headers need. The standard matters as much as
# the includes -- Mitsuba builds as gnu++17, and compiling a consumer at a
# different level risks ODR and ABI mismatch against the .so being linked.
mapfile -t flags < <(python3 - "$db" <<'PY'
import json, shlex, sys

with open(sys.argv[1]) as fh:
    db = json.load(fh)

units = [e for e in db if "/src/core/" in e["file"] and e["file"].endswith(".cpp")]
if not units:
    sys.exit("no src/core translation unit in compile_commands.json")

argv = shlex.split(units[0]["command"])
print(argv[0])

seen = set()
for tok in argv[1:]:
    if (tok.startswith("-I") or tok.startswith("-std=")) and tok not in seen:
        seen.add(tok)
        print(tok)
PY
)

if [ "${#flags[@]}" -lt 2 ]; then
    echo "Derived no usable flags from $db." >&2
    exit 2
fi

cxx="${flags[0]}"
compile_flags=("${flags[@]:1}")

echo "== compiler: $cxx =="
echo "== ${#compile_flags[@]} flags derived from compile_commands.json =="

out="$(mktemp -d)/header_probe"

echo "== compiling and linking =="
"$cxx" "${compile_flags[@]}" \
    "$here/header_probe.cpp" \
    -L"$libdir" -lmitsuba -ldrjit-core -lnanothread \
    -Wl,-rpath,"$libdir" \
    -o "$out"

echo "== running =="
"$out"

echo
echo "T2.2 PASS: Mitsuba headers compile, link, and run outside the build tree."
