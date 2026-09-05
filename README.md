# `nsi-mitsuba`

An [ɴsɪ](https://nsi.readthedocs.io/) backend on
[Mitsuba 3](https://github.com/mitsuba-renderer/mitsuba3).

ɴsɪ today means 3Delight: a closed-source binary and its closed-source
OSL shaders. This is a second, open-source renderer behind the same
interface.

## Crates

| Crate | What it is | State |
| --- | --- | --- |
| [`nsi-mitsuba`](crates/nsi-mitsuba) | The flush into Mitsuba. | Stub |

Everything above the flush lives in
[`nsi-intermediate`](https://github.com/virtualritz/nsi), in the `nsi`
workspace, and is shared with
[`nsi-moonray`](https://github.com/virtualritz/nsi-moonray). A backend
costs only its own flush.

## Status

The Mitsuba flush is not started. It needs a host that can build Mitsuba
(Dr.Jit, Embree, LLVM), which is a precondition rather than a tuning
matter.

## Quick Start

```bash
git clone https://github.com/virtualritz/nsi-mitsuba.git
cd nsi-mitsuba
cargo build --workspace
```

[`nsi`](https://github.com/virtualritz/nsi) resolves as a git
dependency, pinned by `Cargo.lock`. To develop against a local
checkout, add to the workspace `Cargo.toml`:

```toml
[patch."https://github.com/virtualritz/nsi.git"]
nsi-intermediate = { path = "../nsi/crates/nsi-intermediate" }
```

There is nothing to test yet — see `specs/002-mitsuba-backend/`.

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
