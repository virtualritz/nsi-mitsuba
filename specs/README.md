# Specs

Feature specs live here. The active feature directory is
`.specify/feature.json`.

Specs are permanent; plans are transient and live in `plans/`. A plan is
deleted when its work lands, with anything durable moved into a spec
first.

## Index

| # | Surface | Status |
| --- | --- | --- |
| 001 | *Retired.* Was "ɴsɪ scene recording and resolution". The surface moved to the `nsi` workspace as `nsi-intermediate`; its spec is [`nsi/specs/003-nsi-intermediate-representation`](https://github.com/virtualritz/nsi/tree/master/specs/003-nsi-intermediate-representation). |
| [002](002-mitsuba-backend/) | Mitsuba 3 backend | Build and header gates `Covered` (T2.1, T2.2); the shim itself is unstarted |

## Coverage Order

1. **002** — the backend itself. Retires the C++ risk.
2. Native materials, then NURBS tessellation, then generic OSL. Each is
   a surface of its own once 002 renders.

Everything upstream of the flush lives in `nsi-intermediate`. A second
backend now exists as [`nsi-moonray`](https://github.com/virtualritz/nsi-moonray),
which is what made that separation structural rather than notional; see
`002/research.md` D5.

Spec numbers are never reused or renumbered, so 001 keeps its retired
line above rather than being deleted.

## Definition Of Covered

A surface is covered only when a spec exists, contracts exist, tasks
exist, every matrix row is `Covered`/`Partial`/`Open`, each `Covered`
row cites source *and* test or manual QA evidence, and each contract
carries a `Required Evidence Before Marking Complete` section.

Neither surface here is fully covered, and both say so.
