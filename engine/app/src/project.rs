//! Project file encoding (proto/framix/project/v1/project.proto). Pure: bytes in, bytes out.

use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Resolution};
use framix_core::media::{Media, MediaKind, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{
    ClipPlacement, ClipTransform, Crop, FIT_SCALE, MediaId, Timeline, TimelineError, TrackFlags,
    TrackKind,
};
use prost::Message as _;
use thiserror::Error;

use crate::project_proto::{
    ProjectFile, SavedClip, SavedMedia, SavedMediaKind, SavedTrack, SavedTrackKind,
};

/// Format version this engine writes and the newest it reads.
pub const FORMAT_VERSION: u32 = 5;

/// Oldest reader that can open what this engine writes: 5, because older readers would drop
/// what they don't know when they save again (format 1: the media list; format 2: clip
/// transforms; format 3: canvas position and scale; format 4: export settings).
const MIN_READER_VERSION: u32 = 5;

/// Most tracks a project file may hold.
pub const MAX_TRACKS: usize = 256;
/// Most clips (all tracks together) a project file may hold.
pub const MAX_CLIPS: usize = 100_000;
/// Largest id a project file may carry; keeps the id counter far from overflow.
pub const MAX_ID: u64 = 1 << 53;

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
    /// A media entry breaks the import rules (bad reference, size, duration, ...).
    #[error("invalid media: {0}")]
    InvalidMedia(#[from] framix_core::media::MediaError),
    /// A media id (or a clip's media id) is above [`MAX_ID`].
    #[error("id {0} out of range")]
    IdOutOfRange(u64),
    /// A clip refers to media the file does not list (format 2+).
    #[error("clip refers to unlisted media {0}")]
    UnknownMedia(u64),
    /// A media kind this engine does not know.
    /// Export settings out of range.
    #[error("invalid export settings")]
    InvalidExport,
    #[error("unknown media kind {0}")]
    UnknownMediaKind(i32),
    /// Two media entries share an id.
    #[error("duplicate media id {0}")]
    DuplicateMedia(u64),
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
                    turns: u32::from(c.transform.turns),
                    flip_h: c.transform.flip_h,
                    flip_v: c.transform.flip_v,
                    crop_left: c.transform.crop.left,
                    crop_top: c.transform.crop.top,
                    crop_right: c.transform.crop.right,
                    crop_bottom: c.transform.crop.bottom,
                    x: c.transform.x,
                    y: c.transform.y,
                    scale: c.transform.scale,
                })
                .collect(),
            muted: track.flags().muted,
            hidden: track.flags().hidden,
            locked: track.flags().locked,
        })
        .collect();
    ProjectFile {
        format_version: FORMAT_VERSION,
        min_reader_version: MIN_READER_VERSION,
        tracks,
        aspect_width: timeline.aspect().width(),
        aspect_height: timeline.aspect().height(),
        media: timeline.all_media().map(saved_media).collect(),
        export_resolution: match timeline.export().resolution {
            Resolution::P720 => 1,
            Resolution::P1080 => 2,
            Resolution::P2K => 3,
            Resolution::P4K => 4,
        },
        export_fps: match timeline.export().fps {
            FrameRate::F24 => 1,
            FrameRate::F30 => 2,
            FrameRate::F60 => 3,
        },
        export_kbps: match timeline.export().bitrate {
            Bitrate::Auto => 0,
            Bitrate::Kbps(kbps) => kbps,
        },
    }
    .encode_to_vec()
}

/// Encodes `timeline` for saving, refusing anything [`decode`] would refuse to open again
/// (more than [`MAX_TRACKS`], [`MAX_CLIPS`], or [`MAX_PROJECT_BYTES`]).
pub fn encode_for_save(timeline: &Timeline) -> Result<Vec<u8>, ProjectError> {
    let tracks = timeline.tracks();
    let clips: usize = tracks.iter().map(|t| t.clips().len()).sum();
    let media = timeline.all_media().count();
    if tracks.len() > MAX_TRACKS || clips > MAX_CLIPS || media > MAX_CLIPS {
        return Err(ProjectError::TooLarge);
    }
    // Open refuses format-2 clips whose media is not listed, so never write one.
    if let Some(clip) = tracks
        .iter()
        .flat_map(|t| t.clips())
        .find(|c| timeline.media(c.media).is_none())
    {
        return Err(ProjectError::UnknownMedia(clip.media.0));
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
    if file.tracks.len() > MAX_TRACKS || clips > MAX_CLIPS || file.media.len() > MAX_CLIPS {
        return Err(ProjectError::TooLarge);
    }
    let mut timeline = Timeline::default();
    timeline.set_export(saved_export(&file)?);
    // 0:0 is a file from before the aspect ratio was saved: keep the default.
    if (file.aspect_width, file.aspect_height) != (0, 0) {
        let aspect = AspectRatio::new(file.aspect_width, file.aspect_height)
            .ok_or(ProjectError::InvalidAspect)?;
        timeline.set_aspect(aspect);
    }
    let clip_media = file
        .tracks
        .iter()
        .flat_map(|t| &t.clips)
        .map(|c| c.media_id);
    if let Some(id) = file
        .media
        .iter()
        .map(|m| m.id)
        .chain(clip_media)
        .find(|&id| id > MAX_ID)
    {
        return Err(ProjectError::IdOutOfRange(id));
    }
    for saved in file.media {
        let id = MediaId(saved.id);
        if timeline.media(id).is_some() {
            return Err(ProjectError::DuplicateMedia(saved.id));
        }
        timeline.restore_media(id, restore_media(saved)?);
    }
    // Clips of format-1 files refer to media the file does not list; never reuse those ids.
    let referenced = file
        .tracks
        .iter()
        .flat_map(|t| &t.clips)
        .map(|c| c.media_id)
        .max();
    timeline.reserve_ids_through(referenced.unwrap_or(0));
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
        let flags = TrackFlags {
            muted: saved.muted,
            hidden: saved.hidden,
            locked: saved.locked,
        };
        for c in saved.clips {
            let placement = ClipPlacement {
                media: MediaId(c.media_id),
                source_start: Time(c.source_start),
                start: Time(c.start),
                duration: Time(c.duration),
            };
            // Format 1 had no media list; from format 2 on every clip's media is listed.
            if file.format_version >= 2 && timeline.media(placement.media).is_none() {
                return Err(ProjectError::UnknownMedia(c.media_id));
            }
            let transform = ClipTransform {
                turns: u8::try_from(c.turns).map_err(|_| TimelineError::BadTransform)?,
                flip_h: c.flip_h,
                flip_v: c.flip_v,
                crop: Crop {
                    left: c.crop_left,
                    top: c.crop_top,
                    right: c.crop_right,
                    bottom: c.crop_bottom,
                },
                x: c.x,
                y: c.y,
                // Files before format 4 have no scale: fit.
                scale: if c.scale == 0 { FIT_SCALE } else { c.scale },
            };
            // Untrusted: checked like an edit, and set at insert so loading stays linear.
            timeline.insert_clip_with(track, placement, transform)?;
        }
        // After the clips: a locked track refuses inserts.
        timeline.set_track_flags(track, flags)?;
    }
    Ok(timeline)
}

/// Export settings from a file; 0 in a field (files before format 5) keeps its default.
fn saved_export(file: &ProjectFile) -> Result<ExportSettings, ProjectError> {
    let default = ExportSettings::default();
    let resolution = match file.export_resolution {
        0 => default.resolution,
        1 => Resolution::P720,
        2 => Resolution::P1080,
        3 => Resolution::P2K,
        4 => Resolution::P4K,
        _ => return Err(ProjectError::InvalidExport),
    };
    let fps = match file.export_fps {
        0 => default.fps,
        1 => FrameRate::F24,
        2 => FrameRate::F30,
        3 => FrameRate::F60,
        _ => return Err(ProjectError::InvalidExport),
    };
    let bitrate = match file.export_kbps {
        0 => Bitrate::Auto,
        kbps => Bitrate::kbps(kbps).ok_or(ProjectError::InvalidExport)?,
    };
    Ok(ExportSettings {
        resolution,
        fps,
        bitrate,
    })
}

fn saved_media((id, media): (MediaId, &Media)) -> SavedMedia {
    let (width, height) = media.size();
    SavedMedia {
        id: id.0,
        uri: media.uri().to_owned(),
        kind: match media.kind() {
            MediaKind::Video => SavedMediaKind::Video,
            MediaKind::Image => SavedMediaKind::Image,
        } as i32,
        duration: media.duration().0,
        width,
        height,
        rotation: media.rotation(),
        codec: media.codec().to_owned(),
    }
}

/// Re-validates a saved media entry with the same rules as an import (the file is untrusted).
fn restore_media(saved: SavedMedia) -> Result<Media, ProjectError> {
    let kind = match SavedMediaKind::try_from(saved.kind) {
        Ok(SavedMediaKind::Video) => MediaKind::Video,
        Ok(SavedMediaKind::Image) => MediaKind::Image,
        _ => return Err(ProjectError::UnknownMediaKind(saved.kind)),
    };
    let raw = RawMedia {
        uri: saved.uri,
        kind,
        duration_value: saved.duration,
        duration_timescale: TICKS_PER_SECOND_U32,
        width: saved.width,
        height: saved.height,
        rotation: saved.rotation,
        codec: saved.codec,
    };
    Ok(Media::validate(raw)?)
}

/// Saved durations are ticks, so their timescale is ticks per second (fits in u32).
const TICKS_PER_SECOND_U32: u32 = TICKS_PER_SECOND as u32;
