# Feature Spec: Mitsuba 3 Backend

## User Stories

### User Story 1: Render A Recorded Scene (P1)

As an ɴsɪ consumer, I want a recorded scene rendered by Mitsuba 3, so
that I have an open-source renderer behind the same interface as
3Delight.

**Acceptance Criteria**

- Given a recorded `nsi_record::Scene` containing geometry, a camera and
  a screen, when it is flushed and rendered, then a bitmap with non-zero
  pixels is produced.
- Given a scene with two shapes and two distinct materials, when it is
  rendered, then each material is applied to the correct shape.

### User Story 2: Build Without A GPU (P1)

As a user without an NVIDIA card, I want the backend to render on CPU,
so that the renderer is usable on any machine.

**Acceptance Criteria**

- Given the `llvm_ad_rgb` variant, when the backend renders, then no
  CUDA device is required.

### User Story 3: Native Materials Without OSL (P2)

As a consumer using 3Delight's stock shaders, I want the common ones
mapped onto Mitsuba's native BSDFs, so that scenes render before generic
OSL exists.

**Acceptance Criteria**

- Given a `shader` node naming `dlPrincipled`, when it is flushed, then
  a Mitsuba `principled` BSDF is instantiated with equivalent
  parameters.

### User Story 4: A Motion Vector Pass Instead Of Blur (P2)

As a compositor, I want per-pixel screen-space motion vectors, so that
blur, denoising and temporal reprojection remain possible downstream
even though the renderer cannot blur.

**Acceptance Criteria**

- Given a scene whose transforms carry two time samples, when a motion
  vector pass is requested, then each covered pixel holds the
  screen-space displacement of its surface point between the two times.
- Given a pixel covering a static surface, when the pass renders, then
  its motion vector is zero.

## Non-Goals

- **Generic OSL.** Deferred; see `003` when it exists. `dlToon` is
  confirmed not load-bearing, which is what allowed this deferral.
- **3Delight's `dl*` shaders themselves.** They ship as closed-source
  `.oso`. Even generic OSL would not run them; the native mapping in
  User Story 3 is the answer.
- **NURBS.** Mitsuba has no NURBS. Tessellation via
  `monstertruck-meshing` is a later surface.
- **Matching 3Delight's interactive latency.** `parameters_changed()`
  rebuilds the whole acceleration structure.

- **Motion blur. Mitsuba 3 cannot do it.** `AnimatedTransform` does not
  exist in `core/transform.h` and its Python binding is commented out;
  it was present in Mitsuba 2 and dropped. Sensors do carry
  `shutter_open`/`shutter_close` and rays carry a `time`, so the time
  dimension is plumbed through sampling -- but no scene quantity varies
  with it, so every sample sees an identical scene and the result is
  sharp. (`Shape::differential_motion` is automatic-differentiation
  machinery, not motion: its result is "attached (AD) to the shape's
  parameters".)

  This is a **capability regression against 3Delight**, which does
  motion blur. It is a property of the renderer, not of this backend.

  **ɴsɪ always returns an image.** The interface's philosophy is that a
  render produces pixels; refusing a scene is not an option a farm can
  use. So a motion-sampled scene renders sharp, with the limitation
  reported -- see User Story 4 for what is offered instead.

## Requirements

- R1: A hand-written `extern "C"` shim exposes Mitsuba to Rust.
- R2: No C++ exception crosses the boundary; every entry point returns a
  status and a thread-local message.
- R3: The ɴsɪ row-vector to Mitsuba column-vector transpose happens once,
  inside the shim.
- R4: The backend contains no ɴsɪ graph semantics; it consumes resolved
  facts from `001`.
- R5: `Type::Reference` never reaches Mitsuba.
- R6: One variant, fixed at build time.

## Risks

- **Mitsuba's headers may not compile standalone** outside its own build
  tree. Every render class is `template <typename Float, typename
  Spectrum>` with CRTP. Mitigated by making this the first gate, before
  any shim is written.
- **Build weight.** Mitsuba pulls Dr.Jit, Embree and LLVM. The
  development machine could not build an egui application without
  entering swap; it certainly cannot build this. Mitigated by treating a
  capable build host as a prerequisite, not an optimisation.
- **`m_shapes_dr` refresh.** Unverified whether `m_accel.rebuild()`
  refreshes Dr.Jit's shape-pointer buffer when shapes are added or
  removed. Could reshape the flush strategy.
- **Silent material misbinding.** Inherited from `001`'s top risk.
  Mitigated by an explicit two-shape, two-material test.
- **Silently sharp motion.** An ɴsɪ consumer may legitimately send
  `set_attribute_at_time`. Mitsuba cannot honour it, and ɴsɪ requires an
  image regardless, so the risk is a sharp render that reads as correct.
  Mitigated by reporting the limitation, not by refusing.

- **Shim growth.** If the C surface passes roughly twenty entry points,
  the hand-written approach is losing. Fall back to `pyo3` over
  Mitsuba's nanobind API, which is the surface upstream supports.
