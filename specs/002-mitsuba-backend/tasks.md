# Tasks: Mitsuba 3 Backend

Nothing is started. Ordering is by risk retired per task, not by
convenience.

## User Story 2: Build Without A GPU (P1)

- [ ] T2.1 Build Mitsuba 3, `llvm_ad_rgb`, on a capable host. Record the
      CMake invocation in the crate README.
- [ ] T2.2 **Compile a standalone probe including
      `<mitsuba/render/scene.h>` and link it.**
      Gate: `contracts/shim.md` headers row. Do this before writing any
      shim; a failure here means `pyo3`, not more C++.

## User Story 1: Render A Recorded Scene (P1)

- [ ] T1.1 `mi_props_*` and `mi_last_error`.
- [ ] T1.2 `bindgen` over the shim header in `mitsuba-sys/build.rs`.
- [ ] T1.3 Test: one value of each ɴsɪ type through `Properties`.
- [ ] T1.4 Test: a bad plugin name returns `MI_ERR_PLUGIN` with a
      non-empty message. Proves exceptions are caught.
- [ ] T1.5 `mi_mesh_new`, `mi_render`, `mi_bitmap_data`.
- [ ] T1.6 **Test: a triangle renders.** Milestone -- C++ risk retired.
- [ ] T1.7 Test: the transform transpose places a shape correctly.
- [ ] T1.8 `flush.rs` walking a `nsi_record::Scene`.
- [ ] T1.9 Map `render_outputs()` onto sensor and film.
- [ ] T1.10 **Test: two shapes, two materials, each correct.**
      Gate: `contracts/flush.md`. This is `001`'s top risk made
      executable; nothing earlier catches a misbinding.
- [ ] T1.11 Test: an unmapped shader or node type errors rather than
      rendering something plausible.

## User Story 3: Native Materials (P2)

- [ ] T3.1 `dlPrincipled` to `principled`, with parameter mapping.
- [ ] T3.2 `dlMetal`, `dlConstant`, `environmentLight`, and the texture
      shaders.

## Blocked

- [ ] TB.1 **Refuse motion, do not implement it.** Mitsuba 3 has no
      `AnimatedTransform`; the capability was dropped after Mitsuba 2.
      Not blocked on `001` T3.5 -- resolving motion samples would not
      help, because there is nothing to hand them to. The task is to
      detect `set_attribute_at_time` on a transform and fail or warn,
      never to return a sharp image as an unqualified success.
- [ ] TB.2 Verify `m_accel.rebuild()` refreshes `m_shapes_dr` when
      shapes are added or removed. Could reshape the flush strategy.
