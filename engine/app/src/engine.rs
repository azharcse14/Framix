//! Turns UI commands into timeline edits and reports the result as an event.

use framix_core::aspect::AspectRatio;
use framix_core::time::Time;
use framix_core::timeline::{self, ClipPlacement, MediaId, Timeline, TimelineError, TrackId};

use std::path::Path;

use crate::history::History;
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
}

impl Engine {
    /// An engine that saves and opens projects through `store`. [`Engine::default`] has no
    /// store and refuses SaveProject/OpenProject.
    pub fn with_store(store: Box<dyn ProjectStore>) -> Self {
        Self {
            history: History::default(),
            store: Some(store),
        }
    }

    /// Applies `command` and returns the single event describing the outcome: the new
    /// timeline, or [`CommandFailed`] with the timeline unchanged.
    pub fn handle(&mut self, command: Command) -> Event {
        let Some(kind) = command.kind else {
            return command_failed("command has no kind");
        };
        match self.apply(kind) {
            Ok(Reply::Timeline) => self.timeline_changed(),
            Ok(Reply::Saved) => Event {
                kind: Some(proto::event::Kind::ProjectSaved(ProjectSaved {})),
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
                Ok(Reply::Timeline)
            }
            command::Kind::OpenProject(open) => timeline(self.open(&open.path)),
            command::Kind::SaveProject(save) => self.save(&save.path).map(|()| Reply::Saved),
            command::Kind::RemoveClip(_)
            | command::Kind::SplitClip(_)
            | command::Kind::MergeClips(_)
            | command::Kind::TrimClip(_)
            | command::Kind::DuplicateClip(_) => Err("not implemented".to_owned()),
            command::Kind::SetAspectRatio(set) => {
                let aspect = AspectRatio::new(set.width, set.height)
                    .ok_or_else(|| format!("invalid aspect ratio {}:{}", set.width, set.height))?;
                // Re-selecting the current ratio is not an edit: no undo step, redo kept.
                if self.history.timeline().aspect() == aspect {
                    return Ok(Reply::Timeline);
                }
                timeline(self.edit(|tl| {
                    tl.set_aspect(aspect);
                    Ok::<_, TimelineError>(())
                }))
            }
        }
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
                        })
                        .collect(),
                    number: *count,
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
