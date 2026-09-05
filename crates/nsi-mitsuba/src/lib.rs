//! Mitsuba 3 backend for the Nodal Scene Interface.
//!
//! This crate holds only the **flush**: turning a recorded ɴsɪ scene
//! into Mitsuba `Properties` trees and instantiating them through
//! `PluginManager`. Everything upstream of that — recording nodes,
//! attributes and classified connections, and replaying them as an
//! `.nsi` stream — is renderer-agnostic and lives in [`nsi_record`].
//!
//! The split exists because a second backend is plausible. MoonRay's
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
//! Nothing is implemented yet. `babble` was the planned binding route
//! and was replaced by a hand-written C shim plus `bindgen`; see
//! `specs/002-mitsuba-backend/research.md` D2. The shim's first gate —
//! that Mitsuba's headers work outside its own build tree — passed on
//! 2026-09-05, so the remaining work is `mitsuba-sys` and the flush.
//! Building Mitsuba is documented in this crate's `README.md`.

pub use nsi_record;
