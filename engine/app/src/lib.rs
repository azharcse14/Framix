//! Command handling, undo, and orchestration on top of `framix_core`.

pub mod engine;
pub mod history;

/// Wire types of the UI <-> engine contract (proto/framix/v1/engine.proto).
pub mod proto {
    include!(concat!(env!("OUT_DIR"), "/framix.v1.rs"));
}
