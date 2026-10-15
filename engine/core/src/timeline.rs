//! Multi-track timeline: tracks of non-overlapping clips, addressed by stable ids.
//!
//! Keyframes (P5-001) are not modelled yet. Clip-local times are relative to the clip, so
//! keyframes added later stay valid when a clip moves.

use crate::time::Time;

/// Stable id of a track within a timeline.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct TrackId(pub u64);

/// Stable id of a clip within a timeline.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ClipId(pub u64);

/// Id of an imported media item in the project's media pool.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct MediaId(pub u64);

/// What a track carries.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum TrackKind {
    /// Video, photo, or other visual clips.
    Video,
    /// Audio-only clips.
    Audio,
}

/// Where a new clip goes and which part of its media it shows.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ClipPlacement {
    /// Media the clip plays.
    pub media: MediaId,
    /// Offset into the media where playback starts.
    pub source_start: Time,
    /// Timeline position of the clip's first tick.
    pub start: Time,
    /// Length on the timeline; must be positive.
    pub duration: Time,
}

/// A clip on a track. Covers the half-open range `[start, start + duration)`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Clip {
    /// Stable id.
    pub id: ClipId,
    /// Media the clip plays.
    pub media: MediaId,
    /// Offset into the media where playback starts.
    pub source_start: Time,
    /// Timeline position of the first tick.
    pub start: Time,
    /// Length on the timeline; always positive.
    pub duration: Time,
}

impl Clip {
    /// First tick after the clip.
    pub fn end(&self) -> Time {
        // Timeline::insert_clip checked that start + duration fits in i64.
        Time(self.start.0 + self.duration.0)
    }
}

/// One track: clips sorted by start, never overlapping.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Track {
    id: TrackId,
    kind: TrackKind,
    clips: Vec<Clip>,
}

impl Track {
    /// Stable id.
    pub fn id(&self) -> TrackId {
        self.id
    }

    /// What the track carries.
    pub fn kind(&self) -> TrackKind {
        self.kind
    }

    /// Clips sorted by start time.
    pub fn clips(&self) -> &[Clip] {
        &self.clips
    }

    /// The clip covering `time`, if any.
    pub fn clip_at(&self, time: Time) -> Option<&Clip> {
        let after = self.clips.partition_point(|c| c.start <= time);
        let clip = self.clips[..after].last()?;
        (time < clip.end()).then_some(clip)
    }
}

/// Why a timeline edit was rejected.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum TimelineError {
    #[error("track {0:?} does not exist")]
    UnknownTrack(TrackId),
    #[error("clip duration must be positive")]
    NonPositiveDuration,
    #[error("clip end is past the largest representable time")]
    TimeOverflow,
    #[error("clip overlaps clip {0:?}")]
    Overlap(ClipId),
}

/// The editable timeline of a video project.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Timeline {
    tracks: Vec<Track>,
    next_id: u64,
}

impl Timeline {
    /// Tracks in display order.
    pub fn tracks(&self) -> &[Track] {
        &self.tracks
    }

    /// Looks up a track by id.
    pub fn track(&self, id: TrackId) -> Option<&Track> {
        self.tracks.iter().find(|t| t.id == id)
    }

    /// Appends an empty track and returns its id.
    pub fn add_track(&mut self, kind: TrackKind) -> TrackId {
        let id = TrackId(self.allocate_id());
        self.tracks.push(Track {
            id,
            kind,
            clips: Vec::new(),
        });
        id
    }

    /// Places a clip on `track`. Fails if it would overlap a clip already there.
    pub fn insert_clip(
        &mut self,
        track: TrackId,
        placement: ClipPlacement,
    ) -> Result<ClipId, TimelineError> {
        if placement.duration.0 <= 0 {
            return Err(TimelineError::NonPositiveDuration);
        }
        let end = placement
            .start
            .0
            .checked_add(placement.duration.0)
            .ok_or(TimelineError::TimeOverflow)?;
        let index = self
            .tracks
            .iter()
            .position(|t| t.id == track)
            .ok_or(TimelineError::UnknownTrack(track))?;
        let clips = &self.tracks[index].clips;
        let at = clips.partition_point(|c| c.start < placement.start);
        if let Some(prev) = clips[..at].last().filter(|c| c.end() > placement.start) {
            return Err(TimelineError::Overlap(prev.id));
        }
        if let Some(next) = clips.get(at).filter(|c| c.start.0 < end) {
            return Err(TimelineError::Overlap(next.id));
        }
        let id = ClipId(self.allocate_id());
        let clip = Clip {
            id,
            media: placement.media,
            source_start: placement.source_start,
            start: placement.start,
            duration: placement.duration,
        };
        self.tracks[index].clips.insert(at, clip);
        Ok(id)
    }

    /// End of the last clip on any track; zero when empty.
    pub fn duration(&self) -> Time {
        // Clips are sorted and never overlap, so a track's last clip ends last.
        self.tracks
            .iter()
            .filter_map(|t| t.clips.last().map(Clip::end))
            .max()
            .unwrap_or(Time(0))
    }

    fn allocate_id(&mut self) -> u64 {
        self.next_id += 1;
        self.next_id
    }
}
