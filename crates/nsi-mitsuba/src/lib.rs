//! Mitsuba 3 backend for the Nodal Scene Interface.
//!
//! This crate holds only the **flush**: turning a recorded ɴsɪ scene
//! into Mitsuba `Properties` trees and instantiating them through
//! `PluginManager`. Everything upstream of that — recording nodes,
//! attributes and classified connections, and replaying them as an
//! `.nsi` stream — is renderer-agnostic and lives in
//! [`nsi_intermediate`], in the `nsi` workspace.
//!
//! The split exists because a second backend now does: MoonRay's
//! `scene_rdl2` model (`SceneObject` / `SceneClass` / typed attributes /
//! bindings / `Layer`) maps onto ɴsɪ at least as well as Mitsuba's
//! `Properties` do, and in two places better: bindings carry named
//! ports, which Mitsuba references do not, and `Layer` is a real
//! assignment table, which is a closer target for dissolving ɴsɪ
//! `attributes` nodes than a per-shape `bsdf` field.
//!
//! So a backend crate owns exactly two things: the flush, and the
//! renderer-specific half of the graph rewrites. `attributes`
//! dissolution lands on `bsdf` + `visibility_mask` here and on `Layer`
//! there; the classifier that labels those edges is shared.
//!
//! Nothing is implemented yet. It needs a host that can build
//! Mitsuba, and a hand-written `extern "C"` shim -- see
//! `specs/002-mitsuba-backend/`.

pub use nsi_intermediate;

/// The shorter idiom, for consumers who prefer it.
pub use nsi_intermediate as nsi_ir;
