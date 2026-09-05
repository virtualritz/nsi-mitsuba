# Handoff

Written 2026-09-05. Read `specs/README.md` first, then this.

## What Exists

`nsi-record`, complete and tested. It records an ɴsɪ scene, classifies
every connection, resolves ɴsɪ's graph semantics into flat facts, and
replays the scene as a `.nsi` stream. 43 tests pass.

The fidelity gate is the part worth trusting: one generic `build`
function drives both a live 3Delight `apistream` context and the
recorder, and the two streams are compared. They match.

`nsi-mitsuba` is a documented stub, but no longer a blocked one: Mitsuba
3 builds and its headers are proven usable from outside its build tree
(T2.1, T2.2). See `crates/nsi-mitsuba/README.md`.

## Picking This Up On A Fresh Checkout

Three things live outside the repository and do not travel with a clone.

**The `.blueprints` submodule is private.** A plain clone leaves it
empty and every `.blueprints/...` reference in `AGENTS.md` dangles:

```bash
git submodule update --init .blueprints
```

That needs credentials for `virtualritz/blueprints`. The per-repo setup
is already committed, so nothing needs re-running — but if you ever do,
`.blueprints/setup.sh` skips files that exist and will not clobber
`specs/README.md` or `AGENTS.md`. `setup-user.sh` is separate and runs
once per machine, not per checkout.

**Mitsuba is not vendored.** `MITSUBA_DIR` points at a build tree that
lives wherever you put it; `crates/nsi-mitsuba/README.md` has the
invocation. Budget for it — 834 targets, and the `-j3` ceiling there is
load-bearing on a 16 GiB box.

**`just` may not be installed.** `.blueprints/setup.sh` installs it via
cargo if missing; `cargo install just` is the same thing.

Then confirm the baseline before changing anything:

```bash
cargo test --all-features                                  # 43 pass with 3Delight
MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh          # T2.2, exits 0
```

## What To Do Next

`specs/002-mitsuba-backend/tasks.md`, in order. The task that matters
most is now T1.10; T2.2 is done, and its result is recorded below
because it constrains everything after it.

**T2.2, the standalone header probe, has passed** — 2026-09-05, against
Mitsuba `609be13`. This was the first gate and the C++ risk it guarded
is retired: the headers work in a translation unit outside Mitsuba's own
build tree, so the shim is an ordinary `cc`-built crate and does not
have to move inside Mitsuba's CMake. Re-run it any time with
`MITSUBA_DIR=/path/to/mitsuba3/build ./probe/run.sh`.

It bought three constraints, all in `002/research.md` D6, and all of
them bind `mitsuba-sys` at T1.2: compile as **`gnu++17`** (not C++20),
include **`<cmath>` before any Mitsuba header** (`kdtree.h` calls
`std::nextafter` without it — latent in Mitsuba's build, fatal in a
consumer's), and **derive the 25 include paths from Mitsuba's
`compile_commands.json`** rather than maintaining a list.

So the next task is **T1.1**, `mi_props_*` and `mi_last_error`. Building
Mitsuba is documented in `crates/nsi-mitsuba/README.md`.

**T1.10, two shapes with two materials.** This is the executable form of
the project's top risk. A misclassified ɴsɪ connection does not error;
it renders, with materials on the wrong shapes. Nothing before this task
can catch it.

## What Would Bite You

**A missing 3Delight makes the stream test fail, not pass.** Do not read
its absence as permission to mark contract rows `Covered`.
`001/quickstart.md` shows how to confirm the reference side really ran.

**Motion blur silently resolves to the static transform.**
`world_transform` reads static attributes only. `Scene` stores
`time_attrs` separately precisely so this can be fixed, but the API
decision has not been made. Tracked as `001` T3.5 and `002` TB.1.

**`nsi-record` depends on `nsi` as a git dependency**, pinned by
`Cargo.lock`. Under the `[patch]` override in `README.md` it instead
tracks a local working tree, uncommitted changes included, and a red
test here may then originate there.

**The build machine matters.** Mitsuba pulls Dr.Jit, Embree and LLVM.
The machine this was developed on has 14 GiB and was driven into swap by
an *egui* build; it OOM-killed twice. A 4-core / 15 GiB host does manage
it at `-j3` with the Python bindings off and the variants trimmed to
two — that exact invocation, and why each part of it is deliberate, is
in `crates/nsi-mitsuba/README.md`. Do not raise `-j` without headroom.

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
