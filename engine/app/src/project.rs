//! Project file encoding (proto/framix/project/v1/project.proto). Pure: bytes in, bytes out.

use framix_core::aspect::AspectRatio;
use framix_core::time::Time;
use framix_core::timeline::{ClipPlacement, MediaId, Timeline, TimelineError, TrackKind};
use prost::Message as _;
use thiserror::Error;

use crate::project_proto::{ProjectFile, SavedClip, SavedTrack, SavedTrackKind};

/// Format version this engine writes and the newest it reads.
pub const FORMAT_VERSION: u32 = 1;

/// Oldest reader that can open what this engine writes.
const MIN_READER_VERSION: u32 = 1;

/// Most tracks a project file may hold.
pub const MAX_TRACKS: usize = 256;
/// Most clips (all tracks together) a project file may hold.
pub const MAX_CLIPS: usize = 100_000;
/// Largest project file. Small on purpose: prost holds a file's decoded messages in memory
/// before the track and clip caps apply (2-byte empty tracks would otherwise multiply).
// ponytail: fixed caps; raise them together when real projects need it.
pub const MAX_PROJECT_BYTES: u64 = 4 * 1024 * 1024;

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
    /// No format version: an empty or truncated file, not a project.
    #[error("project file has no format version")]
    MissingVersion,
    /// A track's clips are not in ascending start order (the encoder always sorts them).
    #[error("clips out of order")]
    Unsorted,
    /// More than [`MAX_TRACKS`], [`MAX_CLIPS`] or [`MAX_PROJECT_BYTES`].
    #[error("project too large")]
    TooLarge,
    /// The aspect ratio is outside what the editor allows.
    #[error("invalid aspect ratio")]
    InvalidAspect,
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
            muted: false,
            hidden: false,
            locked: false,
        })
        .collect();
    ProjectFile {
        format_version: FORMAT_VERSION,
        min_reader_version: MIN_READER_VERSION,
        tracks,
        aspect_width: timeline.aspect().width(),
        aspect_height: timeline.aspect().height(),
    }
    .encode_to_vec()
}

/// Encodes `timeline` for saving, refusing anything [`decode`] would refuse to open again
/// (more than [`MAX_TRACKS`], [`MAX_CLIPS`], or [`MAX_PROJECT_BYTES`]).
pub fn encode_for_save(timeline: &Timeline) -> Result<Vec<u8>, ProjectError> {
    let tracks = timeline.tracks();
    let clips: usize = tracks.iter().map(|t| t.clips().len()).sum();
    if tracks.len() > MAX_TRACKS || clips > MAX_CLIPS {
        return Err(ProjectError::TooLarge);
    }
    let bytes = encode(timeline);
    if bytes.len() as u64 > MAX_PROJECT_BYTES {
        return Err(ProjectError::TooLarge);
    }
    Ok(bytes)
}

/// Decodes a project file. The bytes are untrusted: every clip is re-inserted through the
/// timeline's own checks, and ids are assigned fresh.
pub fn decode(bytes: &[u8]) -> Result<Timeline, ProjectError> {
    if bytes.len() as u64 > MAX_PROJECT_BYTES {
        return Err(ProjectError::TooLarge);
    }
    let file = ProjectFile::decode(bytes)?;
    // proto3 decodes empty bytes as all-zero fields; a real file always has a version.
    if file.format_version == 0 || file.min_reader_version == 0 {
        return Err(ProjectError::MissingVersion);
    }
    if file.min_reader_version > FORMAT_VERSION {
        return Err(ProjectError::TooNew(file.min_reader_version));
    }
    let clips: usize = file.tracks.iter().map(|t| t.clips.len()).sum();
    if file.tracks.len() > MAX_TRACKS || clips > MAX_CLIPS {
        return Err(ProjectError::TooLarge);
    }
    let mut timeline = Timeline::default();
    // 0:0 is a file from before the aspect ratio was saved: keep the default.
    if (file.aspect_width, file.aspect_height) != (0, 0) {
        let aspect = AspectRatio::new(file.aspect_width, file.aspect_height)
            .ok_or(ProjectError::InvalidAspect)?;
        timeline.set_aspect(aspect);
    }
    for saved in file.tracks {
        let kind = match SavedTrackKind::try_from(saved.kind) {
            Ok(SavedTrackKind::Video) => TrackKind::Video,
            Ok(SavedTrackKind::Audio) => TrackKind::Audio,
            _ => return Err(ProjectError::UnknownTrackKind(saved.kind)),
        };
        let track = timeline.add_track(kind);
        // Ascending starts make every insert an append, so loading stays linear.
        if saved.clips.windows(2).any(|w| w[0].start >= w[1].start) {
            return Err(ProjectError::Unsorted);
        }
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
