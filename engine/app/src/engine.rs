//! Turns UI commands into timeline edits and reports the result as an event.

use framix_core::aspect::AspectRatio;
use framix_core::media::{self, Media, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{
    self, ClipId, ClipPlacement, MediaId, Timeline, TimelineError, TrackFlags, TrackId,
};

use std::path::Path;

use crate::history::History;
use crate::preview::{PlatformTexture, PreviewHost, PreviewRenderer};
use crate::project;
use crate::proto::{
    self, Command, CommandFailed, Event, ProjectSaved, TimelineChanged, TrackKind, command,
};
use crate::store::ProjectStore;

/// Engine state behind the FFI boundary: one project's timeline, its undo history, and where
/// projects are saved.
#[derive(Default)]
pub struct Engine {
    history: History,
    store: Option<Box<dyn ProjectStore>>,
    preview: Option<Preview>,
    thumbnails: Option<crate::thumbnail::Thumbnails>,
    /// Where the preview shows; always inside [0, duration]. Not part of the timeline, so undo
    /// never moves it and saves don't store it.
    playhead: Time,
}

/// Where the preview comes from: the platform's texture and the GPU that draws into it.
struct Preview {
    host: Box<dyn PreviewHost>,
    renderer: Box<dyn PreviewRenderer>,
    /// Texture requests the platform has not answered yet.
    pending: u32,
    /// The texture last shown, redrawn when the playhead moves.
    shown: Option<PlatformTexture>,
}

/// Largest snap radius a Seek may ask for.
const MAX_SNAP: Time = Time(10 * TICKS_PER_SECOND);

/// Largest preview side; also the smallest max texture size of supported GPUs.
const MAX_PREVIEW_SIDE: u32 = 8192;

impl Engine {
    /// An engine that saves and opens projects through `store`. [`Engine::default`] has no
    /// store and refuses SaveProject/OpenProject.
    pub fn with_store(store: Box<dyn ProjectStore>) -> Self {
        Self {
            store: Some(store),
            ..Self::default()
        }
    }

    /// Lets this engine answer CreatePreview through `host` and `renderer`; without them it
    /// refuses CreatePreview.
    pub fn with_preview(
        self,
        host: Box<dyn PreviewHost>,
        renderer: Box<dyn PreviewRenderer>,
    ) -> Self {
        Self {
            preview: Some(Preview {
                host,
                renderer,
                pending: 0,
                shown: None,
            }),
            ..self
        }
    }

    /// The platform's answer to a CreatePreview: draws into the texture, signals the frame,
    /// and returns PreviewReady, or CommandFailed if the platform or the GPU failed.
    pub fn preview_texture_ready(&mut self, texture: Result<PlatformTexture, String>) -> Event {
        match self.show_preview(texture) {
            Ok(texture_id) => Event {
                kind: Some(proto::event::Kind::PreviewReady(proto::PreviewReady {
                    texture_id,
                })),
            },
            Err(reason) => command_failed(reason),
        }
    }

    fn request_preview(&mut self, width: u32, height: u32) -> Result<(), String> {
        let side = 1..=MAX_PREVIEW_SIDE;
        if !side.contains(&width) || !side.contains(&height) {
            return Err(format!("invalid preview size {width}x{height}"));
        }
        let preview = self.preview.as_mut().ok_or("no preview on this platform")?;
        preview.host.create_texture(width, height)?;
        preview.pending += 1;
        Ok(())
    }

    fn show_preview(&mut self, texture: Result<PlatformTexture, String>) -> Result<i64, String> {
        let preview = self
            .preview
            .as_mut()
            .filter(|p| p.pending > 0)
            .ok_or("no preview was requested")?;
        preview.pending -= 1;
        let texture = texture?;
        preview.renderer.draw(texture, self.playhead)?;
        preview.host.frame_available(texture.id);
        // Only a preview that drew once is redrawn later.
        preview.shown = Some(texture);
        Ok(texture.id)
    }

    /// Best effort: draws the shown texture at the playhead. A failed draw stops later redraws
    /// (the preview is gone) but never fails the command that moved the playhead; the
    /// playhead and the timeline are the state, the picture follows them.
    fn redraw(&mut self) {
        let Some(preview) = self.preview.as_mut() else {
            return;
        };
        let Some(texture) = preview.shown else {
            return;
        };
        match preview.renderer.draw(texture, self.playhead) {
            Ok(()) => preview.host.frame_available(texture.id),
            Err(_) => preview.shown = None,
        }
    }

    /// Moves the playhead to `time` inside the timeline and redraws if it moved.
    fn move_playhead(&mut self, time: Time) {
        let end = self.history.timeline().duration();
        let time = Time(time.0.clamp(0, end.0.max(0)));
        if time != self.playhead {
            self.playhead = time;
            self.redraw();
        }
    }

    /// Lets this engine make thumbnails through `host`; without it RequestThumbnails fails.
    pub fn with_thumbnails(self, host: Box<dyn crate::thumbnail::ThumbnailHost>) -> Self {
        Self {
            thumbnails: Some(crate::thumbnail::Thumbnails::new(host)),
            ..self
        }
    }

    /// The platform's answer to one thumbnail request: ThumbnailReady for a made file, nothing
    /// for a failure. Starts the next queued request either way.
    pub fn thumbnail_ready(
        &mut self,
        key: crate::thumbnail::ThumbnailKey,
        path: Result<String, String>,
    ) -> Option<Event> {
        let thumbnails = self.thumbnails.as_mut()?;
        if !thumbnails.finish(key) {
            return None;
        }
        let path = path.ok()?;
        Some(Event {
            kind: Some(proto::event::Kind::ThumbnailReady(proto::ThumbnailReady {
                media_id: key.media.0,
                time: key.time.0,
                max_side: key.max_side,
                path,
            })),
        })
    }

    /// Applies `command` and returns the single event describing the outcome: the new
    /// timeline, or [`CommandFailed`] with the timeline unchanged.
    pub fn handle(&mut self, command: Command) -> Event {
        let Some(kind) = command.kind else {
            return command_failed("command has no kind");
        };
        match self.apply(kind) {
            // An edit may have shortened the timeline under the playhead.
            Ok(Reply::Timeline) => {
                // An edit may have shortened the timeline under the playhead.
                self.move_playhead(self.playhead);
                self.timeline_changed()
            }
            Ok(Reply::Playhead(snapped)) => Event {
                kind: Some(proto::event::Kind::PlayheadChanged(
                    proto::PlayheadChanged {
                        time: self.playhead.0,
                        snapped,
                    },
                )),
            },
            Ok(Reply::Saved) => Event {
                kind: Some(proto::event::Kind::ProjectSaved(ProjectSaved {})),
            },
            Ok(Reply::Accepted) => Event {
                kind: Some(proto::event::Kind::CommandAccepted(
                    proto::CommandAccepted {},
                )),
            },
            Err(reason) => command_failed(reason),
        }
    }

    fn apply(&mut self, kind: command::Kind) -> Result<Reply, String> {
        let timeline = |r: Result<(), String>| r.map(|()| Reply::Timeline);
        match kind {
            command::Kind::AddTrack(add) => {
                let kind = track_kind(add.kind)?;
                timeline(self.edit(|tl| Ok(tl.add_track(kind))))
            }
            command::Kind::InsertClip(insert) => {
                let placement = ClipPlacement {
                    media: MediaId(insert.media_id),
                    source_start: Time(insert.source_start),
                    start: Time(insert.start),
                    duration: Time(insert.duration),
                };
                timeline(self.edit(|tl| tl.insert_clip(TrackId(insert.track_id), placement)))
            }
            command::Kind::Undo(_) => timeline(step(self.history.undo(), "nothing to undo")),
            command::Kind::Redo(_) => timeline(step(self.history.redo(), "nothing to redo")),
            command::Kind::GetTimeline(_) => Ok(Reply::Timeline),
            command::Kind::NewProject(_) => {
                self.history = History::default();
                self.forget_thumbnails();
                self.move_playhead(Time(0));
                Ok(Reply::Timeline)
            }
            command::Kind::OpenProject(open) => timeline(self.open(&open.path).map(|()| {
                // Another project starts at its beginning, with its own media ids.
                self.forget_thumbnails();
                self.move_playhead(Time(0));
            })),
            command::Kind::SaveProject(save) => self.save(&save.path).map(|()| Reply::Saved),
            command::Kind::RemoveClip(op) => {
                timeline(self.edit(|tl| tl.remove_clip(ClipId(op.clip_id))))
            }
            command::Kind::SplitClip(op) => {
                timeline(self.edit(|tl| tl.split_clip(ClipId(op.clip_id), Time(op.at))))
            }
            command::Kind::MergeClips(op) => {
                timeline(self.edit(|tl| tl.merge_clips(ClipId(op.left_id), ClipId(op.right_id))))
            }
            command::Kind::TrimClip(op) => timeline(
                self.edit(|tl| tl.trim_clip(ClipId(op.clip_id), Time(op.start), Time(op.end))),
            ),
            command::Kind::DuplicateClip(op) => {
                timeline(self.edit(|tl| tl.duplicate_clip(ClipId(op.clip_id))))
            }
            command::Kind::SetTrackFlags(op) => {
                let track = TrackId(op.track_id);
                timeline(self.edit(|tl| {
                    let current = tl
                        .track(track)
                        .ok_or(TimelineError::UnknownTrack(track))?
                        .flags();
                    let flags = TrackFlags {
                        muted: op.muted.unwrap_or(current.muted),
                        hidden: op.hidden.unwrap_or(current.hidden),
                        locked: op.locked.unwrap_or(current.locked),
                    };
                    tl.set_track_flags(track, flags)
                }))
            }
            command::Kind::MoveClip(op) => {
                timeline(self.edit(|tl| {
                    tl.move_clip(ClipId(op.clip_id), TrackId(op.track_id), Time(op.start))
                }))
            }
            command::Kind::ImportMedia(op) => {
                // Fail fast before validating a huge list; Timeline::import holds the rule.
                if op.items.len() > media::MAX_IMPORT {
                    return Err(TimelineError::TooManyMedia.to_string());
                }
                let media = op
                    .items
                    .into_iter()
                    .map(media_from_item)
                    .collect::<Result<Vec<_>, _>>()?;
                timeline(self.edit(|tl| tl.import(media).map(drop)))
            }
            command::Kind::RequestThumbnails(op) => {
                self.request_thumbnails(op).map(|()| Reply::Accepted)
            }
            command::Kind::Seek(seek) => {
                if seek.snap_within < 0 {
                    return Err("negative snap tolerance".into());
                }
                let within = Time(seek.snap_within.min(MAX_SNAP.0));
                let snapped = (within.0 > 0)
                    .then(|| self.history.timeline().snap(Time(seek.time), within))
                    .flatten();
                self.move_playhead(snapped.unwrap_or(Time(seek.time)));
                Ok(Reply::Playhead(snapped.is_some()))
            }
            command::Kind::CreatePreview(size) => self
                .request_preview(size.width, size.height)
                .map(|()| Reply::Accepted),
            command::Kind::SetAspectRatio(set) => {
                let aspect = AspectRatio::new(set.width, set.height)
                    .ok_or_else(|| format!("invalid aspect ratio {}:{}", set.width, set.height))?;
                timeline(self.edit(|tl| {
                    tl.set_aspect(aspect);
                    Ok::<_, TimelineError>(())
                }))
            }
        }
    }

    fn forget_thumbnails(&mut self) {
        if let Some(thumbnails) = self.thumbnails.as_mut() {
            thumbnails.reset();
        }
    }

    fn request_thumbnails(&mut self, op: proto::RequestThumbnails) -> Result<(), String> {
        use crate::thumbnail::{MAX_SIDE, MAX_TIMES};
        if !MAX_SIDE.contains(&op.max_side) {
            return Err(format!("thumbnail size {} out of range", op.max_side));
        }
        if op.times.len() > MAX_TIMES {
            return Err(format!("too many thumbnail times ({})", op.times.len()));
        }
        let id = MediaId(op.media_id);
        let media = self
            .history
            .timeline()
            .media(id)
            .ok_or_else(|| format!("unknown media {}", op.media_id))?;
        let thumbnails = self
            .thumbnails
            .as_mut()
            .ok_or("no thumbnails on this platform")?;
        thumbnails.ask(id, media, &op.times, op.max_side)
    }

    fn store(&self) -> Result<&dyn ProjectStore, String> {
        self.store
            .as_deref()
            .ok_or_else(|| "no project store".to_owned())
    }

    fn save(&self, path: &str) -> Result<(), String> {
        let bytes = project::encode_for_save(self.history.timeline()).map_err(|e| e.to_string())?;
        self.store()?
            .save(Path::new(path), &bytes)
            .map_err(|e| e.to_string())
    }

    /// Replaces the project only if the file loads and decodes; otherwise nothing changes.
    fn open(&mut self, path: &str) -> Result<(), String> {
        let bytes = self
            .store()?
            .load(Path::new(path))
            .map_err(|e| e.to_string())?;
        let timeline = project::decode(&bytes).map_err(|e| e.to_string())?;
        self.history = History::new(timeline);
        Ok(())
    }

    fn edit<T>(
        &mut self,
        edit: impl FnOnce(&mut Timeline) -> Result<T, TimelineError>,
    ) -> Result<(), String> {
        self.history
            .apply(edit)
            .map(drop)
            .map_err(|e| e.to_string())
    }

    fn timeline_changed(&self) -> Event {
        let timeline = self.history.timeline();
        let (mut videos, mut audios) = (0, 0);
        let tracks = timeline
            .tracks()
            .iter()
            .map(|t| {
                let (kind, count) = match t.kind() {
                    timeline::TrackKind::Video => (TrackKind::Video, &mut videos),
                    timeline::TrackKind::Audio => (TrackKind::Audio, &mut audios),
                };
                *count += 1;
                proto::Track {
                    id: t.id().0,
                    kind: kind as i32,
                    clips: t
                        .clips()
                        .iter()
                        .map(|c| proto::Clip {
                            id: c.id.0,
                            media_id: c.media.0,
                            source_start: c.source_start.0,
                            start: c.start.0,
                            duration: c.duration.0,
                            media_kind: match timeline.media(c.media).map(Media::kind) {
                                Some(media::MediaKind::Video) => proto::MediaKind::Video,
                                Some(media::MediaKind::Image) => proto::MediaKind::Image,
                                None => proto::MediaKind::Unspecified,
                            } as i32,
                        })
                        .collect(),
                    number: *count,
                    muted: t.flags().muted,
                    hidden: t.flags().hidden,
                    locked: t.flags().locked,
                }
            })
            .collect();
        Event {
            kind: Some(proto::event::Kind::TimelineChanged(TimelineChanged {
                tracks,
                duration: timeline.duration().0,
                can_undo: self.history.can_undo(),
                can_redo: self.history.can_redo(),
                aspect_width: timeline.aspect().width(),
                aspect_height: timeline.aspect().height(),
                playhead: self.playhead.0,
                ticks_per_second: TICKS_PER_SECOND,
                thumbnail_step: crate::thumbnail::THUMBNAIL_STEP.0,
            })),
        }
    }
}

/// What a successful command reports.
enum Reply {
    /// The timeline (changed or not).
    Timeline,
    /// The project was saved.
    Saved,
    /// Work started; its result comes later as its own event.
    Accepted,
    /// Where the playhead is now, and whether the seek snapped.
    Playhead(bool),
}

/// The event for a rejected command. `reason` is for logs, not for display.
pub fn command_failed(reason: impl Into<String>) -> Event {
    Event {
        kind: Some(proto::event::Kind::CommandFailed(CommandFailed {
            reason: reason.into(),
        })),
    }
}

fn track_kind(wire: i32) -> Result<timeline::TrackKind, String> {
    match TrackKind::try_from(wire) {
        Ok(TrackKind::Video) => Ok(timeline::TrackKind::Video),
        Ok(TrackKind::Audio) => Ok(timeline::TrackKind::Audio),
        _ => Err(format!("unknown track kind {wire}")),
    }
}

fn step(done: bool, otherwise: &str) -> Result<(), String> {
    done.then_some(()).ok_or_else(|| otherwise.to_owned())
}

/// Validates one picked file. Errors never include the uri (no paths in logs).
fn media_from_item(item: proto::MediaItem) -> Result<Media, String> {
    let kind = match proto::MediaKind::try_from(item.kind) {
        Ok(proto::MediaKind::Video) => media::MediaKind::Video,
        Ok(proto::MediaKind::Image) => media::MediaKind::Image,
        _ => return Err(format!("unknown media kind {}", item.kind)),
    };
    let raw = RawMedia {
        uri: item.uri,
        kind,
        duration_value: item.duration_value,
        duration_timescale: item.duration_timescale,
        width: item.width,
        height: item.height,
        rotation: item.rotation,
        codec: item.codec,
    };
    Media::validate(raw).map_err(|e| e.to_string())
}
