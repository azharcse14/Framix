//! Project file encoding (proto/framix/project/v1/project.proto). Pure: bytes in, bytes out.

use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};
use prost::Message as _;
use thiserror::Error;

use crate::project_proto::{ProjectFile, SavedClip, SavedTrack, SavedTrackKind};

/// Format version this engine writes and the newest it reads.
pub const FORMAT_VERSION: u32 = 1;

/// Oldest reader that can open what this engine writes.
const MIN_READER_VERSION: u32 = 1;

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
pub fn encode(timeline: &Timeline) -> Vec<u8> {
    let tracks = timeline
        .tracks()
        .iter()
        .map(|track| SavedTrack {
            kind: match track.kind() {
                TrackKind::Video => SavedTrackKind::Video,
                TrackKind::Audio => SavedTrackKind::Audio,
            } as i32,
            clips: track
                .clips()
                .iter()
                .map(|c| SavedClip {
                    media_id: c.media.0,
                    source_start: c.source_start.0,
                    start: c.start.0,
                    duration: c.duration.0,
                })
                .collect(),
        })
        .collect();
    ProjectFile {
        format_version: FORMAT_VERSION,
        min_reader_version: MIN_READER_VERSION,
        tracks,
    }
    .encode_to_vec()
}

/// Decodes a project file. The bytes are untrusted: every clip is re-inserted through the
/// timeline's own checks, and ids are assigned fresh.
pub fn decode(bytes: &[u8]) -> Result<Timeline, ProjectError> {
    let file = ProjectFile::decode(bytes)?;
    if file.min_reader_version > FORMAT_VERSION {
        return Err(ProjectError::TooNew(file.min_reader_version));
    }
    let mut timeline = Timeline::default();
    for saved in file.tracks {
        let kind = match SavedTrackKind::try_from(saved.kind) {
            Ok(SavedTrackKind::Video) => TrackKind::Video,
            Ok(SavedTrackKind::Audio) => TrackKind::Audio,
            _ => return Err(ProjectError::UnknownTrackKind(saved.kind)),
        };
        let track = timeline.add_track(kind);
        for c in saved.clips {
            let placement = ClipPlacement {
                media: MediaId(c.media_id),
                source_start: Time(c.source_start),
                start: Time(c.start),
                duration: Time(c.duration),
            };
            timeline.insert_clip(track, placement)?;
        }
    }
    Ok(timeline)
}
