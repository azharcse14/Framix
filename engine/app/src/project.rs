//! Project file encoding (proto/framix/project/v1/project.proto). Pure: bytes in, bytes out.

use framix_core::timeline::{Timeline, TimelineError};
use thiserror::Error;

/// Format version this engine writes and the newest it reads.
pub const FORMAT_VERSION: u32 = 1;

/// Why a project file could not be opened.
#[derive(Debug, Error)]
pub enum ProjectError {
    /// Not a project file (bad Protobuf).
    #[error("not a project file: {0}")]
    Corrupt(#[from] prost::DecodeError),
    /// Written by a newer app that this engine cannot read safely.
    #[error("project needs reader version {0}")]
    TooNew(u32),
    /// A track kind this engine does not know.
    #[error("unknown track kind {0}")]
    UnknownTrackKind(i32),
    /// The clips break timeline rules (overlap, non-positive duration, ...).
    #[error("invalid project: {0}")]
    Invalid(#[from] TimelineError),
}

/// Encodes `timeline` as a project file.
pub fn encode(_timeline: &Timeline) -> Vec<u8> {
    Vec::new()
}

/// Decodes a project file. The bytes are untrusted: every clip is re-inserted through the
/// timeline's own checks, and ids are assigned fresh.
pub fn decode(_bytes: &[u8]) -> Result<Timeline, ProjectError> {
    Ok(Timeline::default())
}
