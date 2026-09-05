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

Two crates:

- `nsi-record` — renderer-agnostic. Records an ɴsɪ scene, classifies its
  connections, resolves its graph semantics, and replays it as a `.nsi`
  stream. No renderer needed to build or test it.
- `nsi-mitsuba` — the Mitsuba 3 flush. A stub today.

The split is deliberate: nothing above the flush is Mitsuba-specific, so
a second backend costs only its own flush. See
`specs/002-mitsuba-backend/research.md` D5.

## Local Dependencies

`nsi-record` depends on [`nsi`](https://github.com/virtualritz/nsi) **by
path** during development, so it tracks that working tree — uncommitted
changes included. A red test here may originate there. Check both before
concluding this repo is broken.

The trait seam it relies on landed upstream in `a9abbb0` and `b092555`.

## Before Claiming Anything Works

`specs/001-nsi-scene-recording/contracts/stream.md` is the fidelity gate,
and it needs a working 3Delight. **A missing 3Delight makes that test
fail, not pass** — do not read its absence as licence to mark rows
`Covered`. `quickstart.md` shows how to confirm the reference side ran.
