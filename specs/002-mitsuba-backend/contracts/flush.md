# Contract: Flushing A Recorded Scene

## Scope

Covers turning a `nsi_record::Scene` into Mitsuba objects. Depends on
`001` having resolved graph semantics already.

## Matrix

| Behavior | Status | Source Evidence | Test/QA Evidence | Required Next Evidence |
| --- | --- | --- | --- | --- |
| Geometry flushes with its world transform | Open | None | None | Flush a scene with a translated mesh; assert the rendered shape is where the transform puts it. |
| **Two materials land on the right two shapes** | Open | None | None | Two shapes, two distinct materials, render, assert each material is on its own shape. **This is `001`'s top risk made executable: a misclassified connection does not error, it renders wrongly. Nothing earlier catches it.** |
| Render outputs map to sensor and film | Open | None | None | Flush `render_outputs()`; assert resolution matches the `screen` node. |
| Instances map to shapegroup + instance | Open | None | None | Flush an `instances` node with two prototypes. |
| `dlPrincipled` maps to `principled` | Open | None | None | Flush a `shader` node naming it; assert a `principled` BSDF results. |
| An unmapped shader fails loudly | Open | None | None | Assert that an unknown `shaderfilename` errors rather than silently rendering untextured. |
| The `stream_roundtrip` fixture renders | Open | None | None | Reuse `001`'s fixture scene end to end. |
| Motion blur | Open | `001` `contracts/resolution.md` records that `world_transform` reads static attributes only | None | Blocked on `001` T3.5. **A motion-blurred scene would currently render with its static transform, silently.** |

## Invariants

- This crate contains no ɴsɪ graph semantics. Transform composition,
  `attributes` dissolution, output-chain and instance resolution all
  happen in `nsi-record`.
- `Type::Reference` never reaches Mitsuba.

## Failure Modes

- **Unmapped shader name:** must error. Rendering an untextured surface
  instead would be a silent wrong result.
- **Unmapped node type:** must error, for the same reason.

## Required Evidence Before Marking Complete

- Every row above, on a host that can build Mitsuba.
- The two-material test specifically. Do not mark this contract complete
  on the strength of a scene merely rendering.
