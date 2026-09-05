# `nsi-mitsuba`

An [ɴsɪ](https://nsi.readthedocs.io/) backend on
[Mitsuba 3](https://github.com/mitsuba-renderer/mitsuba3), and the
renderer-agnostic recording layer beneath it.

ɴsɪ today means 3Delight: a closed-source binary and its closed-source
OSL shaders. This is a second, open-source renderer behind the same
interface.

## Crates

| Crate | What it is | State |
| --- | --- | --- |
| [`nsi-record`](crates/nsi-record) | Records an ɴsɪ scene, classifies its connections, resolves its graph semantics, replays it as `.nsi`. Renderer-agnostic. | Implemented, 43 tests |
| [`nsi-mitsuba`](crates/nsi-mitsuba) | The flush into Mitsuba. | Stub |

`nsi-record` needs no renderer to build or test. Everything above the
flush is renderer-agnostic, so a second backend — MoonRay is the
candidate — costs only its own flush.

## Status

`nsi-record` is done and verified: a recorded scene replays as a `.nsi`
stream **token-identical to what 3Delight 2.9.207 writes for the same
calls**, with one generic function driving both sides.

The Mitsuba flush is not started. It needs a host that can build Mitsuba
(Dr.Jit, Embree, LLVM), which is a precondition rather than a tuning
matter.

## Quick Start

This repository depends on [`nsi`](https://github.com/virtualritz/nsi)
**by path**, so it expects a sibling checkout:

```bash
git clone https://github.com/virtualritz/nsi.git
git clone https://github.com/virtualritz/nsi-mitsuba.git
cd nsi-mitsuba
cargo test --workspace
```

The layout must be `<parent>/nsi` and `<parent>/nsi-mitsuba`, because
`crates/nsi-record/Cargo.toml` reaches across with a relative path.

Path deps are deliberate while both repositories move together; the
trait seam this needs landed in `nsi` only recently. They become version
deps once `nsi` publishes.

The stream test needs a working 3Delight, and **fails rather than skips
without it**. See `specs/001-nsi-scene-recording/quickstart.md`.

## Documentation

This repository uses spec-driven development. Specs are permanent and
live in [`specs/`](specs/); plans are transient and live in
[`plans/`](plans/). Start with [`specs/README.md`](specs/README.md), and
read [`HANDOFF.md`](HANDOFF.md) to pick the work up.

Shared standards come from `.blueprints`, a submodule.

> **`.blueprints` is a private repository.** If you do not have access,
> clone without it:
>
> ```bash
> git clone https://github.com/virtualritz/nsi-mitsuba.git
> ```
>
> A plain `clone` does not fetch submodules, so nothing breaks. Only
> `--recurse-submodules` or `git submodule update --init` will fail, on
> `.blueprints` alone. Nothing in this repository needs it to build or
> test — it carries shared authoring standards, not code. The
> conventions it describes are visible in `specs/` regardless.

## Licence

MIT OR Apache-2.0 OR Zlib, matching `nsi`.
