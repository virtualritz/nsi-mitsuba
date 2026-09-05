# Handoff

Written 2026-09-05. Read `specs/README.md` first, then this.

## What Exists

Specs. The crate is a stub.

The renderer-agnostic half — recording, connection classification, graph
resolution and `.nsi` replay — moved to `nsi-intermediate` in the
[`nsi`](https://github.com/virtualritz/nsi) workspace once
[`nsi-moonray`](https://github.com/virtualritz/nsi-moonray) made its
renderer-agnosticism structural. Its spec went with it, as
`nsi/specs/003-nsi-intermediate-representation`; spec `001` here is
retired and keeps one line in the index, per blueprints.

That crate is done and verified: a recorded scene replays as a `.nsi`
stream token-identical to what 3Delight 2.9.207 writes for the same
calls, one generic function driving both sides.

## What To Do Next

`specs/002-mitsuba-backend/tasks.md`, in order. Two tasks matter more
than the rest:

**T2.2, the standalone header probe.** Compile a file that includes
`<mitsuba/render/scene.h>`, instantiates `Properties`, and links. Do
this *before* writing any shim. Every Mitsuba render class is a
two-parameter template with CRTP, so this is genuinely uncertain. The
probe lives at `probe/`; run it with
`MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh`.

If it fails, the answer is to build the shim inside Mitsuba's own CMake
tree, where the flags match by construction. It is *not* `pyo3`, which
was the recorded fallback until 2026-09-05 and is now rejected —
`002/research.md` D3.

**T1.10, two shapes with two materials.** This is the executable form of
the project's top risk. A misclassified ɴsɪ connection does not error;
it renders, with materials on the wrong shapes. Nothing before this task
can catch it.

## What Would Bite You

**The build machine matters.** Mitsuba pulls Dr.Jit, Embree and LLVM.
The machine this was developed on has 14 GiB and was driven into swap by
an *egui* build; it OOM-killed twice. Confirm a capable host first.

## Decisions You Should Not Silently Undo

Each has a reason recorded; changing one without reading it will look
like a simplification and be a regression.

- **The backend is C++, not `pyo3`.** A flush is one interpreter
  crossing per node, per attribute and per connection; the render is a
  single call at the end. Going through Python pays interpreter overhead
  on the whole scene to save binding work on a handful of entry points.
  `002` research D3.
- **`nsi-trait`'s `Arg` GAT has no `where Self: 'call`.** Re-adding it
  makes `impl<'a> Nsi for Context<'a>` unprovable (E0477). `001`
  research D2, and a doc comment on the trait itself.
- **`Recorder` has no context lifetime, though `Context` does.** It
  stores `Reference` addresses; `Context` does not. `001` research D3.
- **`Send`/`Sync` sits on `HostPtr`, not `Recorder`.** Scoped to the
  field that needs it. `001` research D4.
- **Transform composition is `mul(child, parent)`.** ɴsɪ is row-vector.
  The other order is correct whenever transforms commute, so the test
  uses a non-commuting pair.
- **`classify` rejects unknown destinations.** Defaulting to a reference
  is the silent-failure mode the classifier exists to prevent.
- **The `.nsi` format was read from 3Delight, not inferred.** It
  corrected four assumptions: `int64`, `doublematrix`, `int[2]`, and the
  bracketing rule.

## Known Gaps, Honestly

From the contract matrices, not memory:

- `disconnect` is implemented and **untested** (`Open`).
- `Nsi::delete` and time-sample `delete_attribute` are `Partial`.
- Whether 3Delight emits `Reference` arguments to a stream is an
  **assumption**, not verified.
- Motion-sampled transforms are unresolved.
- Only one screen is ever tested.

## Upstream

Two commits landed in [`virtualritz/nsi`](https://github.com/virtualritz/nsi)
and are pushed: `a9abbb0` (`ParamValue for Arg`) and `b092555`
(`Nsi for Context`, GAT bound dropped).

`monster-step-viewer` was to be made generic over `Nsi` as the first
consumer. That work is parked: it needs a full egui build the
development machine could not complete. An uncompiled, unverified
72-line test sits in its `src/nsi_render/mod.rs`; it is gated behind
`#[cfg(all(test, feature = "nsi-render"))]` so it cannot affect a normal
build. Rewrite it against the `for<'call> R: Nsi<Arg<'call> = ...>`
bound and the canonicaliser in `stream_roundtrip.rs`, both since proven.
