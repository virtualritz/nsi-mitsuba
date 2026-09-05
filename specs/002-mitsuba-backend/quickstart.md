# Quickstart: Mitsuba 3 Backend

## Prerequisites

- A host that can build Mitsuba 3. See `plan.md`.
- Mitsuba built with the `llvm_ad_rgb` variant.
- `libclang` for `bindgen`.

## Build

```bash
cd ~/code/crates/nsi-mitsuba
export MITSUBA_DIR=/path/to/mitsuba3/build
cargo build -p nsi-mitsuba
```

## Verification Commands

```bash
cargo test -p mitsuba-sys          # shim.md
cargo test -p nsi-mitsuba          # flush.md
```

None of these run yet; every contract row is `Open`.

## The First Thing To Run

Before writing shim code, prove the headers work:

```bash
cat > /tmp/probe.cpp <<'CPP'
#include <mitsuba/render/scene.h>
#include <mitsuba/core/properties.h>
int main() { mitsuba::Properties props("perspective"); return 0; }
CPP
# compile and link against the Mitsuba build
```

If this does not link, stop and read `research.md` D3. The C++ path is
not viable and `pyo3` over nanobind is the alternative.

## Manual QA Path

Render the `001` roundtrip fixture scene and view the output. There is
no reference image yet; the first render establishes one.
