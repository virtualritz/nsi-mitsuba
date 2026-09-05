# Research: Mitsuba 3 Backend

## Decisions

### D1: Mitsuba 3, over LuisaCompute, Cycles and LuisaRender

| Candidate | Language | License | Verdict |
| --- | --- | --- | --- |
| **Mitsuba 3** | C++ | BSD-3 | **Chosen.** Complete renderer, active, CPU-capable. |
| LuisaCompute | C++/Rust | Apache-2.0 | A compute framework, not a renderer. `luisa-compute-rs` contains only a 569-line path-tracer example, and was last pushed 2025-12-19. |
| Cycles | C++ | Apache-2.0 | Already embeds generic OSL on CPU and OptiX -- the cheapest route to OSL. Rejected: standalone embedding is documented as not production-ready, API is Blender-shaped. **Reconsider if OSL is ever promoted ahead of everything else.** |
| LuisaRender | C++ | BSD-3 | CLI-driven, JSON scenes, no programmatic scene API. |
| AkariRender | Rust | **GPL-3.0** | Incompatible with MIT/Apache consumers, and archived 2026-04. |

Mitsuba's `Properties` is close to an ɴsɪ node: plugin name, id, typed
key/value bag. **Its connections are not ɴsɪ connections**, which is why
`001` classifies rather than translates.

### D2: A hand-written shim, not a binding generator

Every render class is a two-parameter template with CRTP:

```cpp
template <typename Float, typename Spectrum>
class MI_EXPORT_LIB Scene final : public JitObject<Scene<Float, Spectrum>>
```

A variant must be instantiated explicitly whatever the tool. `babble`
supports that, and so would the alternatives, but all require naming the
instantiation by hand. Once instantiation is manual, a generator's
automation value largely evaporates, and our surface is about a dozen
entry points.

That leaves maintenance risk to decide it. As of 2026-09: `babble` last
pushed 2025-01-19 (9 stars, 12 open issues), `bbl-build-rs` the same day
(1 star); `bindgen` pushed within two days (5274 stars). Adopting
`babble` would put maintaining a binding generator on the critical path
of a rendering project.

**Rejected:** `cxx` -- mature, but its bridge does not do templates
either, so the shim gets written anyway; `bindgen` over a plain C header
is the smaller dependency. **Rejected:** `crubit` -- active, but not
production-ready by its own account.

Keeping `babble` alive is reasonable on its own terms, since `bbl-usd`
depends on it. It is not a prerequisite here.

### D3: `pyo3` over nanobind is rejected; C++ is the only path

Superseded 2026-09-05. This entry previously named `pyo3` over Mitsuba's
nanobind API as the fallback if the headers proved unusable. That
fallback is withdrawn on performance grounds, by project decision.

The original argument was that the GIL matters less than it sounds,
because scene construction is the only chatty part and rendering happens
below in the JIT. The first half is what fails in practice: scene
construction is exactly what this backend does. A flush walks a
`nsi_record::Scene` and makes one call per node, per attribute, and per
connection, and every one of those crosses the interpreter — GIL
acquisition, argument boxing, and a nanobind dispatch each way. The
render is one call at the end. Paying interpreter overhead on the whole
scene to save binding work on a handful of entry points is the wrong
trade for a renderer backend.

So the C++ path is not merely preferred, it is the path. **A failure at
the T2.2 gate is not a licence to reach for Python.** If the headers do
not work outside Mitsuba's own build tree, the answer stays in C++, in
this order:

1. Build the shim *inside* Mitsuba's build tree as a CMake target that
   emits a C-ABI shared library. It then compiles under exactly the
   include paths, definitions and flags Mitsuba compiles itself with,
   which is what "outside the build tree" was risking. Rust links the
   result and never sees a C++ type — the `shim.md` invariants are
   unchanged.
2. Vendor the specific headers or flags that fight back, and record each
   one here.

Mitsuba's *supported* public API being Python remains true, and remains
the standing risk of this approach: the C++ API can change without
notice between releases. That is accepted, and the mitigation is the
pinned Mitsuba commit in the crate README plus the shim's own tests.

### D4: Incremental edits are viable, if blunt

`Scene::shapes()` returns a non-const `std::vector<ref<Shape>>&`, and
`Scene::parameters_changed()` (`src/render/scene.cpp:770`) scans for
`dirty()` shapes, then calls `m_accel.rebuild(this)`,
`clear_shapes_dirty()` and `update_instance_transforms()`.

So ɴsɪ `Synchronize` maps to: mutate, mark dirty, call
`parameters_changed()`. This is a **full rebuild**, not a refit, and
will be slower than 3Delight's incremental updates.

### D5: A second backend is anticipated

MoonRay (`OpenMoonRay`, Apache-2.0, active) maps onto ɴsɪ at least as
well: `SceneObject` is a handled node, `SceneClass` a node type with
declared typed attributes, `.rdla`/`.rdlb` are its stream formats. In
two places better -- attribute **bindings** carry named ports, which
Mitsuba references do not, and `Layer` is a real assignment table, a
closer target for dissolving ɴsɪ `attributes` nodes.

MoonRay has no OSL either, so it carries the same requirement. This is
why `001` is renderer-agnostic and a backend owns only the flush.

### D6: The build's own flags are the shim's flags

Established by T2.2 on 2026-09-05, against Mitsuba `609be13`. The header
gate passed, so the shim is an ordinary `cc`-built crate rather than a
CMake target inside Mitsuba's tree. It passed on three conditions, and
each is a standing constraint on `mitsuba-sys`, not a one-off fix.

**Compile as `gnu++17`.** Mitsuba builds itself at `-std=gnu++17`, not
C++20. Compiling a consumer at a different language level against the
same `.so` risks ODR and ABI mismatch, and `std::string_view` in the
public signatures makes that concrete rather than theoretical.

**Include `<cmath>` before any Mitsuba header.**
`mitsuba/render/kdtree.h` calls `std::nextafter` without including
`<cmath>`. Every Mitsuba translation unit reaches that header having
already pulled it in, so the bug is invisible in Mitsuba's own build and
fires immediately in a consumer's. Expect more of this shape: the public
headers are only ever compiled by Mitsuba itself.

**Derive the include set, do not maintain it.** The public headers reach
into a dozen bundled third-party trees -- tinyformat, nanobind's
intrusive refcounting (which is header-only and needed even at
`MI_ENABLE_PYTHON=OFF`), drjit, drjit-core, robin_map, fastfloat and
others -- for 25 include paths in total. That set is a property of the
Mitsuba commit. `probe/run.sh` reads the compiler, the standard and the
includes out of Mitsuba's `compile_commands.json`, and
`mitsuba-sys/build.rs` should read the same file for `bindgen` at T1.2
rather than carry a list that goes stale on the next bump.

## References

- `include/mitsuba/core/plugin.h` -- `PluginManager::instance()`,
  `create_object<T>(props)` dispatching on `T::Variant, T::Type`.
- `include/mitsuba/render/mesh.h` -- `Mesh` buffer constructor,
  `InputFloat = float`, `add_attribute()`.
- `src/render/scene.cpp:770` -- `parameters_changed()`.
- `include/mitsuba/render/scene_ir.h` -- the accel-builder IR. **Not**
  the flush target; it is one layer too low.
