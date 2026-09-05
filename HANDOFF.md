# Handoff

Written 2026-09-05. Read `specs/README.md` first, then this.

## What Exists

`nsi-record`, complete and tested. It records an ɴsɪ scene, classifies
every connection, resolves ɴsɪ's graph semantics into flat facts, and
replays the scene as a `.nsi` stream. 43 tests pass.

The fidelity gate is the part worth trusting: one generic `build`
function drives both a live 3Delight `apistream` context and the
recorder, and the two streams are compared. They match.

`nsi-mitsuba` is a documented stub.

## What To Do Next

`specs/002-mitsuba-backend/tasks.md`, in order. Two tasks matter more
than the rest:

**T2.2, the standalone header probe.** Compile a file that includes
`<mitsuba/render/scene.h>`, instantiates `Properties`, and links. Do
this *before* writing any shim. Every Mitsuba render class is a
two-parameter template with CRTP, and if the headers do not work outside
Mitsuba's own build tree, the answer is `pyo3` over its nanobind API —
not more C++. That decision is recorded in `002/research.md` D3.

**T1.10, two shapes with two materials.** This is the executable form of
the project's top risk. A misclassified ɴsɪ connection does not error;
it renders, with materials on the wrong shapes. Nothing before this task
can catch it.

## What Would Bite You

**A missing 3Delight makes the stream test fail, not pass.** Do not read
its absence as permission to mark contract rows `Covered`.
`001/quickstart.md` shows how to confirm the reference side really ran.

**Motion blur is a capability gap, not a bug to fix.** Mitsuba 3 cannot
do it: `AnimatedTransform` does not exist in `core/transform.h` and its
binding is commented out -- it was dropped after Mitsuba 2. Sensors do
have `shutter_open`/`shutter_close` and rays carry a `time`, so the
plumbing exists, but nothing in the scene varies with it.

That makes this a regression against 3Delight, which does motion blur.
Two separate consequences: `nsi-record`'s `world_transform` still reads
static attributes only (`001` T3.5, worth doing for a backend that can
use it, such as MoonRay), and the Mitsuba backend must **refuse a
motion-sampled scene rather than return a sharp image** (`002` TB.1).
A sharp render offered without comment is indistinguishable from a
correct one.

**`nsi-record` depends on `nsi` as a git dependency**, pinned by
`Cargo.lock`. Under the `[patch]` override in `README.md` it instead
tracks a local working tree, uncommitted changes included, and a red
test here may then originate there.

**The build machine matters.** Mitsuba pulls Dr.Jit, Embree and LLVM.
The machine this was developed on has 14 GiB and was driven into swap by
an *egui* build; it OOM-killed twice. Confirm a capable host first.

## Decisions You Should Not Silently Undo

Each has a reason recorded; changing one without reading it will look
like a simplification and be a regression.

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
