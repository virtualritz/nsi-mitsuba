# Contract: The C Shim

## Scope

Covers the `extern "C"` boundary between Rust and Mitsuba 3. Does not
cover ɴsɪ mapping (`flush.md`).

## Matrix

| Behavior | Status | Source Evidence | Test/QA Evidence | Required Next Evidence |
| --- | --- | --- | --- | --- |
| Mitsuba builds with the `llvm_ad_rgb` variant | Open | None | None | Build on a capable host; record the exact CMake invocation in the crate README. |
| Mitsuba headers compile standalone | Open | None | None | Compile a file including `<mitsuba/render/scene.h>` that instantiates `Properties` and links. **This is the first gate; if it fails, move the shim inside Mitsuba's CMake tree per `research.md` D3 — the project does not leave C++.** |
| `Properties` round-trips every ɴsɪ type | Open | None | None | Rust test setting one value of each type, instantiating a trivial plugin, asserting `MI_OK`. |
| No C++ exception crosses the boundary | Open | None | None | Test that a bad plugin name returns `MI_ERR_PLUGIN` with a non-empty `mi_last_error`, rather than aborting. |
| A mesh is constructed from buffers | Open | None | None | Test building a triangle and asserting `face_count == 1`, `vertex_count == 3`. |
| A triangle renders | Open | None | None | Render 32x32 with `perspective` + `path` + `hdrfilm`; assert `MI_OK` and non-zero pixels. **This is the milestone; C++ risk is retired here.** |
| The transform transpose is correct | Open | None | None | Test that a known ɴsɪ row-vector matrix places a shape where Mitsuba reports it. A transposed matrix is plausible and wrong only asymmetrically. |
| Handles free without leaking | Open | None | None | Run the shim tests under a leak checker. |

## Invariants

- No C++ type crosses the boundary.
- Every `_new` has a `_free`.
- `mi_last_error` is valid until the next shim call on that thread.

## Failure Modes

- **Missing plugin:** `MI_ERR_PLUGIN`, message names the plugin.
- **Type mismatch on a property:** `MI_ERR_TYPE`.
- **Render failure:** `MI_ERR_RENDER`.
- **Mitsuba aborts rather than throwing:** not recoverable in-process.
  The shim cannot be made safe against it, and `pyo3` is not the escape
  (`research.md` D3) — an abort below the binding takes the process down
  whichever language called it. If this happens, the shim must avoid the
  aborting call rather than catch it.

## Required Evidence Before Marking Complete

- A build host. **None of this is runnable on the machine this spec was
  written on**; see `spec.md` risks.
- `cargo test -p mitsuba-sys`
- The standalone-header compile, before any shim code is written.
