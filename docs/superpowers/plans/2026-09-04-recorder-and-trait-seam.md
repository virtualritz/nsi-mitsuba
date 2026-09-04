# ɴsɪ Recorder and Trait Seam Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `nsi::Context` implement `nsi_trait::Nsi`, make a consumer
generic over that trait, and build a pure-Rust ɴsɪ recorder that
classifies connections and can replay a scene as an `.nsi` stream.

**Architecture:** Two crates change. In `nsi`, `Arg` gains a `ParamValue`
impl and `Context` gains an `Nsi` impl — nine thin delegations, since the
inherent method signatures already match the trait exactly. In the new
`nsi-mitsuba` repo, a `Recorder` implements `Nsi` by storing nodes,
owned attributes, and a classified edge list behind a `Mutex`, then
replays them as an `.nsi` stream for byte-comparison against 3Delight.

**Tech Stack:** Rust 2024 edition, `indexmap` for insertion-ordered
tables, `ustr` (optional) for interned handles. No C++, no Mitsuba, no
renderer needed to build or test anything in this plan.

**Spec:** `docs/superpowers/specs/2026-09-03-nsi-mitsuba-design.md`

## Global Constraints

- Edition `2024`; matches every crate in the `nsi` workspace.
- License `MIT OR Apache-2.0 OR Zlib`, matching `nsi`.
- `nsi-trait` version `0.3`, by path during development.
- No C++, no `bbl-*`, no Mitsuba dependency anywhere in this plan. Those
  begin at Phase 3.
- ɴsɪ `Type::Reference` is a raw host pointer, never an object link. It
  is stored but never forwarded to a renderer.
- Every connection is classified by `to_attr`. An unrecognised `to_attr`
  is an error, never a silent default.

## Spec amendment: the shared `Arg` currency

The spec did not settle which concrete type satisfies the trait's
`type Arg<'call>: ParamValue` for the recorder, and it matters.

Consumers build arguments with the `nsi::point_slice!` / `nsi::f32!` /
`nsi::string!` macros, which produce `nsi_ffi_wrap::Arg<'a, 'b>`. If the
recorder invented its own `Arg` type, every generic consumer would need a
second set of macros and the generic rewrite in Task 3 would cascade
through every call site.

**Decision:** `nsi_ffi_wrap::Arg` is the shared argument currency.
`nsi-mitsuba` depends on `nsi-ffi-wrap` for the type only. This matches
what upstream already assumes — `FfiApiAdapter` is declared as
`for<'a> T: Nsi<Arg<'a> = Arg<'a, 'a>>`. Merely constructing an `Arg`
loads no renderer: `nsi-ffi-wrap`'s default features enable neither
`link_lib3delight` nor `download_lib3delight`, and the dynamic loader
only runs on `Context::new`.

Consequence: `impl ParamValue for Arg` must live inside `nsi-ffi-wrap`,
because `Arg`'s fields are `pub(crate)`. That is Task 1.

## File Structure

**In `~/code/crates/nsi` (existing workspace):**

- Create `crates/nsi-ffi-wrap/src/param_value.rs` — `impl ParamValue for
Arg`, plus the `DataType` → `Type` mapping. Isolated in its own file so
  the trait bridge is reviewable apart from `argument.rs`, which is
  already large.
- Create `crates/nsi-ffi-wrap/src/nsi_impl.rs` — `impl Nsi for
Context<'a>`. Nine delegations, nothing else.
- Modify `crates/nsi-ffi-wrap/src/lib.rs` — declare both modules.

**In `~/code/crates/nsi-mitsuba` (new):**

- Create `Cargo.toml` — workspace.
- Create `crates/nsi-mitsuba/Cargo.toml`.
- Create `crates/nsi-mitsuba/src/lib.rs` — public surface, re-exports.
- Create `crates/nsi-mitsuba/src/owned.rs` — `OwnedArg` / `OwnedData`:
  the owned mirror of a borrowed `Arg`.
- Create `crates/nsi-mitsuba/src/scene.rs` — `Node`, `Scene`, the node
  and attribute tables.
- Create `crates/nsi-mitsuba/src/edge.rs` — `Edge`, `EdgeKind`, and the
  classifier. Kept separate from `scene.rs` because the classifier is the
  spec's highest-risk component and deserves its own test file.
- Create `crates/nsi-mitsuba/src/recorder.rs` — `Recorder` and the `Nsi`
  impl.
- Create `crates/nsi-mitsuba/src/stream.rs` — `.nsi` stream emitter.
- Create `crates/nsi-mitsuba/tests/classifier.rs`.
- Create `crates/nsi-mitsuba/tests/stream_roundtrip.rs`.

---

### Task 1: `ParamValue` for `Arg`

The trait seam needs `Arg` to expose its name, type, length, flags and a
C-compatible view. `Arg`'s fields are `pub(crate)`, so this impl must be
inside `nsi-ffi-wrap`.

`DataType` (`argument.rs:701`) and `nsi_trait::Type` are both `repr(i32)`
with discriminants derived from `NSIType`, so the values already agree.
Map them explicitly anyway — an explicit match fails to compile if either
enum gains a variant, whereas a transmute would silently accept it.

**Files:**

- Create: `crates/nsi-ffi-wrap/src/param_value.rs`
- Modify: `crates/nsi-ffi-wrap/src/lib.rs`
- Test: `crates/nsi-ffi-wrap/src/param_value.rs` (inline `mod tests`,
  matching the crate's existing style in `argument.rs`)

**Interfaces:**

- Consumes: `Arg<'a, 'b>` fields `name: Ustr`, `data: ArgData<'a, 'b>`,
  `array_length: NonZeroUsize`, `flags: i32`; the `pub(crate) trait
ArgDataMethods` with `type_() -> DataType`, `len() -> usize`,
  `as_c_ptr() -> *const c_void`.
- Produces: `impl<'a, 'b> ::nsi_trait::ParamValue for Arg<'a, 'b>`.
  Task 2 relies on this impl existing.

- [ ] **Step 1: Write the failing test**

Create `crates/nsi-ffi-wrap/src/param_value.rs` with only the test module
for now:

```rust
#[cfg(test)]
mod tests {
    use crate::*;
    use ::nsi_trait::{ParamValue, Type};

    #[test]
    fn f32_arg_reports_name_type_and_len() {
        let arg = f32!("roughness", 0.3);
        assert_eq!(arg.name(), "roughness");
        assert_eq!(arg.type_tag(), Type::F32);
        assert_eq!(arg.len(), 1);
        assert_eq!(arg.array_length(), 1);
        assert_eq!(arg.flags(), 0);
    }

    #[test]
    fn point_slice_reports_element_count_not_float_count() {
        let points = [0.0f32, 0.0, 0.0, 1.0, 0.0, 0.0];
        let arg = point_slice!("P", &points);
        assert_eq!(arg.type_tag(), Type::Point);
        assert_eq!(arg.len(), 2);
    }

    #[test]
    fn as_c_param_matches_the_arg() {
        let arg = f32!("fov", 45.0);
        let c = arg.as_c_param().expect("Arg always has a C view");
        assert_eq!(c.type_, Type::F32 as i32);
        assert_eq!(c.count, 1);
        assert_eq!(c.arraylength, 1);
        assert!(!c.data.is_null());
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-ffi-wrap param_value`
Expected: FAIL — `error[E0433]: failed to resolve: use of undeclared
crate or module 'param_value'`, because `lib.rs` does not declare it yet.

- [ ] **Step 3: Declare the module**

In `crates/nsi-ffi-wrap/src/lib.rs`, beside the other `mod` declarations:

```rust
mod param_value;
```

- [ ] **Step 4: Run test to verify it now fails for the right reason**

Run: `cargo test -p nsi-ffi-wrap param_value`
Expected: FAIL — `the method 'name' exists for struct 'Arg', but its
trait bounds were not satisfied` or `no method named 'type_tag'`. The
module resolves; the impl is missing.

- [ ] **Step 5: Write the implementation**

Prepend to `crates/nsi-ffi-wrap/src/param_value.rs`, above the test
module:

```rust
//! `ParamValue` bridge: exposes `Arg` through the renderer-agnostic
//! `nsi-trait` interface.
//!
//! Lives here rather than in `argument.rs` because it reaches into
//! `Arg`'s `pub(crate)` fields, and because keeping the trait bridge in
//! one small file makes it reviewable on its own.

use crate::argument::{Arg, ArgDataMethods, DataType};
use ::nsi_trait::{FfiParam, ParamValue, Type};

/// Map the crate-private `DataType` onto the public `nsi-trait` `Type`.
///
/// Both are `repr(i32)` over the same `NSIType` discriminants, so the
/// values already agree. The match is written out so that adding a
/// variant to either enum is a compile error rather than a silent
/// mismatch.
#[inline]
const fn to_trait_type(data_type: DataType) -> Type {
    match data_type {
        DataType::F32 => Type::F32,
        DataType::F64 => Type::F64,
        DataType::I32 => Type::I32,
        DataType::I64 => Type::I64,
        DataType::String => Type::String,
        DataType::Color => Type::Color,
        DataType::Point => Type::Point,
        DataType::Vector => Type::Vector,
        DataType::Normal => Type::Normal,
        DataType::MatrixF32 => Type::MatrixF32,
        DataType::MatrixF64 => Type::MatrixF64,
        DataType::Reference => Type::Reference,
    }
}

impl<'a, 'b> ParamValue for Arg<'a, 'b> {
    #[inline]
    fn name(&self) -> &str {
        self.name.as_str()
    }

    #[inline]
    fn type_tag(&self) -> Type {
        to_trait_type(self.data.type_())
    }

    #[inline]
    fn len(&self) -> usize {
        self.data.len()
    }

    #[inline]
    fn array_length(&self) -> usize {
        self.array_length.get()
    }

    #[inline]
    fn flags(&self) -> i32 {
        self.flags
    }

    fn as_c_param(&self) -> Option<FfiParam> {
        Some(FfiParam {
            name: self.name.as_char_ptr(),
            data: self.data.as_c_ptr(),
            type_: self.data.type_() as core::ffi::c_int,
            arraylength: self.array_length.get() as core::ffi::c_int,
            count: self.data.len(),
            flags: self.flags,
        })
    }
}
```

If `ArgDataMethods` or `DataType` are not visible from `param_value.rs`,
widen them from `pub(crate)` on their own declarations in `argument.rs` —
they are already crate-visible, so no public API changes.

- [ ] **Step 6: Run test to verify it passes**

Run: `cargo test -p nsi-ffi-wrap param_value`
Expected: PASS, 3 tests.

- [ ] **Step 7: Confirm nothing else regressed**

Run: `cargo test -p nsi-ffi-wrap`
Expected: PASS, no new failures against the pre-change baseline.

- [ ] **Step 8: Commit**

```bash
cd ~/code/crates/nsi
git add crates/nsi-ffi-wrap/src/param_value.rs crates/nsi-ffi-wrap/src/lib.rs
git commit -m "feat(nsi-ffi-wrap): implement ParamValue for Arg"
```

---

### Task 2: `Nsi` for `Context`

The nine inherent `Context` methods already have the trait's exact
parameter names, order and types. The only differences: they return `()`
rather than `Result`, and the trait's single-lifetime GAT must be pinned
to `Context`'s two lifetimes.

`Context<'a>` takes `ArgSlice<'_, 'a>` — the _first_ lifetime is the
transient call borrow, the _second_ is pegged to the context. So
`type Arg<'call> = crate::Arg<'call, 'a>`.

ɴsɪ's C API reports no per-call errors; failures arrive through the
`errorhandler` callback installed in `Context::new`. So there is no error
to surface and `Error = core::convert::Infallible`, which satisfies the
trait's `Error + Send + Sync + 'static` bound.

**Files:**

- Create: `crates/nsi-ffi-wrap/src/nsi_impl.rs`
- Modify: `crates/nsi-ffi-wrap/src/lib.rs`
- Test: `crates/nsi-ffi-wrap/src/nsi_impl.rs` (inline `mod tests`)

**Interfaces:**

- Consumes: `impl ParamValue for Arg` from Task 1; `Context<'a>` inherent
  methods `create`, `delete`, `set_attribute`, `set_attribute_at_time`,
  `delete_attribute`, `connect`, `disconnect`, `evaluate`,
  `render_control`, all returning `()`.
- Produces: `impl<'a> ::nsi_trait::Nsi for Context<'a>` with
  `type Arg<'call> = crate::Arg<'call, 'a>` and
  `type Error = core::convert::Infallible`. Task 3 depends on this.

- [ ] **Step 1: Write the failing test**

Create `crates/nsi-ffi-wrap/src/nsi_impl.rs` with only the test module:

```rust
#[cfg(test)]
mod tests {
    use crate::Context;
    use ::nsi_trait::Nsi;

    /// Compiles only if `Context` satisfies the full `Nsi` bound,
    /// including `Send + Sync` and the GAT. This is the real assertion;
    /// it needs no renderer.
    fn assert_is_nsi<T: Nsi>() {}

    #[test]
    fn context_implements_nsi() {
        assert_is_nsi::<Context<'static>>();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-ffi-wrap nsi_impl`
Expected: FAIL — `failed to resolve: use of undeclared crate or module
'nsi_impl'`.

- [ ] **Step 3: Declare the module**

In `crates/nsi-ffi-wrap/src/lib.rs`:

```rust
mod nsi_impl;
```

- [ ] **Step 4: Run test to verify it fails for the right reason**

Run: `cargo test -p nsi-ffi-wrap nsi_impl`
Expected: FAIL — `the trait bound 'Context<'static>: Nsi' is not
satisfied`.

- [ ] **Step 5: Write the implementation**

Prepend to `crates/nsi-ffi-wrap/src/nsi_impl.rs`:

```rust
//! `Nsi` implementation for the 3Delight-backed [`Context`].
//!
//! Every method delegates to the inherent method of the same name. The
//! signatures already match; the only adaptation is wrapping the unit
//! return in `Ok`.
//!
//! The ɴsɪ C API surfaces no per-call error. Failures are delivered to
//! the `errorhandler` callback installed by `Context::new`, so there is
//! nothing to return and the error type is [`Infallible`].

use crate::{Arg, Context};
use ::nsi_trait::{Action, Nsi};
use core::convert::Infallible;

impl<'a> Nsi for Context<'a> {
    /// `'call` is the transient borrow; `'a` is pinned to this context,
    /// which is what `ArgData`'s second lifetime means.
    type Arg<'call>
        = Arg<'call, 'a>
    where
        Self: 'call;

    type Error = Infallible;

    fn create(
        &self,
        handle: &str,
        node_type: &str,
        args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        Context::create(self, handle, node_type, args);
        Ok(())
    }

    fn delete(
        &self,
        handle: &str,
        args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        Context::delete(self, handle, args);
        Ok(())
    }

    fn set_attribute(
        &self,
        handle: &str,
        args: &[Self::Arg<'_>],
    ) -> Result<(), Self::Error> {
        Context::set_attribute(self, handle, args);
        Ok(())
    }

    fn set_attribute_at_time(
        &self,
        handle: &str,
        time: f64,
        args: &[Self::Arg<'_>],
    ) -> Result<(), Self::Error> {
        Context::set_attribute_at_time(self, handle, time, args);
        Ok(())
    }

    fn delete_attribute(
        &self,
        handle: &str,
        name: &str,
    ) -> Result<(), Self::Error> {
        Context::delete_attribute(self, handle, name);
        Ok(())
    }

    fn connect(
        &self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
        args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        Context::connect(self, from, from_attr, to, to_attr, args);
        Ok(())
    }

    fn disconnect(
        &self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
    ) -> Result<(), Self::Error> {
        Context::disconnect(self, from, from_attr, to, to_attr);
        Ok(())
    }

    fn evaluate(&self, args: &[Self::Arg<'_>]) -> Result<(), Self::Error> {
        Context::evaluate(self, args);
        Ok(())
    }

    fn render_control(
        &self,
        action: Action,
        args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        Context::render_control(self, action, args);
        Ok(())
    }
}
```

`ArgSlice<'x, 'a>` is a type alias for `[Arg<'x, 'a>]`, so
`&[Self::Arg<'_>]` and `&ArgSlice<'_, 'a>` are the same type and the
delegations need no conversion.

- [ ] **Step 6: Run test to verify it passes**

Run: `cargo test -p nsi-ffi-wrap nsi_impl`
Expected: PASS, 1 test.

- [ ] **Step 7: Confirm the whole workspace still builds**

Run: `cargo build --workspace`
Expected: success, no warnings introduced.

- [ ] **Step 8: Commit**

```bash
cd ~/code/crates/nsi
git add crates/nsi-ffi-wrap/src/nsi_impl.rs crates/nsi-ffi-wrap/src/lib.rs
git commit -m "feat(nsi-ffi-wrap): implement Nsi for Context"
```

---

### Task 3: Make a consumer generic over `T: Nsi`

`monster-step-viewer` is the target, not akatela: it is 4873 lines
against akatela's ~7200, uses the identical ɴsɪ surface, and exercises
the NURBS path we need later.

This task proves the seam is usable without changing behaviour. The
render output must be unchanged — that is the whole test.

**Files:**

- Modify: `~/code/crates/monster-step-viewer/src/nsi_render/mod.rs:138`
  (`context: nsi::Context<'static>`), `:156` (`Context::new`), `:181`
  (`ctx: &nsi::Context`)
- Modify: `~/code/crates/monster-step-viewer/src/nsi_render/brep.rs`,
  `export.rs` — same substitution wherever `&nsi::Context` appears
- Modify: `~/code/crates/monster-step-viewer/Cargo.toml` — add
  `nsi-trait`

**Interfaces:**

- Consumes: `impl Nsi for Context<'a>` from Task 2.
- Produces: helper functions generic over `R: Nsi` rather than taking
  `&nsi::Context`. Signatures change from
  `fn setup(ctx: &nsi::Context, ...)` to
  `fn setup<R: Nsi>(ctx: &R, ...)`.

- [ ] **Step 1: Capture the golden image before touching anything**

```bash
cd ~/code/crates/monster-step-viewer
cargo run --release --example parse_test -- assets/ >/dev/null 2>&1 || true
cargo test --release 2>&1 | tee /tmp/msv-baseline.txt
```

Record a rendered PNG from the existing 3Delight path into
`/tmp/msv-golden.png` by whatever entry point the viewer already exposes.
This is the artifact Step 6 compares against; without it this task has no
test.

- [ ] **Step 2: Add the dependency**

In `~/code/crates/monster-step-viewer/Cargo.toml`:

```toml
nsi-trait = { version = "0.3", path = "../nsi/crates/nsi-trait" }
```

- [ ] **Step 3: Make the free functions generic**

For each helper currently taking `&nsi::Context`, change the signature
and add the import. For `nsi_render/mod.rs:181`:

```rust
use nsi_trait::Nsi;

fn setup_scene<R: Nsi>(
    ctx: &R,
    handles: &Handles,
) -> Result<(), R::Error> {
    ctx.create(&handles.camera_xform, nsi::TRANSFORM, None)?;
    ctx.connect(&handles.camera_xform, None, nsi::ROOT, "objects", None)?;
    // ... remaining body unchanged except for `?` on each call
    Ok(())
}
```

Each `ctx.create(...)` / `ctx.connect(...)` / `ctx.set_attribute(...)`
call now returns `Result`, so append `?` and give the function a
`Result<(), R::Error>` return type. The node-type constants
(`nsi::TRANSFORM`, `nsi::ROOT`, …) and the argument macros
(`nsi::f32!`, `nsi::point_slice!`) are unchanged — they still produce
`nsi_ffi_wrap::Arg`, which is `R::Arg<'_>` for every backend per the
spec amendment above.

- [ ] **Step 4: Leave the struct field concrete**

Do **not** make `NsiRenderer` generic in this task. `context:
nsi::Context<'static>` at `mod.rs:138` stays as it is. Making the
owning struct generic ripples into every caller and the render thread at
`mod.rs:676`; that is Phase 3 work, once a second backend exists to
justify it. This task only proves the free functions compile against the
trait.

- [ ] **Step 5: Build**

Run: `cargo build --release`
Expected: success. Fix any missed `?` — the compiler names every call
site.

- [ ] **Step 6: Verify the render is unchanged**

Re-render the same scene and compare against `/tmp/msv-golden.png`:

```bash
cmp /tmp/msv-golden.png /tmp/msv-after.png && echo IDENTICAL
```

Expected: `IDENTICAL`. This task must be a pure refactor; any pixel
difference means a call was reordered or dropped.

- [ ] **Step 7: Commit**

```bash
cd ~/code/crates/monster-step-viewer
git add Cargo.toml src/nsi_render/
git commit -m "refactor(nsi_render): make scene helpers generic over Nsi"
```

---

### Task 4: `nsi-mitsuba` workspace and `OwnedArg`

The recorder outlives every call it receives, so it cannot hold borrowed
`Arg`s. `OwnedArg` is the owned mirror.

Colour, point, vector, normal and matrix types all store `f32`/`f64` and
differ only by tag, so `OwnedData` needs one variant per storage
representation, not one per ɴsɪ type.

**Files:**

- Create: `Cargo.toml`, `crates/nsi-mitsuba/Cargo.toml`,
  `crates/nsi-mitsuba/src/lib.rs`, `crates/nsi-mitsuba/src/owned.rs`
- Test: `crates/nsi-mitsuba/src/owned.rs` (inline `mod tests`)

**Interfaces:**

- Consumes: `ParamValue` from Task 1; `nsi_ffi_wrap::Arg`.
- Produces: `pub struct OwnedArg { pub name: String, pub type_tag: Type,
pub array_length: usize, pub flags: i32, pub data: OwnedData }`,
  `pub enum OwnedData`, and
  `pub fn OwnedArg::from_param<P: ParamValue>(p: &P) -> Self`.
  Tasks 5 and 8 use both.

- [ ] **Step 1: Create the workspace**

`~/code/crates/nsi-mitsuba/Cargo.toml`:

```toml
[workspace]
members = ["crates/*"]
resolver = "3"
```

`~/code/crates/nsi-mitsuba/crates/nsi-mitsuba/Cargo.toml`:

```toml
[package]
name = "nsi-mitsuba"
version = "0.1.0"
edition = "2024"
license = "MIT OR Apache-2.0 OR Zlib"
description = "Mitsuba 3 backend for the Nodal Scene Interface – ɴsɪ."
repository = "https://github.com/virtualritz/nsi-mitsuba/"

[dependencies]
indexmap = "2"
nsi-ffi-wrap = { version = "0.9", path = "../../../nsi/crates/nsi-ffi-wrap" }
nsi-trait = { version = "0.3", path = "../../../nsi/crates/nsi-trait" }
```

`~/code/crates/nsi-mitsuba/crates/nsi-mitsuba/src/lib.rs`:

```rust
//! A Mitsuba 3 backend for the Nodal Scene Interface.
//!
//! This crate records an ɴsɪ scene — nodes, attributes and classified
//! connections — and replays it. Recording is pure Rust and needs no
//! renderer present.

mod owned;

pub use owned::{OwnedArg, OwnedData};
```

- [ ] **Step 2: Write the failing test**

Append to `crates/nsi-mitsuba/src/owned.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use nsi_ffi_wrap as nsi;
    use nsi_trait::Type;

    #[test]
    fn owns_a_single_f32() {
        let arg = nsi::f32!("roughness", 0.3);
        let owned = OwnedArg::from_param(&arg);
        assert_eq!(owned.name, "roughness");
        assert_eq!(owned.type_tag, Type::F32);
        assert_eq!(owned.data, OwnedData::F32(vec![0.3]));
    }

    #[test]
    fn owns_a_point_slice_with_all_floats() {
        let points = [0.0f32, 0.0, 0.0, 1.0, 0.0, 0.0];
        let arg = nsi::point_slice!("P", &points);
        let owned = OwnedArg::from_param(&arg);
        assert_eq!(owned.type_tag, Type::Point);
        // Two points, three floats each: the storage keeps all six.
        assert_eq!(owned.data, OwnedData::F32(points.to_vec()));
    }

    #[test]
    fn owns_a_string() {
        let arg = nsi::string!("shaderfilename", "dlPrincipled");
        let owned = OwnedArg::from_param(&arg);
        assert_eq!(owned.type_tag, Type::String);
        assert_eq!(
            owned.data,
            OwnedData::String(vec!["dlPrincipled".to_string()])
        );
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cargo test -p nsi-mitsuba owned`
Expected: FAIL — `cannot find type 'OwnedArg' in this scope`.

- [ ] **Step 4: Write the implementation**

Prepend to `crates/nsi-mitsuba/src/owned.rs`:

```rust
//! Owned mirrors of borrowed ɴsɪ arguments.
//!
//! The recorder outlives the calls that feed it, so it cannot hold a
//! borrowed `Arg`. `OwnedArg` copies the payload out.

use core::ffi::c_void;
use nsi_trait::{ParamValue, Type};

/// An ɴsɪ argument's payload, owned.
///
/// Variants are storage representations, not ɴsɪ types: colour, point,
/// vector, normal and 4x4 `f32` matrices all live in [`OwnedData::F32`]
/// and are told apart by [`OwnedArg::type_tag`].
#[derive(Debug, Clone, PartialEq)]
pub enum OwnedData {
    F32(Vec<f32>),
    F64(Vec<f64>),
    I32(Vec<i32>),
    I64(Vec<i64>),
    String(Vec<String>),
    /// Raw host pointers. ɴsɪ calls this `Reference` (`Pointer` in the C
    /// API); it is not an object link and is never forwarded to a
    /// renderer. Stored so output-driver callbacks survive a replay.
    Reference(Vec<*const c_void>),
}

/// A recorded ɴsɪ argument.
#[derive(Debug, Clone, PartialEq)]
pub struct OwnedArg {
    pub name: String,
    pub type_tag: Type,
    pub array_length: usize,
    pub flags: i32,
    pub data: OwnedData,
}

impl OwnedArg {
    /// Copy a borrowed parameter into owned storage.
    pub fn from_param<P: ParamValue>(param: &P) -> Self {
        let type_tag = param.type_tag();
        let count = param.len();
        // Total scalars = element count x components per element.
        let scalars = count * components_per_element(type_tag);

        let c = param
            .as_c_param()
            .expect("nsi-ffi-wrap Arg always yields a C view");

        // SAFETY: `c.data` points at `scalars` values of the type named
        // by `type_tag`, valid while `param` lives, which is this call.
        let data = unsafe {
            match type_tag {
                Type::F32
                | Type::Color
                | Type::Point
                | Type::Vector
                | Type::Normal
                | Type::MatrixF32 => OwnedData::F32(
                    core::slice::from_raw_parts(
                        c.data as *const f32,
                        scalars,
                    )
                    .to_vec(),
                ),
                Type::F64 | Type::MatrixF64 => OwnedData::F64(
                    core::slice::from_raw_parts(
                        c.data as *const f64,
                        scalars,
                    )
                    .to_vec(),
                ),
                Type::I32 => OwnedData::I32(
                    core::slice::from_raw_parts(
                        c.data as *const i32,
                        scalars,
                    )
                    .to_vec(),
                ),
                Type::I64 => OwnedData::I64(
                    core::slice::from_raw_parts(
                        c.data as *const i64,
                        scalars,
                    )
                    .to_vec(),
                ),
                Type::String => {
                    let ptrs = core::slice::from_raw_parts(
                        c.data as *const *const core::ffi::c_char,
                        scalars,
                    );
                    OwnedData::String(
                        ptrs.iter()
                            .map(|p| {
                                core::ffi::CStr::from_ptr(*p)
                                    .to_string_lossy()
                                    .into_owned()
                            })
                            .collect(),
                    )
                }
                Type::Reference => OwnedData::Reference(
                    core::slice::from_raw_parts(
                        c.data as *const *const c_void,
                        scalars,
                    )
                    .to_vec(),
                ),
                Type::Invalid => OwnedData::F32(Vec::new()),
            }
        };

        Self {
            name: param.name().to_string(),
            type_tag,
            array_length: param.array_length(),
            flags: param.flags(),
            data,
        }
    }
}

/// Scalars per element for each ɴsɪ type.
#[inline]
const fn components_per_element(type_tag: Type) -> usize {
    match type_tag {
        Type::Color | Type::Point | Type::Vector | Type::Normal => 3,
        Type::MatrixF32 | Type::MatrixF64 => 16,
        _ => 1,
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cargo test -p nsi-mitsuba owned`
Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
cd ~/code/crates/nsi-mitsuba
git add Cargo.toml crates/
git commit -m "feat: add nsi-mitsuba workspace and OwnedArg"
```

---

### Task 5: The connection classifier

The spec names this the highest-consequence component: a misclassified
edge does not error, it renders wrongly. So the classifier is exhaustive
over `to_attr` and rejects anything it does not recognise.

**Files:**

- Create: `crates/nsi-mitsuba/src/edge.rs`
- Modify: `crates/nsi-mitsuba/src/lib.rs`
- Test: `crates/nsi-mitsuba/tests/classifier.rs`

**Interfaces:**

- Consumes: nothing from earlier tasks.
- Produces: `pub enum EdgeKind`, `pub struct Edge`,
  `pub fn classify(from_attr: Option<&str>, to_attr: &str) ->
Result<EdgeKind, ClassifyError>`, `pub struct ClassifyError`.
  Tasks 6 and 8 use these.

- [ ] **Step 1: Write the failing test**

Create `crates/nsi-mitsuba/tests/classifier.rs`:

```rust
use nsi_mitsuba::{EdgeKind, classify};

#[test]
fn scene_membership() {
    assert_eq!(classify(None, "objects").unwrap(), EdgeKind::SceneMember);
}

#[test]
fn geometry_attributes_dissolve() {
    assert_eq!(
        classify(None, "geometryattributes").unwrap(),
        EdgeKind::AttributeBinding
    );
}

#[test]
fn surface_shader_is_a_material_reference() {
    assert_eq!(
        classify(None, "surfaceshader").unwrap(),
        EdgeKind::SurfaceShader
    );
}

#[test]
fn instancing_source_models() {
    assert_eq!(
        classify(None, "sourcemodels").unwrap(),
        EdgeKind::InstanceSource
    );
}

#[test]
fn output_chain() {
    assert_eq!(classify(None, "screens").unwrap(), EdgeKind::Screen);
    assert_eq!(
        classify(None, "outputlayers").unwrap(),
        EdgeKind::OutputLayer
    );
    assert_eq!(
        classify(None, "outputdrivers").unwrap(),
        EdgeKind::OutputDriver
    );
}

#[test]
fn a_named_output_port_is_a_shader_network_edge() {
    let kind = classify(Some("outColor"), "inColor").unwrap();
    assert_eq!(
        kind,
        EdgeKind::ShaderNetwork {
            from_port: "outColor".to_string(),
            to_port: "inColor".to_string(),
        }
    );
}

/// The property that matters: an unknown destination must be an error,
/// never a silently-defaulted reference.
#[test]
fn unknown_to_attr_is_rejected() {
    let err = classify(None, "somethingnobodyimplemented").unwrap_err();
    assert!(err.to_string().contains("somethingnobodyimplemented"));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-mitsuba --test classifier`
Expected: FAIL — `unresolved import 'nsi_mitsuba::classify'`.

- [ ] **Step 3: Write the implementation**

Create `crates/nsi-mitsuba/src/edge.rs`:

```rust
//! Connection classification.
//!
//! An ɴsɪ connection is a typed multi-relation: its meaning depends on
//! the destination attribute. Only [`EdgeKind::SurfaceShader`] and
//! [`EdgeKind::ShaderNetwork`] become Mitsuba references; the rest are
//! scene membership, transform composition, instancing, or output
//! routing.
//!
//! Unrecognised destinations are rejected. Defaulting them to a
//! reference is exactly the silent failure this module exists to
//! prevent.

use core::fmt;

/// What an ɴsɪ connection means, once classified.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EdgeKind {
    /// `X -> .root "objects"`, or a transform chain link. Membership and
    /// hierarchy are the same ɴsɪ attribute; which one it is depends on
    /// whether the destination is `.root`, so the recorder resolves that
    /// when it walks the graph, not here.
    SceneMember,
    /// `attributes -> geo "geometryattributes"`. The attributes node is
    /// dissolved at flush time.
    AttributeBinding,
    /// `shader -> attributes "surfaceshader"`. Becomes the shape's bsdf.
    SurfaceShader,
    /// `geo -> instances "sourcemodels"`. Becomes shapegroup + instance.
    InstanceSource,
    /// `screen -> camera "screens"`.
    Screen,
    /// `outputlayer -> screen "outputlayers"`.
    OutputLayer,
    /// `outputdriver -> outputlayer "outputdrivers"`.
    OutputDriver,
    /// An attribute-to-attribute shader network edge, naming ports on
    /// both ends. Mitsuba references point at whole objects, so the port
    /// names must be resolved during flush.
    ShaderNetwork { from_port: String, to_port: String },
}

/// A recorded, classified connection.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Edge {
    pub from: String,
    pub to: String,
    pub kind: EdgeKind,
}

/// An ɴsɪ connection whose destination attribute has no mapping.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClassifyError {
    pub to_attr: String,
}

impl fmt::Display for ClassifyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "unmapped ɴsɪ connection destination attribute {:?}; refusing \
             to guess -- add a case to nsi_mitsuba::classify",
            self.to_attr
        )
    }
}

impl core::error::Error for ClassifyError {}

/// Classify a connection by its destination attribute.
///
/// A `from_attr` means the source names an output port, which only
/// happens for shader-network edges.
pub fn classify(
    from_attr: Option<&str>,
    to_attr: &str,
) -> Result<EdgeKind, ClassifyError> {
    // A named source port is always a shader network edge, whatever the
    // destination is called.
    if let Some(from_port) = from_attr {
        return Ok(EdgeKind::ShaderNetwork {
            from_port: from_port.to_string(),
            to_port: to_attr.to_string(),
        });
    }

    Ok(match to_attr {
        "objects" => EdgeKind::SceneMember,
        "geometryattributes" => EdgeKind::AttributeBinding,
        "surfaceshader" => EdgeKind::SurfaceShader,
        "sourcemodels" => EdgeKind::InstanceSource,
        "screens" => EdgeKind::Screen,
        "outputlayers" => EdgeKind::OutputLayer,
        "outputdrivers" => EdgeKind::OutputDriver,
        other => {
            return Err(ClassifyError {
                to_attr: other.to_string(),
            });
        }
    })
}
```

In `crates/nsi-mitsuba/src/lib.rs`:

```rust
mod edge;

pub use edge::{ClassifyError, Edge, EdgeKind, classify};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p nsi-mitsuba --test classifier`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/code/crates/nsi-mitsuba
git add crates/nsi-mitsuba/src/edge.rs crates/nsi-mitsuba/src/lib.rs crates/nsi-mitsuba/tests/classifier.rs
git commit -m "feat: add exhaustive ɴsɪ connection classifier"
```

---

### Task 6: The scene tables

**Files:**

- Create: `crates/nsi-mitsuba/src/scene.rs`
- Modify: `crates/nsi-mitsuba/src/lib.rs`
- Test: `crates/nsi-mitsuba/src/scene.rs` (inline `mod tests`)

**Interfaces:**

- Consumes: `OwnedArg` (Task 4), `Edge` (Task 5).
- Produces: `pub struct Node { pub node_type: String, pub attrs:
IndexMap<String, OwnedArg>, pub time_attrs: Vec<(f64, IndexMap<String,
OwnedArg>)> }` and `pub struct Scene { pub nodes: IndexMap<String,
Node>, pub edges: Vec<Edge> }` with methods `create`, `delete`,
  `set_attribute`, `set_attribute_at_time`, `delete_attribute`.
  Task 7 wraps these.

- [ ] **Step 1: Write the failing test**

Append to `crates/nsi-mitsuba/src/scene.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::OwnedData;
    use nsi_trait::Type;

    fn arg(name: &str, value: f32) -> OwnedArg {
        OwnedArg {
            name: name.to_string(),
            type_tag: Type::F32,
            array_length: 1,
            flags: 0,
            data: OwnedData::F32(vec![value]),
        }
    }

    #[test]
    fn creates_and_finds_a_node() {
        let mut scene = Scene::default();
        scene.create("cam", "perspectivecamera");
        assert_eq!(scene.nodes["cam"].node_type, "perspectivecamera");
    }

    #[test]
    fn set_attribute_overwrites_by_name() {
        let mut scene = Scene::default();
        scene.create("cam", "perspectivecamera");
        scene.set_attribute("cam", vec![arg("fov", 45.0)]);
        scene.set_attribute("cam", vec![arg("fov", 60.0)]);
        assert_eq!(scene.nodes["cam"].attrs.len(), 1);
        assert_eq!(
            scene.nodes["cam"].attrs["fov"].data,
            OwnedData::F32(vec![60.0])
        );
    }

    #[test]
    fn time_samples_are_kept_separately_and_sorted() {
        let mut scene = Scene::default();
        scene.create("xf", "transform");
        scene.set_attribute_at_time("xf", 1.0, vec![arg("t", 1.0)]);
        scene.set_attribute_at_time("xf", 0.0, vec![arg("t", 0.0)]);
        let times: Vec<f64> = scene.nodes["xf"]
            .time_attrs
            .iter()
            .map(|(t, _)| *t)
            .collect();
        assert_eq!(times, vec![0.0, 1.0]);
        assert!(scene.nodes["xf"].attrs.is_empty());
    }

    #[test]
    fn delete_removes_the_node_and_its_edges() {
        let mut scene = Scene::default();
        scene.create("xf", "transform");
        scene.create("mesh", "mesh");
        scene
            .connect("mesh", None, "xf", "objects")
            .expect("known attribute");
        scene.delete("xf");
        assert!(!scene.nodes.contains_key("xf"));
        assert!(scene.edges.is_empty());
    }

    #[test]
    fn delete_attribute_removes_one_key() {
        let mut scene = Scene::default();
        scene.create("cam", "perspectivecamera");
        scene.set_attribute("cam", vec![arg("fov", 45.0), arg("fs", 1.0)]);
        scene.delete_attribute("cam", "fov");
        assert!(!scene.nodes["cam"].attrs.contains_key("fov"));
        assert!(scene.nodes["cam"].attrs.contains_key("fs"));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-mitsuba scene`
Expected: FAIL — `cannot find type 'Scene' in this scope`.

- [ ] **Step 3: Write the implementation**

Prepend to `crates/nsi-mitsuba/src/scene.rs`:

```rust
//! Node and attribute tables.
//!
//! `IndexMap` throughout: replaying a scene in a different order than it
//! was recorded would make the stream diff in Task 8 meaningless.

use crate::{ClassifyError, Edge, OwnedArg, classify};
use indexmap::IndexMap;

/// One ɴsɪ node.
#[derive(Debug, Clone, Default)]
pub struct Node {
    pub node_type: String,
    /// Attributes set with `set_attribute`, keyed by name.
    pub attrs: IndexMap<String, OwnedArg>,
    /// Attributes set with `set_attribute_at_time`, sorted by time.
    /// Motion samples are kept apart from static attributes because
    /// transform composition has to happen per sample.
    pub time_attrs: Vec<(f64, IndexMap<String, OwnedArg>)>,
}

/// The recorded scene graph.
#[derive(Debug, Clone, Default)]
pub struct Scene {
    pub nodes: IndexMap<String, Node>,
    pub edges: Vec<Edge>,
}

impl Scene {
    /// Create a node. Re-creating an existing handle updates its type,
    /// matching ɴsɪ's tolerance of repeated identical `create` calls.
    pub fn create(&mut self, handle: &str, node_type: &str) {
        let node = self.nodes.entry(handle.to_string()).or_default();
        node.node_type = node_type.to_string();
    }

    /// Delete a node and every edge that touches it.
    pub fn delete(&mut self, handle: &str) {
        self.nodes.shift_remove(handle);
        self.edges.retain(|e| e.from != handle && e.to != handle);
    }

    /// Set static attributes, overwriting by name.
    pub fn set_attribute(&mut self, handle: &str, args: Vec<OwnedArg>) {
        let node = self.nodes.entry(handle.to_string()).or_default();
        for arg in args {
            node.attrs.insert(arg.name.clone(), arg);
        }
    }

    /// Set attributes at one motion sample, keeping samples time-sorted.
    pub fn set_attribute_at_time(
        &mut self,
        handle: &str,
        time: f64,
        args: Vec<OwnedArg>,
    ) {
        let node = self.nodes.entry(handle.to_string()).or_default();

        let slot = match node
            .time_attrs
            .iter()
            .position(|(t, _)| *t == time)
        {
            Some(i) => i,
            None => {
                // Insertion sort keeps samples ordered without needing a
                // total order on f64.
                let i = node
                    .time_attrs
                    .iter()
                    .position(|(t, _)| *t > time)
                    .unwrap_or(node.time_attrs.len());
                node.time_attrs.insert(i, (time, IndexMap::new()));
                i
            }
        };

        for arg in args {
            node.time_attrs[slot].1.insert(arg.name.clone(), arg);
        }
    }

    /// Remove one attribute by name. Silent when absent, as ɴsɪ is.
    pub fn delete_attribute(&mut self, handle: &str, name: &str) {
        if let Some(node) = self.nodes.get_mut(handle) {
            node.attrs.shift_remove(name);
            for (_, attrs) in &mut node.time_attrs {
                attrs.shift_remove(name);
            }
        }
    }

    /// Classify and record a connection.
    pub fn connect(
        &mut self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
    ) -> Result<(), ClassifyError> {
        let kind = classify(from_attr, to_attr)?;
        self.edges.push(Edge {
            from: from.to_string(),
            to: to.to_string(),
            kind,
        });
        Ok(())
    }

    /// Remove a connection. Silent when absent, as ɴsɪ is.
    pub fn disconnect(
        &mut self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
    ) -> Result<(), ClassifyError> {
        let kind = classify(from_attr, to_attr)?;
        self.edges
            .retain(|e| !(e.from == from && e.to == to && e.kind == kind));
        Ok(())
    }
}
```

In `crates/nsi-mitsuba/src/lib.rs`:

```rust
mod scene;

pub use scene::{Node, Scene};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p nsi-mitsuba scene`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/code/crates/nsi-mitsuba
git add crates/nsi-mitsuba/src/scene.rs crates/nsi-mitsuba/src/lib.rs
git commit -m "feat: add ɴsɪ scene node and attribute tables"
```

---

### Task 7: `Recorder` and the `Nsi` impl

**Files:**

- Create: `crates/nsi-mitsuba/src/recorder.rs`
- Modify: `crates/nsi-mitsuba/src/lib.rs`
- Test: `crates/nsi-mitsuba/src/recorder.rs` (inline `mod tests`)

**Interfaces:**

- Consumes: `Scene` (Task 6), `OwnedArg::from_param` (Task 4),
  `ClassifyError` (Task 5).
- Produces: `pub struct Recorder<'ctx>`, `Recorder::new()`,
  `Recorder::scene(&self) -> MutexGuard<'_, Scene>`,
  `Recorder::render_state(&self) -> RenderState`, `pub enum RenderState`,
  and `impl<'ctx> Nsi for Recorder<'ctx>` with
  `type Arg<'call> = nsi_ffi_wrap::Arg<'call, 'ctx>`,
  `type Error = ClassifyError`. Task 8 uses `scene()`.

- [ ] **Step 1: Write the failing test**

Append to `crates/nsi-mitsuba/src/recorder.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use nsi_ffi_wrap as nsi;
    use nsi_trait::{Action, Nsi};

    fn assert_is_nsi<T: Nsi>() {}

    #[test]
    fn recorder_implements_nsi() {
        assert_is_nsi::<Recorder<'static>>();
    }

    #[test]
    fn records_a_node_and_its_attribute() {
        let r = Recorder::new();
        r.create("cam", "perspectivecamera", None).unwrap();
        r.set_attribute("cam", &[nsi::f32!("fov", 45.0)]).unwrap();

        let scene = r.scene();
        assert_eq!(scene.nodes["cam"].node_type, "perspectivecamera");
        assert_eq!(scene.nodes["cam"].attrs["fov"].name, "fov");
    }

    #[test]
    fn an_unmapped_connection_is_an_error() {
        let r = Recorder::new();
        r.create("a", "transform", None).unwrap();
        r.create("b", "transform", None).unwrap();
        let err = r.connect("a", None, "b", "nonsense", None).unwrap_err();
        assert_eq!(err.to_attr, "nonsense");
    }

    #[test]
    fn render_control_drives_the_state_machine() {
        let r = Recorder::new();
        assert_eq!(r.render_state(), RenderState::Idle);
        r.render_control(Action::Start, None).unwrap();
        assert_eq!(r.render_state(), RenderState::Running);
        r.render_control(Action::Suspend, None).unwrap();
        assert_eq!(r.render_state(), RenderState::Suspended);
        r.render_control(Action::Resume, None).unwrap();
        assert_eq!(r.render_state(), RenderState::Running);
        r.render_control(Action::Stop, None).unwrap();
        assert_eq!(r.render_state(), RenderState::Idle);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-mitsuba recorder`
Expected: FAIL — `cannot find type 'Recorder' in this scope`.

- [ ] **Step 3: Write the implementation**

Prepend to `crates/nsi-mitsuba/src/recorder.rs`:

```rust
//! The ɴsɪ recorder.
//!
//! `Nsi` takes `&self` everywhere, so the scene lives behind a `Mutex`.

use crate::{ClassifyError, OwnedArg, Scene};
use nsi_ffi_wrap::Arg;
use nsi_trait::{Action, Nsi, ParamValue};
use core::marker::PhantomData;
use std::sync::{Mutex, MutexGuard};

/// Where the render is in its lifecycle.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RenderState {
    Idle,
    Running,
    Suspended,
}

/// Records an ɴsɪ scene without rendering it.
///
/// # Lifetime
///
/// `'ctx` mirrors [`nsi_ffi_wrap::Context`]'s lifetime parameter: it
/// bounds borrowed Rust data handed in through `Reference`,
/// `ReferenceSlice` and `Callback` arguments. The recorder **stores**
/// those raw pointers in [`OwnedData::Reference`] so they survive to
/// replay, so the data must outlive the recorder — exactly the
/// guarantee `Context` needs, for exactly the same reason.
///
/// Do not be tempted to write `Arg<'call, 'call>` here, as
/// `FfiApiAdapter` does. That is sound for the adapter, whose args come
/// from C parameters the C side copies immediately, and unsound here,
/// where the pointer outlives the call.
///
/// `PhantomData<*mut &'ctx ()>` makes the recorder invariant in `'ctx`,
/// matching `InnerContext`. Most callers want `Recorder<'static>`.
#[derive(Debug, Default)]
pub struct Recorder<'ctx> {
    scene: Mutex<Scene>,
    state: Mutex<RenderState>,
    _marker: PhantomData<*mut &'ctx ()>,
}

impl Default for RenderState {
    fn default() -> Self {
        Self::Idle
    }
}

impl<'ctx> Recorder<'ctx> {
    pub fn new() -> Self {
        Self::default()
    }

    /// Borrow the recorded scene.
    pub fn scene(&self) -> MutexGuard<'_, Scene> {
        self.scene.lock().expect("scene mutex poisoned")
    }

    /// The current render state.
    pub fn render_state(&self) -> RenderState {
        *self.state.lock().expect("state mutex poisoned")
    }

    fn own(args: &[Arg<'_, '_>]) -> Vec<OwnedArg> {
        args.iter().map(OwnedArg::from_param).collect()
    }
}

impl<'ctx> Nsi for Recorder<'ctx> {
    type Arg<'call>
        = Arg<'call, 'ctx>
    where
        Self: 'call;

    type Error = ClassifyError;

    fn create(
        &self,
        handle: &str,
        node_type: &str,
        _args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        self.scene().create(handle, node_type);
        Ok(())
    }

    fn delete(
        &self,
        handle: &str,
        _args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        self.scene().delete(handle);
        Ok(())
    }

    fn set_attribute(
        &self,
        handle: &str,
        args: &[Self::Arg<'_>],
    ) -> Result<(), Self::Error> {
        let owned = Self::own(args);
        self.scene().set_attribute(handle, owned);
        Ok(())
    }

    fn set_attribute_at_time(
        &self,
        handle: &str,
        time: f64,
        args: &[Self::Arg<'_>],
    ) -> Result<(), Self::Error> {
        let owned = Self::own(args);
        self.scene().set_attribute_at_time(handle, time, owned);
        Ok(())
    }

    fn delete_attribute(
        &self,
        handle: &str,
        name: &str,
    ) -> Result<(), Self::Error> {
        self.scene().delete_attribute(handle, name);
        Ok(())
    }

    fn connect(
        &self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
        _args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        self.scene().connect(from, from_attr, to, to_attr)
    }

    fn disconnect(
        &self,
        from: &str,
        from_attr: Option<&str>,
        to: &str,
        to_attr: &str,
    ) -> Result<(), Self::Error> {
        self.scene().disconnect(from, from_attr, to, to_attr)
    }

    fn evaluate(
        &self,
        _args: &[Self::Arg<'_>],
    ) -> Result<(), Self::Error> {
        // Procedurals and Lua are out of scope until Phase 3; recording
        // them would imply an execution model we have not designed.
        Ok(())
    }

    fn render_control(
        &self,
        action: Action,
        _args: Option<&[Self::Arg<'_>]>,
    ) -> Result<(), Self::Error> {
        let mut state = self.state.lock().expect("state mutex poisoned");
        *state = match (action, *state) {
            (Action::Start, _) => RenderState::Running,
            (Action::Suspend, RenderState::Running) => {
                RenderState::Suspended
            }
            (Action::Resume, RenderState::Suspended) => {
                RenderState::Running
            }
            (Action::Stop, _) => RenderState::Idle,
            // Wait and Synchronize do not change state; a no-op render
            // completes immediately.
            (_, current) => current,
        };
        Ok(())
    }
}
```

`#[derive(Default)]` on `Recorder` requires `Mutex<RenderState>:
Default`, which requires `RenderState: Default` — that is what the
manual `impl Default for RenderState` above provides. `RenderState`
derives `Copy` but not `Default`, so there is no conflict between the
derive and the manual impl.

In `crates/nsi-mitsuba/src/lib.rs`:

```rust
mod recorder;

pub use recorder::{Recorder, RenderState};
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p nsi-mitsuba recorder`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
cd ~/code/crates/nsi-mitsuba
git add crates/nsi-mitsuba/src/recorder.rs crates/nsi-mitsuba/src/lib.rs
git commit -m "feat: add Recorder implementing Nsi"
```

---

### Task 8: `.nsi` stream emitter and the 3Delight diff

The spec's Phase 2 gate: replay a recorded scene as an `.nsi` stream and
compare it against what 3Delight writes for the same calls. This is what
proves the recorder is faithful before any C++ exists.

**Files:**

- Create: `crates/nsi-mitsuba/src/stream.rs`
- Modify: `crates/nsi-mitsuba/src/lib.rs`
- Test: `crates/nsi-mitsuba/tests/stream_roundtrip.rs`

**Interfaces:**

- Consumes: `Scene`, `Node` (Task 6), `OwnedArg`, `OwnedData` (Task 4),
  `EdgeKind` (Task 5).
- Produces: `pub fn write_stream<W: std::io::Write>(scene: &Scene, out:
&mut W) -> std::io::Result<()>`.

- [ ] **Step 1: Write the failing test**

Create `crates/nsi-mitsuba/tests/stream_roundtrip.rs`:

```rust
use nsi_ffi_wrap as nsi;
use nsi_mitsuba::{Recorder, write_stream};
use nsi_trait::Nsi;

/// Build the same tiny scene through the recorder that the sibling
/// 3Delight fixture builds, then compare the emitted stream.
fn build<R: Nsi>(ctx: &R) -> Result<(), R::Error> {
    ctx.create("cam", "perspectivecamera", None)?;
    ctx.set_attribute("cam", &[nsi::f32!("fov", 45.0)])?;
    ctx.create("xf", "transform", None)?;
    ctx.connect("xf", None, ".root", "objects", None)?;
    Ok(())
}

#[test]
fn emits_creates_attributes_and_connections_in_order() {
    let r = Recorder::new();
    build(&r).unwrap();

    let mut out = Vec::new();
    write_stream(&r.scene(), &mut out).unwrap();
    let text = String::from_utf8(out).unwrap();

    let lines: Vec<&str> = text.lines().collect();
    assert_eq!(lines[0], r#"Create "cam" "perspectivecamera""#);
    assert_eq!(lines[1], r#"SetAttribute "cam" "fov" "float" 1 45"#);
    assert_eq!(lines[2], r#"Create "xf" "transform""#);
    assert_eq!(
        lines[3],
        r#"Connect "xf" "" ".root" "objects""#
    );
}

/// The same generic builder must drive the real 3Delight context. Run
/// only where 3Delight is installed; the recorder test above is the
/// unconditional gate.
#[test]
#[ignore = "requires 3Delight; run with --ignored"]
fn matches_3delight_apistream() {
    let path = std::env::temp_dir().join("nsi-mitsuba-fixture.nsi");
    let ctx = nsi::Context::new(Some(&[
        nsi::string!("type", "apistream"),
        nsi::string!("streamfilename", path.to_str().unwrap()),
        nsi::string!("streamformat", "nsi"),
    ]))
    .expect("could not create ɴsɪ context");
    build(&ctx).unwrap();
    drop(ctx);

    let reference = std::fs::read_to_string(&path).unwrap();

    let r = Recorder::new();
    build(&r).unwrap();
    let mut ours = Vec::new();
    write_stream(&r.scene(), &mut ours).unwrap();

    assert_eq!(
        normalise(&reference),
        normalise(&String::from_utf8(ours).unwrap())
    );
}

/// Drop blank lines and comments so the comparison is about calls, not
/// about 3Delight's stream preamble.
fn normalise(s: &str) -> Vec<String> {
    s.lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(str::to_string)
        .collect()
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test -p nsi-mitsuba --test stream_roundtrip`
Expected: FAIL — `unresolved import 'nsi_mitsuba::write_stream'`.

- [ ] **Step 3: Write the implementation**

Create `crates/nsi-mitsuba/src/stream.rs`:

```rust
//! `.nsi` stream emission.
//!
//! Replays a recorded scene in the ɴsɪ stream format so it can be
//! compared against what 3Delight writes for the same calls. Nodes are
//! emitted in creation order, which is why the tables are `IndexMap`s.

use crate::{EdgeKind, OwnedArg, OwnedData, Scene};
use nsi_trait::Type;
use std::io::{self, Write};

/// Write `scene` as an ɴsɪ stream.
pub fn write_stream<W: Write>(scene: &Scene, out: &mut W) -> io::Result<()> {
    for (handle, node) in &scene.nodes {
        writeln!(out, r#"Create "{}" "{}""#, handle, node.node_type)?;
        for arg in node.attrs.values() {
            write_set_attribute(out, handle, arg)?;
        }
        for (time, attrs) in &node.time_attrs {
            for arg in attrs.values() {
                write!(out, r#"SetAttributeAtTime "{handle}" {time} "#)?;
                write_arg(out, arg)?;
                writeln!(out)?;
            }
        }
    }

    for edge in &scene.edges {
        let (from_port, to_port) = match &edge.kind {
            EdgeKind::ShaderNetwork { from_port, to_port } => {
                (from_port.as_str(), to_port.as_str())
            }
            other => ("", to_attr_of(other)),
        };
        writeln!(
            out,
            r#"Connect "{}" "{}" "{}" "{}""#,
            edge.from, from_port, edge.to, to_port
        )?;
    }

    Ok(())
}

/// The ɴsɪ destination attribute an [`EdgeKind`] came from. Inverse of
/// `classify`; keep the two in step.
fn to_attr_of(kind: &EdgeKind) -> &'static str {
    match kind {
        EdgeKind::SceneMember => "objects",
        EdgeKind::AttributeBinding => "geometryattributes",
        EdgeKind::SurfaceShader => "surfaceshader",
        EdgeKind::InstanceSource => "sourcemodels",
        EdgeKind::Screen => "screens",
        EdgeKind::OutputLayer => "outputlayers",
        EdgeKind::OutputDriver => "outputdrivers",
        // Handled by the caller, which has the port names.
        EdgeKind::ShaderNetwork { .. } => "",
    }
}

fn write_set_attribute<W: Write>(
    out: &mut W,
    handle: &str,
    arg: &OwnedArg,
) -> io::Result<()> {
    write!(out, r#"SetAttribute "{handle}" "#)?;
    write_arg(out, arg)?;
    writeln!(out)
}

fn write_arg<W: Write>(out: &mut W, arg: &OwnedArg) -> io::Result<()> {
    write!(
        out,
        r#""{}" "{}" {} "#,
        arg.name,
        type_name(arg.type_tag),
        element_count(arg)
    )?;

    match &arg.data {
        OwnedData::F32(v) => write_scalars(out, v),
        OwnedData::F64(v) => write_scalars(out, v),
        OwnedData::I32(v) => write_scalars(out, v),
        OwnedData::I64(v) => write_scalars(out, v),
        OwnedData::String(v) => {
            let joined: Vec<String> =
                v.iter().map(|s| format!(r#""{s}""#)).collect();
            write!(out, "{}", joined.join(" "))
        }
        // Pointers have no stream representation; 3Delight omits them
        // from apistream output too.
        OwnedData::Reference(_) => Ok(()),
    }
}

fn write_scalars<W: Write, T: std::fmt::Display>(
    out: &mut W,
    values: &[T],
) -> io::Result<()> {
    let joined: Vec<String> =
        values.iter().map(std::string::ToString::to_string).collect();
    write!(out, "{}", joined.join(" "))
}

/// Number of elements, not scalars: a two-point `P` is 2, not 6.
fn element_count(arg: &OwnedArg) -> usize {
    let scalars = match &arg.data {
        OwnedData::F32(v) => v.len(),
        OwnedData::F64(v) => v.len(),
        OwnedData::I32(v) => v.len(),
        OwnedData::I64(v) => v.len(),
        OwnedData::String(v) => v.len(),
        OwnedData::Reference(v) => v.len(),
    };
    let per = match arg.type_tag {
        Type::Color | Type::Point | Type::Vector | Type::Normal => 3,
        Type::MatrixF32 | Type::MatrixF64 => 16,
        _ => 1,
    };
    scalars / per
}

/// ɴsɪ stream type names.
const fn type_name(type_tag: Type) -> &'static str {
    match type_tag {
        Type::F32 | Type::F64 => "float",
        Type::I32 | Type::I64 => "int",
        Type::String => "string",
        Type::Color => "color",
        Type::Point => "point",
        Type::Vector => "vector",
        Type::Normal => "normal",
        Type::MatrixF32 | Type::MatrixF64 => "matrix",
        Type::Reference => "pointer",
        Type::Invalid => "invalid",
    }
}
```

In `crates/nsi-mitsuba/src/lib.rs`:

```rust
mod stream;

pub use stream::write_stream;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test -p nsi-mitsuba --test stream_roundtrip`
Expected: PASS, 1 test; 1 ignored.

- [ ] **Step 5: Run the 3Delight comparison if available**

Run: `cargo test -p nsi-mitsuba --test stream_roundtrip -- --ignored`
Expected: PASS where 3Delight is installed. If the streams differ, the
diff names the exact call whose formatting is wrong — fix `write_arg` or
`type_name`, not the test.

- [ ] **Step 6: Run everything**

Run: `cargo test --workspace`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd ~/code/crates/nsi-mitsuba
git add crates/nsi-mitsuba/src/stream.rs crates/nsi-mitsuba/src/lib.rs crates/nsi-mitsuba/tests/stream_roundtrip.rs
git commit -m "feat: emit .nsi streams and diff against 3Delight"
```

---

## What this plan deliberately leaves out

- **Flushing to Mitsuba.** No `Properties`, no `PluginManager`, no
  `bbl-*`. Phase 3.
- **Transform flattening and `attributes` dissolution.** The classifier
  labels these edges; the graph rewrites happen at flush time, against a
  real Mitsuba scene. Doing them now would mean designing against an API
  we have not bound yet.
- **Making `NsiRenderer` generic.** Task 3 stops at the free functions on
  purpose; see its Step 4.
- **`evaluate`.** Procedurals and Lua imply an execution model that is
  not designed. It records as a no-op and is revisited in Phase 3.
- **akatela.** `monster-step-viewer` is the Phase 1–4 consumer.
