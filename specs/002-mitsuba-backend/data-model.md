# Data Model: Mitsuba 3 Backend

## Entities

### `MiProps` (opaque, C side)

Wraps `mitsuba::Properties`. Owned by Rust, freed via `mi_props_free`.
Carries a plugin name, an id, and typed values.

| ɴsɪ `Type` | Mitsuba `Properties::Type` |
| --- | --- |
| `F32`, `F64` | `Float` |
| `I32`, `I64` | `Integer` |
| `String` | `String` |
| `Color` | `Color` |
| `Point`, `Vector`, `Normal` | `Vector` |
| `MatrixF32`, `MatrixF64` | `Transform` |
| `Reference` | **none -- never crosses** |

ɴsɪ `Type::Reference` is a raw host pointer, called `Pointer` in the C
API. Mitsuba's `Reference` is an id-based object link. **They share a
name and nothing else.**

### `MiObject` (opaque)

A `ref<Object>` from `PluginManager::create_object`. Shapes, BSDFs,
sensors, films and integrators are all this type on the C side; Rust
does not distinguish them.

### `MiBitmap` (opaque)

Render output. `mi_bitmap_data` exposes a float buffer with dimensions
and channel count.

## Ownership

Every `_new` has a matching `_free`. Rust owns handles and frees them;
C++ never retains one past a call except through the object graph a
`Scene` holds.

## Wire Formats

### Transform handedness

`nsi_intermediate::Scene::world_transform` returns row-major, row-vector.
Mitsuba is column-vector. **The transpose happens once, inside
`mi_props_set_transform`.** Neither `nsi-intermediate` nor `nsi-mitsuba`
carries a convention flag, and there is exactly one place to get it
wrong.

### Mesh buffers

Positions are 3 `float` per vertex, indices 3 `uint32_t` per triangle.
Mitsuba's `InputFloat` is `float`, so `f64` ɴsɪ data narrows at the
boundary. ɴsɪ polygons are triangulated by the caller.

### Status codes

`MI_OK`, `MI_ERR_PLUGIN`, `MI_ERR_TYPE`, `MI_ERR_RENDER`. Mitsuba
throws; C cannot. Every entry point catches and stores the message
thread-locally for `mi_last_error`.

## Node Mapping

| ɴsɪ node | Mitsuba |
| --- | --- |
| `mesh` | `Mesh` from buffers |
| `transform` | resolved away into `to_world` by `001` |
| `attributes` | dissolved by `001` into a `bsdf` reference |
| `shader` | a BSDF or texture plugin |
| `perspectivecamera` | `perspective` sensor |
| `orthographiccamera` | `orthographic` sensor |
| `screen` | resolution and sampler on the sensor |
| `outputlayer` | film channel |
| `outputdriver` | `Bitmap` plus a host callback |
| `environment` | `envmap` emitter |
| `instances` | `shapegroup` + `instance` |
| `nurbs` | **none.** Tessellated first; a later surface. |

## Shader Mapping

| ɴsɪ `shaderfilename` | Mitsuba |
| --- | --- |
| `dlPrincipled` | `principled` |
| `dlMetal` | `roughconductor` |
| `dlConstant` | `null` + `area` emitter |
| `environmentLight` | `envmap` |
| `checker`, `uvCoord`, `dlNoise` | texture plugins |
| `dlToon` | **no analogue.** Not load-bearing; see `spec.md`. |

## Migrations

None yet. The shim's C header is the compatibility surface; changing it
requires regenerating `mitsuba-sys`.
