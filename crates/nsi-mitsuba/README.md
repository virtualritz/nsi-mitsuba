# nsi-mitsuba

The Mitsuba 3 backend for ɴsɪ. Holds the flush; everything upstream of
it is renderer-agnostic and lives in `nsi-intermediate`.

## Building Mitsuba 3

`specs/002-mitsuba-backend/tasks.md` T2.1. Mitsuba is not vendored and
not built by `cargo`; build it once and point `MITSUBA_DIR` at the
result.

```bash
git clone --recursive https://github.com/mitsuba-renderer/mitsuba3.git
cd mitsuba3
cmake -GNinja -B build -DMI_ENABLE_PYTHON=OFF
```

Then edit `build/mitsuba.conf` and trim the enabled variants:

```jsonc
"enabled": [
    "scalar_rgb", "llvm_ad_rgb"
],
```

Re-run `cmake -GNinja -B build` to pick that up, then:

```bash
ninja -C build -j3
```

Verified against Mitsuba `609be13` (3.10.0.dev1), Ubuntu 24.04,
GCC 13, on a 4-core / 15 GiB host: 834 targets, no failures.

Three things about that invocation are deliberate.

**`-DMI_ENABLE_PYTHON=OFF`.** The default `ON` builds the Python
bindings in nanobind *split mode* (`MI_SPLIT_MODE`, on by default),
whose stub-generation step imports the freshly built `_drjit_ext` and
fails unless the `nanobind-backend` package is installed. The backend
links `libmitsuba` directly and never goes through Python — `pyo3` is
rejected, see `specs/002-mitsuba-backend/research.md` D3 — so the
bindings are not merely unnecessary, they are a third of the build.

**Trimming the variants.** The stock config enables five, including
`cuda_ad_rgb`, which needs CUDA. `llvm_ad_rgb` is the variant the spec
targets and `scalar_rgb` is mandatory, so those two are the whole set.

**`-j3` on a 4-core host.** Mitsuba instantiates every render class
across all enabled variants, and the peak translation units are several
GiB each. `HANDOFF.md` records this machine class OOM-killing twice on a
lighter build.

Confirm the variant is live before going further:

```console
$ ./build/mitsuba --help | head -3
Mitsuba version 3.10.0.dev1 (master[609be13], Linux, 64bit, 5 threads, 16-wide SIMD)
...
Enabled processor features: llvm avx512 avx2 avx fma f16c sse4.2 x86_64
```

`llvm` in that feature list, and `llvm_ad_rgb` under the `--mode`
options, is the evidence that the variant loads rather than merely
compiles.

## The header gate

`tasks.md` T2.2, the first gate: Mitsuba's public headers have to work
in a translation unit outside its own build tree, or the shim has to
move inside that tree.

```bash
MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh
```

This passes as of Mitsuba `609be13`. Two things it established are
binding constraints on `mitsuba-sys`:

- **Compile as `gnu++17`, not C++20.** Mitsuba builds itself at
  `-std=gnu++17`. A consumer at a different language level risks ODR and
  ABI mismatch against the `.so` it links.
- **Include `<cmath>` before any Mitsuba header.**
  `mitsuba/render/kdtree.h` calls `std::nextafter` without including
  `<cmath>`. Mitsuba's own translation units reach it having already
  pulled that in, so the bug is latent in its build and fires only in a
  consumer's.

`probe/run.sh` derives the compiler, the language standard and all 25
include paths from Mitsuba's `compile_commands.json` rather than
hard-coding them. That set is a property of the Mitsuba commit — the
public headers reach into tinyformat, nanobind's intrusive refcounting,
drjit, robin_map and others — and `mitsuba-sys/build.rs` will need the
same list for `bindgen` at T1.2.
