# Agent Instructions

<!-- SPEC-DRIVEN DEVELOPMENT START -->
Spec-driven development is enabled for this repository.

Before creating or changing a feature surface:

- Read `.blueprints/domain/spec-driven-development.md`.
- Read the active spec pointer in `.specify/feature.json`.
- Read the current feature plan before editing code.
- Work one user story or one contract row at a time.
- Mark contract rows `Covered` only after source evidence and test/manual QA
  evidence are present.

Project-specific specs live in `specs/`. Shared rules and templates live in
`.blueprints/`.
<!-- SPEC-DRIVEN DEVELOPMENT END -->

> `.blueprints` is a private submodule. Without access to it, work from
> `specs/` and this file: the layout, the eight required artifacts per
> feature, and the contract-matrix rules are all visible there. No code
> in this repository depends on it.

## This Repository

One crate, `nsi-mitsuba`: the Mitsuba 3 flush, and nothing else. A stub
today.

Everything above the flush lives in `nsi-intermediate`, in the
[`nsi`](https://github.com/virtualritz/nsi) workspace, and is shared
with [`nsi-moonray`](https://github.com/virtualritz/nsi-moonray).

**If a behaviour is wanted by every backend, it belongs upstream, not
here.** Transform composition and `attributes` dissolution are upstream
for that reason. What lands here is Mitsuba-specific: `Properties`,
`PluginManager`, and the renderer-specific half of the graph rewrites --
`attributes` dissolution reaches `bsdf` + `visibility_mask` here and a
`Layer` entry in MoonRay, from the same classified edges.

## Local Dependencies

Depends on `nsi-intermediate` from the `nsi` repository, as a git
dependency pinned by `Cargo.lock`. Alias it if the full name grates:

```rust
use nsi_intermediate as nsi_ir;
```

When working on both at once, use the `[patch]` block in `README.md`.

## Before Claiming Anything Works

Every contract row in `specs/002-mitsuba-backend/` is `Open`. Nothing
here is implemented, and the first gate is not code: compile a file that
includes `<mitsuba/render/scene.h>` and link it. If Mitsuba's headers do
not work outside its own build tree, the answer is `pyo3` over its
nanobind API, not more C++. See `002/research.md` D3.
