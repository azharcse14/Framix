//! Multi-track timeline: tracks of non-overlapping clips, addressed by stable ids.
//!
//! Keyframes (P5-001) are not modelled yet. Clip-local times are relative to the clip, so
//! keyframes added later stay valid when a clip moves.

use crate::aspect::AspectRatio;
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
/// Only [`Timeline::insert_clip`] builds clips, so `end` never overflows.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[non_exhaustive]
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
        // Non-exhaustive: only insert_clip builds a Clip, and it checked this sum fits.
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
    /// No track has this id.
    #[error("track {0:?} does not exist")]
    UnknownTrack(TrackId),
    /// Duration is zero or negative.
    #[error("clip duration must be positive")]
    NonPositiveDuration,
    /// `start + duration` does not fit in [`Time`].
    #[error("clip end is past the largest representable time")]
    TimeOverflow,
    /// The clip would overlap this existing clip.
    #[error("clip overlaps clip {0:?}")]
    Overlap(ClipId),
    /// Start or source offset is before zero.
    #[error("clip start and source offset must not be negative")]
    NegativeTime,
    /// No clip has this id.
    #[error("clip {0:?} does not exist")]
    UnknownClip(ClipId),
    /// A split point must lie strictly inside the clip.
    #[error("split point is not inside the clip")]
    SplitOutside,
    /// Merge needs two neighbouring clips on one track, same media, continuous source.
    #[error("clips cannot be merged")]
    NotMergeable,
}

/// The editable timeline of a video project.
///
/// `==` compares content (tracks, clips, aspect ratio) only, not the id counter: two equal timelines
/// can hand out different ids next. Anything that restores a timeline (undo, load) must
/// keep the counter ahead of every issued id.
#[derive(Clone, Debug, Default)]
pub struct Timeline {
    tracks: Vec<Track>,
    aspect: AspectRatio,
    /// Last id handed out.
    next_id: u64,
}

impl PartialEq for Timeline {
    fn eq(&self, other: &Self) -> bool {
        self.tracks == other.tracks && self.aspect == other.aspect
    }
}

impl Eq for Timeline {}

impl Timeline {
    /// Canvas aspect ratio.
    pub fn aspect(&self) -> AspectRatio {
        self.aspect
    }

    /// Sets the canvas aspect ratio.
    pub fn set_aspect(&mut self, aspect: AspectRatio) {
        self.aspect = aspect;
    }

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
        if placement.start.0 < 0 || placement.source_start.0 < 0 {
            return Err(TimelineError::NegativeTime);
        }
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

    /// Removes a clip.
    pub fn remove_clip(&mut self, clip: ClipId) -> Result<(), TimelineError> {
        let (t, i) = self.locate(clip)?;
        self.tracks[t].clips.remove(i);
        Ok(())
    }

    /// Splits a clip at timeline time `at` (strictly inside it). The left part keeps the id;
    /// the right part gets a new id and starts its source `at - start` later.
    pub fn split_clip(&mut self, clip: ClipId, at: Time) -> Result<ClipId, TimelineError> {
        let (t, i) = self.locate(clip)?;
        let c = self.tracks[t].clips[i];
        if at <= c.start || at >= c.end() {
            return Err(TimelineError::SplitOutside);
        }
        let cut = at.0 - c.start.0;
        let source_start = c
            .source_start
            .0
            .checked_add(cut)
            .ok_or(TimelineError::TimeOverflow)?;
        let id = ClipId(self.allocate_id());
        let clips = &mut self.tracks[t].clips;
        clips[i].duration = Time(cut);
        let right = Clip {
            id,
            media: c.media,
            source_start: Time(source_start),
            start: at,
            duration: Time(c.duration.0 - cut),
        };
        clips.insert(i + 1, right);
        Ok(id)
    }

    /// Joins `right` into `left`: neighbours on one track (`left` ends where `right` starts),
    /// same media, and `right`'s source continues `left`'s. `left` keeps its id.
    pub fn merge_clips(&mut self, left: ClipId, right: ClipId) -> Result<(), TimelineError> {
        let (t, i) = self.locate(left)?;
        let (rt, j) = self.locate(right)?;
        let clips = &mut self.tracks[t].clips;
        let (l, r) = (clips[i], clips.get(j).copied().filter(|_| rt == t));
        let continuous = |r: &Clip| {
            j == i + 1
                && l.end() == r.start
                && l.media == r.media
                && l.source_start.0.checked_add(l.duration.0) == Some(r.source_start.0)
        };
        let Some(r) = r.filter(continuous) else {
            return Err(TimelineError::NotMergeable);
        };
        // Fits: it is r.end() - l.start, and r.end() fits.
        clips[i].duration = Time(l.duration.0 + r.duration.0);
        clips.remove(j);
        Ok(())
    }

    /// Moves a clip's edges to `[start, end)`. Moving the start also moves the source offset by
    /// the same amount, so the frames under the rest of the clip stay put.
    // ponytail: no media-length check yet (P1-013 brings durations); the tail can grow past
    // the end of the media.
    pub fn trim_clip(&mut self, clip: ClipId, start: Time, end: Time) -> Result<(), TimelineError> {
        let (t, i) = self.locate(clip)?;
        let clips = &mut self.tracks[t].clips;
        let c = clips[i];
        if start.0 < 0 {
            return Err(TimelineError::NegativeTime);
        }
        if end <= start {
            return Err(TimelineError::NonPositiveDuration);
        }
        // Both starts are non-negative, so the difference cannot overflow.
        let source_start = c
            .source_start
            .0
            .checked_add(start.0 - c.start.0)
            .ok_or(TimelineError::TimeOverflow)?;
        if source_start < 0 {
            return Err(TimelineError::NegativeTime);
        }
        if let Some(prev) = clips[..i].last().filter(|p| p.end() > start) {
            return Err(TimelineError::Overlap(prev.id));
        }
        if let Some(next) = clips.get(i + 1).filter(|n| n.start < end) {
            return Err(TimelineError::Overlap(next.id));
        }
        let trimmed = &mut clips[i];
        trimmed.start = start;
        trimmed.source_start = Time(source_start);
        trimmed.duration = Time(end.0 - start.0);
        Ok(())
    }

    /// Copies a clip to right after itself on the same track (no ripple: refused with
    /// [`TimelineError::Overlap`] if that space is taken).
    pub fn duplicate_clip(&mut self, clip: ClipId) -> Result<ClipId, TimelineError> {
        let (t, i) = self.locate(clip)?;
        let c = self.tracks[t].clips[i];
        let copy = ClipPlacement {
            media: c.media,
            source_start: c.source_start,
            start: c.end(),
            duration: c.duration,
        };
        self.insert_clip(self.tracks[t].id, copy)
    }

    /// Track and clip index of `clip`.
    // ponytail: linear scan over all clips, once per command; index by id if profiles show it.
    fn locate(&self, clip: ClipId) -> Result<(usize, usize), TimelineError> {
        self.tracks
            .iter()
            .enumerate()
            .find_map(|(t, track)| {
                track
                    .clips
                    .iter()
                    .position(|c| c.id == clip)
                    .map(|i| (t, i))
            })
            .ok_or(TimelineError::UnknownClip(clip))
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

    /// Makes every id this timeline hands out from now on newer than any id `other`
    /// handed out. Undo uses it so a restored snapshot never reissues an id.
    pub fn keep_ids_newer_than(&mut self, other: &Timeline) {
        self.next_id = self.next_id.max(other.next_id);
    }

    fn allocate_id(&mut self) -> u64 {
        self.next_id += 1;
        self.next_id
    }
}
