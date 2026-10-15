//! Command handling, undo, and orchestration on top of `framix_core`.

pub mod engine;
pub mod history;
pub mod project;
pub mod store;

/// Wire types of the UI <-> engine contract (proto/framix/v1/engine.proto).
pub mod proto {
    include!(concat!(env!("OUT_DIR"), "/framix.v1.rs"));
}

/// Project file types (proto/framix/project/v1/project.proto).
pub mod project_proto {
    include!(concat!(env!("OUT_DIR"), "/framix.project.v1.rs"));
}
