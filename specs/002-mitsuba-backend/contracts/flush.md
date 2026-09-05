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
| A motion-sampled scene renders sharp, and says so | Open | None | None | **Mitsuba 3 cannot do motion blur** -- `AnimatedTransform` was dropped after Mitsuba 2; see `spec.md`. ɴsɪ always returns an image, so the backend renders at shutter-open and reports the limitation. Test that motion samples are detected and surfaced, and that the render still succeeds. |
| A motion vector pass is produced | Open | None | None | Render an `aov` pass emitting `position` and `shape_index`, then compute per-pixel screen-space displacement from the recorded t0/t1 transforms. See Motion Vectors below. |
| The motion pass uses a box filter at 1 spp | Open | None | None | Mitsuba documents integer AOVs as **meaningless under partial pixel coverage or a wide reconstruction filter** -- they come back fractional. Assert the pass configures `box` width 1 and one sample per pixel, and test that a shape index round-trips exactly. |

## Denoising

Not part of this backend, but the AOVs it emits determine what is
possible downstream, so the shape is recorded here.

Mitsuba's only denoiser is OptiX, hence NVIDIA-only, hence unusable on
the CPU path this backend targets. Denoising therefore happens outside
the renderer, fed by the same `aov` mechanism as motion vectors:

| Consumer | Wants | Mitsuba AOV | Fit |
| --- | --- | --- | --- |
| OIDN | beauty, albedo, normal | `albedo`, `sh_normal` | Final frames. What 3Delight uses. |
| A temporal reconstructor (e.g. `kvark/ommatidia`) | sparse beauty, depth, normal, albedo, motion | `depth`, `sh_normal`, `albedo`, plus the motion pass below | Interactive preview at ~1 spp only. Trained on sparse input; a converged frame is out of distribution. |

Emitting these costs nothing extra: they are AOV names on an integrator
already being configured.

## Motion Vectors

Mitsuba cannot blur, but it can report enough to compute motion vectors
downstream, and this needs **no Mitsuba changes**.

The `aov` integrator already emits `position` (world space) and
`shape_index`. Given those, and the transforms `nsi-record` holds in
`Node::time_attrs`:

```text
for each covered pixel:
    P     = position AOV            # world space, at shutter open
    s     = shape_index AOV         # which shape
    M0,M1 = that shape's transforms at t0 and t1
    p_obj = inverse(M0) * P         # back to object space
    mv    = project(camera1, M1 * p_obj) - project(camera0, P)
```

Camera motion falls out of the same formula: an animated camera makes
`camera0` and `camera1` differ.

**Limits, stated rather than discovered:**

- **Rigid transform motion only.** This covers animated `transform`
  nodes. It does *not* cover deforming geometry -- ɴsɪ can send `P`
  itself at several times, and no per-object matrix describes that.
- **Requires `box` width 1 at 1 spp**, per the integer-AOV caveat above.
  A filtered shape index is a fractional index, which is not an index.
- **Needs a shape-index-to-handle map.** We control the flush, so the
  map is ours to keep; it is not recoverable from Mitsuba afterwards.

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
