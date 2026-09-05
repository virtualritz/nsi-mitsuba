# Plan: Mitsuba 3 Backend

## Status

Not started. **Blocked on a build host**, not on design.

The transient working plan is `plans/2026-09-05-mitsuba-shim.md`, which
carries the proposed C surface and the task breakdown. Delete it when
this work lands, moving anything durable here first.

## Approach

`mitsuba-shim` (C++) instantiates one Mitsuba variant and exposes a flat
C API. `mitsuba-sys` is `bindgen` over its header. `nsi-mitsuba` walks a
`nsi_record::Scene` and calls it.

## Gates

| Gate | Command | Met |
| --- | --- | --- |
| Mitsuba builds, `llvm_ad_rgb` | project CMake invocation | no |
| Headers compile standalone | a file including `scene.h` links | no |
| `Properties` round-trips every type | `cargo test -p mitsuba-sys` | no |
| Exceptions do not escape | bad-plugin-name test | no |
| **A triangle renders** | shim render test | no |
| **Two materials, two shapes, correct** | flush test | no |

Gate 2 is first for a reason: if Mitsuba's headers do not compile
outside its own build tree, that is discovered before any shim exists,
while the shim's build strategy is still free to change. It does not
change the language — `pyo3` is rejected per `research.md` D3, and the
recovery is to build the shim inside Mitsuba's own CMake tree.

Gate 5 is the milestone. Gate 6 is the one that proves correctness
rather than mere function.

## Artifact Checklist

- [x] `spec.md`
- [x] `plan.md`
- [x] `research.md`
- [x] `data-model.md`
- [x] `contracts/shim.md`
- [x] `contracts/flush.md`
- [x] `quickstart.md`
- [x] `tasks.md`
- [x] `checklists/requirements.md`

## Prerequisite

Mitsuba pulls Dr.Jit, Embree and LLVM. The machine this was specced on
has 14 GiB and was driven into swap by an egui build. Confirm a capable
host before starting; treat this as a precondition, not a tuning matter.
