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
| A motion-sampled scene is refused, not silently flattened | Open | None | None | **Mitsuba 3 cannot do motion blur** -- `AnimatedTransform` was dropped after Mitsuba 2; see `spec.md`. So this row is not "implement motion", it is "fail honestly". Test that a scene with `set_attribute_at_time` on a transform either errors or renders with a recorded warning, and never returns a sharp image as an unqualified success. |

## Invariants

- This crate contains no ɴsɪ graph semantics. Transform composition,
  `attributes` dissolution, output-chain and instance resolution all
  happen in `nsi-record`.
- `Type::Reference` never reaches Mitsuba.

## Failure Modes

- **Unmapped shader name:** must error. Rendering an untextured surface
  instead would be a silent wrong result.
- **Unmapped node type:** must error, for the same reason.
- **Motion samples present:** must not be silently discarded. A sharp
  image returned without comment is indistinguishable from a correct
  one, which is the failure mode this project exists to avoid.

## Required Evidence Before Marking Complete

- Every row above, on a host that can build Mitsuba.
- The two-material test specifically. Do not mark this contract complete
  on the strength of a scene merely rendering.
