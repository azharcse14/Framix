//! Multi-track timeline: tracks of non-overlapping clips, addressed by stable ids.
//!
//! Keyframes (P5-001) are not modelled yet. Clip-local times are relative to the clip, so
//! keyframes added later stay valid when a clip moves.

use std::collections::BTreeMap;

use crate::aspect::AspectRatio;
use crate::media::{MAX_IMPORT, Media, MediaKind, PHOTO_DEFAULT_DURATION};
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

/// Furthest a frame centre may sit from the canvas centre, in 1/10000 of the canvas: two
/// canvases.
pub const MAX_OFFSET: i32 = 20_000;

/// The scale at which a clip fits the canvas, in 1/1000.
pub const FIT_SCALE: u32 = 1000;

/// Allowed clip scales, in 1/1000 of fit-to-canvas: 1 % to 1000 %.
pub const SCALE_RANGE: std::ops::RangeInclusive<u32> = 10..=10_000;

/// Pixels cut from each side of the source picture.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct Crop {
    /// From the left edge.
    pub left: u32,
    /// From the top edge.
    pub top: u32,
    /// From the right edge.
    pub right: u32,
    /// From the bottom edge.
    pub bottom: u32,
}

/// How a clip's picture is cropped, turned, mirrored and placed on the canvas; the identity by
/// default. The crop applies to the source pixels, then the quarter turns (clockwise, on top of
/// the media's own rotation), then the flips, then the scale and position.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct ClipTransform {
    /// Clockwise quarter turns, 0..=3.
    pub turns: u8,
    /// Mirror left to right.
    pub flip_h: bool,
    /// Mirror top to bottom.
    pub flip_v: bool,
    /// Source pixels cut from each side.
    pub crop: Crop,
    /// Frame centre's offset from the canvas centre, in 1/10000 of the canvas width.
    pub x: i32,
    /// Frame centre's offset from the canvas centre, in 1/10000 of the canvas height.
    pub y: i32,
    /// Size in 1/1000 of fit-to-canvas (1000 = fits).
    pub scale: u32,
}

impl Default for ClipTransform {
    fn default() -> Self {
        Self {
            turns: 0,
            flip_h: false,
            flip_v: false,
            crop: Crop::default(),
            x: 0,
            y: 0,
            scale: FIT_SCALE,
        }
    }
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
    /// Crop, turns and flips of the picture.
    pub transform: ClipTransform,
}

impl Clip {
    /// First tick after the clip.
    pub fn end(&self) -> Time {
        // Non-exhaustive: only insert_clip builds a Clip, and it checked this sum fits.
        Time(self.start.0 + self.duration.0)
    }
}

/// Per-track switches. All off by default.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct TrackFlags {
    /// Silent in preview and export.
    pub muted: bool,
    /// Not drawn in preview and export (visual tracks only).
    pub hidden: bool,
    /// Clips on the track cannot be edited.
    pub locked: bool,
}

/// One track: clips sorted by start, never overlapping.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Track {
    id: TrackId,
    kind: TrackKind,
    clips: Vec<Clip>,
    flags: TrackFlags,
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

    /// Mute, hide and lock switches.
    pub fn flags(&self) -> TrackFlags {
        self.flags
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
    /// The track is locked; its clips cannot be edited.
    #[error("track {0:?} is locked")]
    TrackLocked(TrackId),
    /// Only visual tracks can be hidden.
    #[error("track {0:?} cannot be hidden")]
    NotVisual(TrackId),
    /// A clip can only move to a track of the same kind.
    #[error("track {0:?} has another kind")]
    WrongTrackKind(TrackId),
    /// More items than [`crate::media::MAX_IMPORT`] in one import.
    #[error("too many media in one import")]
    TooManyMedia,
    /// The crop leaves no picture, or the clip's media is unknown.
    #[error("crop leaves no picture")]
    BadCrop,
    /// Quarter turns outside 0..=3.
    #[error("invalid transform")]
    BadTransform,
    /// Merging needs both clips to look the same.
    #[error("clips have different transforms")]
    TransformsDiffer,
    /// The replacement video is shorter than the clip.
    #[error("replacement media is shorter than the clip")]
    MediaTooShort,
}

/// The editable timeline of a video project.
///
/// `==` compares content (tracks, clips, aspect ratio, media) only, not the id counter: two equal timelines
/// can hand out different ids next. Anything that restores a timeline (undo, load) must
/// keep the counter ahead of every issued id.
#[derive(Clone, Debug, Default)]
pub struct Timeline {
    tracks: Vec<Track>,
    aspect: AspectRatio,
    media: BTreeMap<MediaId, Media>,
    /// Last id handed out.
    next_id: u64,
}

impl PartialEq for Timeline {
    fn eq(&self, other: &Self) -> bool {
        self.tracks == other.tracks && self.aspect == other.aspect && self.media == other.media
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
            flags: TrackFlags::default(),
        });
        id
    }

    /// Places a clip on `track` with `transform` (checked like [`Timeline::set_clip_transform`]).
    /// Fails if it would overlap a clip already there.
    pub fn insert_clip_with(
        &mut self,
        track: TrackId,
        placement: ClipPlacement,
        transform: ClipTransform,
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
        if self.tracks[index].flags.locked {
            return Err(TimelineError::TrackLocked(track));
        }
        let at = free_slot(&self.tracks[index].clips, placement.start, end, None)?;
        self.check_transform(placement.media, transform)?;
        let id = ClipId(self.allocate_id());
        let clip = Clip {
            id,
            media: placement.media,
            source_start: placement.source_start,
            start: placement.start,
            duration: placement.duration,
            transform,
        };
        self.tracks[index].clips.insert(at, clip);
        Ok(id)
    }

    /// Places a clip on `track` with the identity transform. Fails if it would overlap a clip
    /// already there.
    pub fn insert_clip(
        &mut self,
        track: TrackId,
        placement: ClipPlacement,
    ) -> Result<ClipId, TimelineError> {
        self.insert_clip_with(track, placement, ClipTransform::default())
    }

    /// Sets a track's mute, hide and lock switches (allowed on a locked track, so it can be
    /// unlocked).
    pub fn set_track_flags(
        &mut self,
        track: TrackId,
        flags: TrackFlags,
    ) -> Result<(), TimelineError> {
        let target = self
            .tracks
            .iter_mut()
            .find(|t| t.id == track)
            .ok_or(TimelineError::UnknownTrack(track))?;
        if flags.hidden && target.kind == TrackKind::Audio {
            return Err(TimelineError::NotVisual(track));
        }
        target.flags = flags;
        Ok(())
    }

    /// Media registered in this project, by id.
    pub fn media(&self, id: MediaId) -> Option<&Media> {
        self.media.get(&id)
    }

    /// All registered media, by id.
    pub fn all_media(&self) -> impl Iterator<Item = (MediaId, &Media)> {
        self.media.iter().map(|(id, m)| (*id, m))
    }

    /// Registers `media` and appends one clip per item, in order and back to back, at the end
    /// of the first unlocked video track (a new video track if there is none). Videos play
    /// their full length, photos [`crate::media::PHOTO_DEFAULT_DURATION`]. All or nothing.
    pub fn import(&mut self, media: Vec<Media>) -> Result<Vec<ClipId>, TimelineError> {
        if media.len() > MAX_IMPORT {
            return Err(TimelineError::TooManyMedia);
        }
        if media.is_empty() {
            return Ok(Vec::new());
        }
        // Work on a copy so a failure part-way leaves `self` untouched.
        let mut next = self.clone();
        let target = next
            .tracks
            .iter()
            .find(|t| t.kind == TrackKind::Video && !t.flags.locked)
            .map(|t| t.id);
        let track = target.unwrap_or_else(|| next.add_track(TrackKind::Video));
        let mut start = next
            .track(track)
            .and_then(|t| t.clips.last())
            .map_or(Time(0), Clip::end);
        let mut clips = Vec::with_capacity(media.len());
        for item in media {
            let duration = match item.kind() {
                MediaKind::Video => item.duration(),
                MediaKind::Image => PHOTO_DEFAULT_DURATION,
            };
            let id = MediaId(next.allocate_id());
            next.media.insert(id, item);
            let placement = ClipPlacement {
                media: id,
                source_start: Time(0),
                start,
                duration,
            };
            clips.push(next.insert_clip(track, placement)?);
            // insert_clip checked that start + duration fits.
            start = Time(start.0 + duration.0);
        }
        *self = next;
        Ok(clips)
    }

    /// Registers `media` under a known `id` (project load), keeping new ids above it.
    pub fn restore_media(&mut self, id: MediaId, media: Media) {
        self.reserve_ids_through(id.0);
        self.media.insert(id, media);
    }

    /// Makes sure ids up to `id` are never handed out (e.g. media ids that clips of an old
    /// project file refer to).
    pub fn reserve_ids_through(&mut self, id: u64) {
        self.next_id = self.next_id.max(id);
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
            transform: c.transform,
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
        if l.transform != r.transform {
            return Err(TimelineError::TransformsDiffer);
        }
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
        // A trim moves edges but never past a neighbour, so the track stays sorted.
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

    /// Moves a clip to `start` on track `to` (its own track or another of the same kind),
    /// keeping its id, media, source offset and duration. Refused if either track is locked or
    /// the new spot overlaps another clip; on refusal nothing changes.
    pub fn move_clip(
        &mut self,
        clip: ClipId,
        to: TrackId,
        start: Time,
    ) -> Result<(), TimelineError> {
        let (from, i) = self.locate(clip)?;
        let dest = self
            .tracks
            .iter()
            .position(|t| t.id == to)
            .ok_or(TimelineError::UnknownTrack(to))?;
        if self.tracks[dest].flags.locked {
            return Err(TimelineError::TrackLocked(to));
        }
        if self.tracks[dest].kind != self.tracks[from].kind {
            return Err(TimelineError::WrongTrackKind(to));
        }
        if start.0 < 0 {
            return Err(TimelineError::NegativeTime);
        }
        let moving = self.tracks[from].clips[i];
        let end = start
            .0
            .checked_add(moving.duration.0)
            .ok_or(TimelineError::TimeOverflow)?;
        // The moving clip may slide over its own old spot.
        free_slot(&self.tracks[dest].clips, start, end, Some(clip))?;
        self.tracks[from].clips.remove(i);
        let clips = &mut self.tracks[dest].clips;
        let at = clips.partition_point(|c| c.start < start);
        clips.insert(at, Clip { start, ..moving });
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
        self.insert_clip_with(self.tracks[t].id, copy, c.transform)
    }

    /// Sets a clip's crop, turns and flips. The crop must leave at least one pixel each way of
    /// the clip's media; turns must be 0..=3.
    pub fn set_clip_transform(
        &mut self,
        clip: ClipId,
        transform: ClipTransform,
    ) -> Result<(), TimelineError> {
        let (t, i) = self.locate(clip)?;
        self.check_transform(self.tracks[t].clips[i].media, transform)?;
        self.tracks[t].clips[i].transform = transform;
        Ok(())
    }

    /// Turns 0..=3, and a crop that leaves at least one pixel each way of `media`.
    fn check_transform(
        &self,
        media: MediaId,
        transform: ClipTransform,
    ) -> Result<(), TimelineError> {
        let on_canvas = |v: i32| (-MAX_OFFSET..=MAX_OFFSET).contains(&v);
        if transform.turns > 3
            || !on_canvas(transform.x)
            || !on_canvas(transform.y)
            || !SCALE_RANGE.contains(&transform.scale)
        {
            return Err(TimelineError::BadTransform);
        }
        let crop = transform.crop;
        if crop != Crop::default() {
            let (width, height) = self.media(media).ok_or(TimelineError::BadCrop)?.size();
            // u64 sums: four u32 insets cannot overflow.
            let across = u64::from(crop.left) + u64::from(crop.right);
            let down = u64::from(crop.top) + u64::from(crop.bottom);
            if across >= u64::from(width) || down >= u64::from(height) {
                return Err(TimelineError::BadCrop);
            }
        }
        Ok(())
    }

    /// Puts `media` under `clip`, keeping its track, start and duration: the media is
    /// registered under a new id, the source starts at 0 and the transform resets. A video must
    /// be at least as long as the clip. The old media stays registered (undo needs it).
    pub fn replace_clip(&mut self, clip: ClipId, media: Media) -> Result<MediaId, TimelineError> {
        let (t, i) = self.locate(clip)?;
        if media.kind() == MediaKind::Video && media.duration() < self.tracks[t].clips[i].duration {
            return Err(TimelineError::MediaTooShort);
        }
        // Every check is done: nothing below can fail, so no id is used up on a refusal.
        let id = MediaId(self.allocate_id());
        self.media.insert(id, media);
        let target = &mut self.tracks[t].clips[i];
        target.media = id;
        target.source_start = Time(0);
        // The crop was measured on the old media's size.
        target.transform = ClipTransform::default();
        Ok(id)
    }

    /// The clip at `time` on the topmost visible video track that has one: the clip canvas
    /// gestures act on.
    pub fn top_clip_at(&self, time: Time) -> Option<ClipId> {
        // Later tracks draw over earlier ones.
        self.tracks
            .iter()
            .rev()
            .filter(|t| t.kind == TrackKind::Video && !t.flags.hidden)
            .find_map(|t| t.clip_at(time))
            .map(|c| c.id)
    }

    /// Track and clip index of `clip`, refusing clips on a locked track.
    // ponytail: linear scan over all clips, once per command; index by id if profiles show it.
    fn locate(&self, clip: ClipId) -> Result<(usize, usize), TimelineError> {
        let (t, i) = self
            .tracks
            .iter()
            .enumerate()
            .find_map(|(t, track)| {
                track
                    .clips
                    .iter()
                    .position(|c| c.id == clip)
                    .map(|i| (t, i))
            })
            .ok_or(TimelineError::UnknownClip(clip))?;
        let track = &self.tracks[t];
        if track.flags.locked {
            return Err(TimelineError::TrackLocked(track.id));
        }
        Ok((t, i))
    }

    /// The snap point nearest to `time` within `within` ticks, if any: 0, the timeline end and
    /// every clip's start and end on every track. Ties go to the earlier point.
    pub fn snap(&self, time: Time, within: Time) -> Option<Time> {
        let mut best: Option<Time> = None;
        // `time` is untrusted (a Seek): distances as u64 cannot overflow.
        let within = within.0.max(0).unsigned_abs();
        let mut consider = |p: Time| {
            let d = p.0.abs_diff(time.0);
            if d > within {
                return;
            }
            // Strictly closer wins; an equal distance keeps the earlier point.
            let better = match best {
                None => true,
                Some(b) => {
                    let bd = b.0.abs_diff(time.0);
                    d < bd || (d == bd && p < b)
                }
            };
            if better {
                best = Some(p);
            }
        };
        consider(Time(0));
        consider(self.duration());
        for track in &self.tracks {
            // Clips are sorted and never overlap, so their edges are sorted too: only the
            // clips around `time` can hold the nearest edges.
            let i = track.clips.partition_point(|c| c.end() < time);
            for clip in track.clips[i.saturating_sub(1)..].iter().take(3) {
                consider(clip.start);
                consider(clip.end());
            }
        }
        best
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

/// Index where a clip spanning `[start, end)` goes in the sorted, non-overlapping `clips`, or
/// the nearest clip it would overlap. `skip` is ignored: the clip being moved. Used where a
/// clip may land anywhere free (insert, move); trim instead stays between its neighbours.
fn free_slot(
    clips: &[Clip],
    start: Time,
    end: i64,
    skip: Option<ClipId>,
) -> Result<usize, TimelineError> {
    let at = clips.partition_point(|c| c.start < start);
    let other = |c: &&Clip| Some(c.id) != skip;
    if let Some(prev) = clips[..at]
        .iter()
        .rev()
        .find(other)
        .filter(|c| c.end() > start)
    {
        return Err(TimelineError::Overlap(prev.id));
    }
    if let Some(next) = clips[at..].iter().find(other).filter(|c| c.start.0 < end) {
        return Err(TimelineError::Overlap(next.id));
    }
    Ok(at)
}
