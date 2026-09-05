# Specs

Feature specs live here. The active feature directory is
`.specify/feature.json`.

Specs are permanent; plans are transient and live in `plans/`. A plan is
deleted when its work lands, with anything durable moved into a spec
first.

## Index

| # | Surface | Status |
| --- | --- | --- |
| [001](001-nsi-scene-recording/) | ɴsɪ scene recording and resolution | Implemented; `Partial` and `Open` rows remain |
| [002](002-mitsuba-backend/) | Mitsuba 3 backend | Not started; blocked on a build host |

## Coverage Order

1. **001** — recording, classification, resolution, replay. Foundational:
   every backend depends on it and it needs no renderer.
2. **002** — the first backend. Retires the C++ risk.
3. Native materials, then NURBS tessellation, then generic OSL. Each is
   a surface of its own once 002 renders.

A second backend (MoonRay) is anticipated but unstarted. Its existence
is why 001 is renderer-agnostic; see `002/research.md` D5.

## Definition Of Covered

A surface is covered only when a spec exists, contracts exist, tasks
exist, every matrix row is `Covered`/`Partial`/`Open`, each `Covered`
row cites source *and* test or manual QA evidence, and each contract
carries a `Required Evidence Before Marking Complete` section.

Neither surface here is fully covered, and both say so.
