# Mitsuba Shim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Flush a recorded ɴsɪ scene into Mitsuba 3 and render it,
through a hand-written `extern "C"` shim and `bindgen`.

**Architecture:** `mitsuba-shim` is C++ that instantiates one Mitsuba
variant and exposes a flat C API over `Properties`, `PluginManager`,
`Scene`, `Mesh` and `Bitmap`. `mitsuba-sys` is `bindgen` over its
header. `nsi-mitsuba` walks a `nsi_intermediate::Scene` and calls it.

**Tech Stack:** Mitsuba 3 (BSD-3), C++17, `bindgen`, `cc` or `cmake`.

**Spec:** `specs/002-mitsuba-backend/`

## Prerequisite: a machine that can build Mitsuba

**Nothing in this plan can be executed on the development machine this
was written on.** It has 14 GiB of RAM and was driven into swap by an
egui build; Mitsuba pulls Dr.Jit, Embree and LLVM. Confirm a build host
before starting.

This is also why the plan stops short of naming exact C++ bodies. The
`.nsi` stream work in the previous plan got its format right _because_
3Delight could be run and it corrected four wrong guesses. The same
discipline applies here: the signatures below are grounded in real
headers, but the bodies must be written against a compiler, not
inferred.

## Global Constraints

- One variant, chosen at build time. Start with `llvm_ad_rgb` — CPU,
  vectorised, no NVIDIA requirement.
- The shim owns no ɴsɪ semantics. Transform composition, `attributes`
  dissolution, output-chain and instance resolution all happened in
  `nsi-intermediate`; the shim receives resolved facts.
- C API only across the boundary: no C++ types, no exceptions escaping.
  Every entry point returns a status code or an opaque handle.
- ɴsɪ `Type::Reference` never crosses into Mitsuba.

## Grounding: the real Mitsuba API

Verified against the headers rather than assumed.

`include/mitsuba/core/plugin.h`:

```cpp
static PluginManager *instance();
ref<Object> create_object(const Properties &props, /* variant */, /* type */);
template <typename T> ref<T> create_object(const Properties &props) {
    return ref<T>((T *) create_object(props, T::Variant, T::Type).get());
}
```

`include/mitsuba/render/mesh.h`:

```cpp
using InputFloat = float;
Mesh(const Properties &props = Properties());
Mesh(std::string_view name, /* faces, positions, ... */);
ScalarSize face_count() const;
ScalarSize vertex_count() const;
// plus transform(), add_attribute()
```

Every render class is `template <typename Float, typename Spectrum>`
with CRTP (`class Scene final : public JitObject<Scene<Float,
Spectrum>>`), which is why the variant is fixed once in the shim.

## Proposed C surface

Roughly a dozen entry points. If it grows much past twenty, revisit
`pyo3` over Mitsuba's nanobind API — the fallback recorded in the spec.

```c
// Opaque handles. Ownership is explicit; every _new has a _free.
typedef struct MiProps  MiProps;
typedef struct MiObject MiObject;
typedef struct MiBitmap MiBitmap;

typedef enum { MI_OK = 0, MI_ERR_PLUGIN, MI_ERR_TYPE, MI_ERR_RENDER } MiStatus;

// --- Properties -----------------------------------------------------
MiProps *mi_props_new(const char *plugin_name);
void     mi_props_free(MiProps *);
void     mi_props_set_bool  (MiProps *, const char *name, int value);
void     mi_props_set_int   (MiProps *, const char *name, int64_t value);
void     mi_props_set_float (MiProps *, const char *name, double value);
void     mi_props_set_string(MiProps *, const char *name, const char *value);
void     mi_props_set_vector(MiProps *, const char *name, const double v[3]);
void     mi_props_set_color (MiProps *, const char *name, const double v[3]);
// Row-major, as nsi_intermediate::Scene::world_transform returns it. The shim
// transposes: ɴsɪ is row-vector, Mitsuba column-vector.
void     mi_props_set_transform(MiProps *, const char *name, const double m[16]);
void     mi_props_set_object(MiProps *, const char *name, MiObject *child);

// --- Instantiation --------------------------------------------------
MiStatus mi_create_object(const MiProps *, MiObject **out);
void     mi_object_free(MiObject *);

// --- Mesh from buffers ----------------------------------------------
// Positions are 3 floats per vertex, indices 3 per triangle. ɴsɪ
// polygons are triangulated by the caller, in nsi-mitsuba.
MiStatus mi_mesh_new(const char *name,
                     const float *positions, size_t vertex_count,
                     const uint32_t *indices, size_t face_count,
                     const float *normals /* or NULL */,
                     const float *uvs     /* or NULL */,
                     MiObject **out);

// --- Render ---------------------------------------------------------
MiStatus mi_render(MiObject *scene, MiObject *sensor, MiBitmap **out);
MiStatus mi_bitmap_data(MiBitmap *, const float **data,
                        size_t *width, size_t *height, size_t *channels);
void     mi_bitmap_free(MiBitmap *);

// --- Diagnostics ----------------------------------------------------
// Last error for this thread; valid until the next shim call.
const char *mi_last_error(void);
```

Two things this shape settles deliberately:

**Errors do not propagate as exceptions.** Mitsuba throws; C cannot.
Every entry point catches, stores the message thread-locally, and
returns a status. `mi_last_error` retrieves it.

**Handedness is converted at the boundary, once.** ɴsɪ is row-vector
row-major; Mitsuba is column-vector. Doing the transpose inside
`mi_props_set_transform` means neither `nsi-intermediate` nor `nsi-mitsuba`
carries a convention flag, and there is exactly one place to get it
wrong.

---

### Task 1: Build Mitsuba and prove the toolchain

**Files:** `crates/mitsuba-shim/CMakeLists.txt` (or `build.rs` with `cc`)

- [ ] **Step 1:** Build Mitsuba 3 with the `llvm_ad_rgb` variant on the
      build host. Record the exact CMake invocation in the crate README.
- [ ] **Step 2:** Compile a throwaway C++ file that includes
      `<mitsuba/render/scene.h>`, instantiates `Properties`, and links.
      Expected: links clean. This is the gate — if Mitsuba's headers do
      not compile standalone outside its own build tree, that is
      discovered now rather than after the shim is written.
- [ ] **Step 3:** Commit the build recipe.

### Task 2: Properties through the shim

**Files:** `crates/mitsuba-shim/{shim.h,props.cpp}`,
`crates/mitsuba-sys/{build.rs,src/lib.rs}`

- [ ] **Step 1:** Write `mi_props_*` and `mi_last_error`.
- [ ] **Step 2:** `bindgen` over `shim.h` in `mitsuba-sys/build.rs`.
- [ ] **Step 3:** Rust test: build a `Properties` with one of each type,
      instantiate a trivial plugin, assert `MI_OK`.
      Run: `cargo test -p mitsuba-sys`
- [ ] **Step 4:** Test that a bad plugin name returns `MI_ERR_PLUGIN`
      and `mi_last_error` is non-empty — proving exceptions are caught
      rather than crossing the boundary.
- [ ] **Step 5:** Commit.

### Task 3: A triangle renders

**Files:** `crates/mitsuba-shim/{mesh.cpp,render.cpp}`

- [ ] **Step 1:** Implement `mi_mesh_new`, `mi_render`,
      `mi_bitmap_data`.
- [ ] **Step 2:** Rust test: one triangle, a `perspective` sensor, a
      `path` integrator, an `hdrfilm`. Render at 32x32.
      Expected: `MI_OK`, non-zero pixels.
- [ ] **Step 3:** Commit. **This is the milestone** — everything after
      is mapping, with the C++ risk retired.

### Task 4: Flush a recorded scene

**Files:** `crates/nsi-mitsuba/src/flush.rs`

- [ ] **Step 1:** Walk `nsi_intermediate::Scene`; for each geometry node
      call `world_transform` for `to_world` and `geometry_binding` for
      the material, and build `Properties`.
- [ ] **Step 2:** Map `render_outputs` onto sensor + film.
- [ ] **Step 3:** Test: the `stream_roundtrip` fixture scene renders
      without error.
- [ ] **Step 4:** Commit.

### Task 5: The binding test the spec demands

- [ ] **Step 1:** Two shapes, two distinct materials, render, assert
      each material landed on the correct shape.

This is the spec's top risk made executable: a misclassified connection
does not error, it renders wrongly. Nothing before this task can catch
it.

## Deferred

- **Native BSDF mapping** (`dlPrincipled` → `principled`, and the rest)
  — spec Phase 4.
- **NURBS** via `monstertruck-meshing` — Phase 5.
- **OSL** — Phase 6, and the `nsi-osl` crate is shared with any second
  backend.
- **Incremental edits.** `parameters_changed()` rebuilds the whole
  acceleration structure. Correct but slower than 3Delight; measure
  before optimising.
