//! Turns UI commands into timeline edits and reports the result as an event.

use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Preset, Resolution};
use framix_core::media::{self, Media, RawMedia};
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{
    self, ClipId, ClipPlacement, Layer, LayerKey, MediaId, Timeline, TimelineError, TrackFlags,
    TrackId,
};

use std::path::{Path, PathBuf};

use crate::history::History;
use crate::preview::{DrawError, PlatformTexture, PreviewHost, PreviewRenderer};
use crate::project;
use crate::proto::{
    self, Command, CommandFailed, Event, ProjectSaved, TimelineChanged, TrackKind, command,
};
use crate::store::{self, LoadError, ProjectStore};

/// Engine state behind the FFI boundary: one project's timeline, its undo history, and where
/// projects are saved.
#[derive(Default)]
pub struct Engine {
    history: History,
    store: Option<Box<dyn ProjectStore>>,
    preview: Option<Preview>,
    thumbnails: Option<crate::thumbnail::Thumbnails>,
    proxies: Option<crate::proxy::Proxies>,
    /// Where the preview shows; always inside [0, duration]. Not part of the timeline, so undo
    /// never moves it and saves don't store it.
    playhead: Time,
    /// Bumped each time a project starts (new, opened, restored), so the UI can drop what it
    /// cached for the old one (media ids restart).
    project: u64,
    /// Where the project is autosaved: EnableAutosave's file, or the library file of the
    /// project NewProject or OpenProject started.
    autosave: Option<PathBuf>,
    /// The folder of the user's projects, once OpenLibrary succeeded.
    library: Option<PathBuf>,
    /// The timeline last autosaved or recovered; autosave writes only when it differs.
    autosaved: Timeline,
    /// The last autosave failed and was reported; later failures stay quiet until a success.
    autosave_failed: bool,
    /// ExportProject is possible (the platform has an encoder).
    exports: bool,
    /// Where ExportProject checks the free storage first; None skips the check.
    free_space: Option<Box<dyn crate::export::FreeSpace>>,
    /// The accepted export, until the worker takes it.
    export_job: Option<crate::export::ExportJob>,
    /// The running export's cancel flag; Some while an export runs (accepted, not finished).
    export_cancel: Option<std::sync::Arc<std::sync::atomic::AtomicBool>>,
    /// What playback advances by; without it Play is refused.
    clock: Option<Box<dyn crate::clock::Clock>>,
    /// While playing: the clock and the playhead when playback last started or was moved
    /// (Seek, StepFrame). The playhead is the anchor plus the clock's time since, so steps
    /// never add up rounding or late ticks.
    playing: Option<(Time, Time)>,
    /// The range SetLoop set, as given (start < end); [`Engine::live_loop`] keeps it to the
    /// timeline.
    loop_range: Option<(Time, Time)>,
}

/// Where the preview comes from: the platform's texture and the GPU that draws into it.
struct Preview {
    host: Box<dyn PreviewHost>,
    renderer: Box<dyn PreviewRenderer>,
    /// Texture requests the platform has not answered yet.
    pending: u32,
    /// The texture last shown, redrawn when the playhead moves.
    shown: Option<PlatformTexture>,
    /// The pictures last drawn into it, bottom to top (empty: an empty canvas).
    drawn: Vec<LayerKey>,
    /// The shown texture needs a redraw at the playhead ([`Engine::flush_preview`]).
    stale: bool,
    /// The texture a redraw lost on the GPU, until [`Engine::flush_preview`] reports it.
    lost: Option<i64>,
}

impl Preview {
    /// Gives `texture` back to the platform once the renderer has dropped what it kept for it.
    fn release(&mut self, texture: PlatformTexture) {
        self.renderer.forget(texture);
        self.host.release_texture(texture);
    }
}

impl Drop for Preview {
    /// The engine is going away: the shown texture goes back to the platform.
    fn drop(&mut self) {
        if let Some(texture) = self.shown.take() {
            self.release(texture);
        }
    }
}

/// Longest time a change waits before the engine autosaves it.
pub const AUTOSAVE_DELAY: std::time::Duration = std::time::Duration::from_secs(1);

/// How often the playhead moves while playing: about 30 PlayheadChanged per second.
pub const PLAYHEAD_INTERVAL: std::time::Duration = std::time::Duration::from_micros(33_333);

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
                drawn: Vec::new(),
                stale: false,
                lost: None,
            }),
            ..self
        }
    }

    /// Saves the project to the autosave file if it changed since the last autosave (or
    /// recovery). Returns CommandFailed if the save failed; None otherwise.
    pub fn autosave(&mut self) -> Option<Event> {
        let path = self.autosave.clone()?;
        if *self.history.timeline() == self.autosaved {
            return None;
        }
        let saved = project::encode_for_save(self.history.timeline())
            .map_err(|e| e.to_string())
            .and_then(|bytes| {
                // The kind only: an io error's text could name the path.
                (self.store()?.save(&path, &bytes)).map_err(|e| e.kind().to_string())
            });
        match saved {
            Ok(()) => {
                self.autosaved = self.history.timeline().clone();
                self.autosave_failed = false;
                None
            }
            // Still unsaved, so the next call tries again; report only the first failure.
            Err(_) if self.autosave_failed => None,
            Err(reason) => {
                self.autosave_failed = true;
                Some(command_failed(format!("autosave failed: {reason}")))
            }
        }
    }

    /// Lets this engine accept ExportProject (it has an encoder); without it the command is
    /// refused.
    pub fn with_export(self) -> Self {
        Self {
            exports: true,
            ..self
        }
    }

    /// Lets this engine refuse an export that would not fit the storage `space` reports.
    pub fn with_free_space(self, space: Box<dyn crate::export::FreeSpace>) -> Self {
        Self {
            free_space: Some(space),
            ..self
        }
    }

    /// The export accepted by the last command, for the worker to run; None if there is none.
    pub fn take_export_job(&mut self) -> Option<crate::export::ExportJob> {
        self.export_job.take()
    }

    /// The worker's result for the running export: ExportFinished.
    pub fn export_finished(&mut self, result: Result<(), String>) -> Event {
        self.export_cancel = None;
        Event {
            kind: Some(proto::event::Kind::ExportFinished(proto::ExportFinished {
                ok: result.is_ok(),
                reason: result.err().unwrap_or_default(),
                cancelled: false,
                ..Default::default()
            })),
        }
    }

    /// The worker's progress: ExportProgress.
    pub fn export_progress(&mut self, frame: u32, frames: u32) -> Event {
        Event {
            kind: Some(proto::event::Kind::ExportProgress(proto::ExportProgress {
                frame,
                frames,
            })),
        }
    }

    /// The worker's result for the running export: one ExportFinished.
    pub fn export_result(&mut self, result: Result<(), crate::export::ExportError>) -> Event {
        match result {
            Ok(()) => self.export_finished(Ok(())),
            Err(crate::export::ExportError::Cancelled) => self.export_cancelled(),
            Err(crate::export::ExportError::Failed(reason)) => self.export_finished(Err(reason)),
        }
    }

    /// The running export stopped because it was cancelled: ExportFinished, cancelled.
    pub fn export_cancelled(&mut self) -> Event {
        self.export_cancel = None;
        Event {
            kind: Some(proto::event::Kind::ExportFinished(proto::ExportFinished {
                ok: false,
                reason: String::new(),
                cancelled: true,
                ..Default::default()
            })),
        }
    }

    /// Asks the running export to stop (the engine is stopping); nothing if none runs.
    pub fn cancel_running_export(&mut self) {
        if let Some(flag) = &self.export_cancel {
            flag.store(true, std::sync::atomic::Ordering::Relaxed);
        }
    }

    /// CancelExport: refused unless an export runs and is not already being cancelled.
    fn cancel_export(&mut self) -> Result<(), String> {
        match &self.export_cancel {
            Some(flag) if !flag.load(std::sync::atomic::Ordering::Relaxed) => {
                flag.store(true, std::sync::atomic::Ordering::Relaxed);
                Ok(())
            }
            Some(_) => Err("the export is already stopping".into()),
            None => Err("no export is running".into()),
        }
    }

    /// Accepts an export of the current timeline: one at a time, never of an empty timeline,
    /// and not when the file would not fit the free storage (then the reply says so).
    fn start_export(&mut self, path: String) -> Result<Reply, String> {
        if !self.exports {
            return Err("this engine cannot export".into());
        }
        if self.export_cancel.is_some() {
            return Err("an export is already running".into());
        }
        // The platform replaces what is at the path, so it must name an .mp4 file.
        if std::path::Path::new(&path).extension() != Some(std::ffi::OsStr::new("mp4")) {
            return Err("the export path must be an .mp4 file".into());
        }
        let timeline = self.history.timeline();
        if timeline.duration() == Time(0) {
            return Err("nothing to export".into());
        }
        if let Some(free) = self.free_space.as_ref().and_then(|s| s.free_bytes(&path)) {
            let estimated = export_info(timeline).estimated_bytes;
            let needed = crate::export::bytes_needed(estimated);
            if needed > free {
                return Ok(Reply::NoSpace { needed, free });
            }
        }
        let cancel = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
        self.export_job = Some(crate::export::ExportJob {
            timeline: timeline.clone(),
            path,
            cancel: cancel.clone(),
        });
        self.export_cancel = Some(cancel);
        Ok(Reply::Accepted)
    }

    /// Whether [`Engine::autosave`] has something to write.
    pub fn autosave_pending(&self) -> bool {
        self.autosave.is_some() && *self.history.timeline() != self.autosaved
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
        let preview = self.preview.as_mut().ok_or("no preview was requested")?;
        if preview.pending == 0 {
            if let Ok(texture) = texture {
                preview.release(texture);
            }
            return Err("no preview was requested".into());
        }
        preview.pending -= 1;
        let texture = texture?;
        let layers = preview_layers(
            self.history.timeline(),
            self.playhead,
            self.proxies.as_ref(),
        );
        match preview
            .renderer
            .draw(texture, self.playhead, &mut layers.clone())
        {
            // A frame that can't be decoded shows black; the preview itself works.
            Ok(()) | Err(DrawError::Decode(_)) => {}
            Err(DrawError::Gpu(reason)) => {
                preview.release(texture);
                return Err(reason);
            }
        }
        preview.host.frame_available(texture.id);
        // Only a preview that drew once is redrawn later; the one it replaces goes back.
        // Platform texture ids are unique, so the old one is never the new one.
        if let Some(old) = preview.shown.replace(texture) {
            preview.release(old);
        }
        remember(&mut preview.drawn, layers);
        preview.stale = false;
        Ok(texture.id)
    }

    /// Marks the shown texture for a redraw at the playhead; [`Engine::flush_preview`] (or the
    /// end of [`Engine::handle`]) draws it once, however often it was marked.
    fn redraw(&mut self) {
        if let Some(preview) = self.preview.as_mut() {
            preview.stale |= preview.shown.is_some();
        }
    }

    /// Best effort: draws a stale preview at the playhead. A failed draw stops later redraws
    /// (the preview is gone, reported by flush_preview) but never fails the command that moved
    /// the playhead; the playhead and the timeline are the state, the picture follows them.
    fn draw_stale(&mut self) {
        let Some(preview) = self.preview.as_mut().filter(|p| p.stale) else {
            return;
        };
        preview.stale = false;
        let Some(texture) = preview.shown else {
            return;
        };
        let layers = preview_layers(
            self.history.timeline(),
            self.playhead,
            self.proxies.as_ref(),
        );
        match preview
            .renderer
            .draw(texture, self.playhead, &mut layers.clone())
        {
            Ok(()) | Err(DrawError::Decode(_)) => {
                preview.host.frame_available(texture.id);
                remember(&mut preview.drawn, layers);
            }
            Err(DrawError::Gpu(_)) => {
                preview.shown = None;
                preview.lost = Some(texture.id);
                preview.release(texture);
            }
        }
    }

    /// Draws the preview once if a command since the last draw moved the playhead or changed
    /// the picture, and returns PreviewLost once if a draw lost the shown texture.
    pub fn flush_preview(&mut self) -> Option<Event> {
        self.draw_stale();
        let texture_id = self.preview.as_mut()?.lost.take()?;
        Some(Event {
            kind: Some(proto::event::Kind::PreviewLost(proto::PreviewLost {
                texture_id,
            })),
        })
    }

    /// Redraws if an edit changed the picture under a playhead that did not move.
    fn redraw_if_changed(&mut self) {
        let Some(preview) = self.preview.as_ref() else {
            return;
        };
        let now = preview_layers(
            self.history.timeline(),
            self.playhead,
            self.proxies.as_ref(),
        )
        .map(|l| l.key());
        if preview.shown.is_some() && !now.eq(preview.drawn.iter().copied()) {
            self.redraw();
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

    /// Lets this engine play (Play) by `clock`; without it Play is refused.
    pub fn with_clock(self, clock: Box<dyn crate::clock::Clock>) -> Self {
        Self {
            clock: Some(clock),
            ..self
        }
    }

    /// Playback is running: call [`Engine::advance_playback`] every [`PLAYHEAD_INTERVAL`].
    pub fn is_playing(&self) -> bool {
        self.playing.is_some()
    }

    /// While playing, moves the playhead to where the clock says and returns its
    /// PlayheadChanged (playing false once it reached the end); None when not playing.
    pub fn advance_playback(&mut self) -> Option<Event> {
        // Taken first, so a panic below leaves playback stopped instead of failing every tick.
        let (clock_at, playhead_at) = self.playing.take()?;
        let now = self.clock.as_ref()?.now();
        let end = self.history.timeline().duration();
        let time = Time(
            playhead_at
                .0
                .saturating_add(now.0.saturating_sub(clock_at.0).max(0)),
        );
        if let Some((start, stop)) = self.live_loop(end).filter(|&(_, stop)| time >= stop) {
            // Past the loop's end: on from its start by the overshoot, anchored there again so
            // laps never add up rounding.
            let at = Time(start.0 + (time.0 - stop.0) % (stop.0 - start.0));
            self.move_playhead(at);
            self.playing = Some((now, at));
            return Some(self.playhead_changed(false));
        }
        self.move_playhead(time);
        if time < end {
            self.playing = Some((clock_at, playhead_at));
        }
        Some(self.playhead_changed(false))
    }

    /// Starts playback at the playhead (at 0 from the end); an empty timeline stays stopped.
    fn play(&mut self) -> Result<(), String> {
        let now = self.clock.as_ref().ok_or("no playback clock")?.now();
        if self.is_playing() {
            // Already playing: report where the clock is now.
            self.advance_playback();
            return Ok(());
        }
        let end = self.history.timeline().duration();
        if end.0 <= 0 {
            return Ok(());
        }
        if self.playhead >= end {
            self.move_playhead(Time(0));
        }
        if let Some((start, stop)) = self.live_loop(end)
            && !(start..stop).contains(&self.playhead)
        {
            self.move_playhead(start);
        }
        self.playing = Some((now, self.playhead));
        Ok(())
    }

    /// The loop kept to the timeline (start at least 0, at most `end`, the timeline's end);
    /// None when that leaves nothing.
    fn live_loop(&self, end: Time) -> Option<(Time, Time)> {
        let (start, stop) = self.loop_range?;
        let start = Time(start.0.max(0));
        let stop = Time(stop.0.min(end.0));
        (start < stop).then_some((start, stop))
    }

    /// Stops playback where the clock is now.
    fn pause(&mut self) {
        self.advance_playback();
        self.playing = None;
    }

    /// Playback goes on from the playhead a Seek or StepFrame just moved.
    fn reanchor_playback(&mut self) {
        if let (Some(playing), Some(clock)) = (self.playing.as_mut(), self.clock.as_ref()) {
            *playing = (clock.now(), self.playhead);
        }
    }

    /// PlayheadChanged at the playhead, unsnapped: e.g. to tell the UI playback stopped after
    /// a step failed.
    pub fn playhead_event(&self) -> Event {
        self.playhead_changed(false)
    }

    /// PlayheadChanged at the playhead.
    fn playhead_changed(&self, snapped: bool) -> Event {
        Event {
            kind: Some(proto::event::Kind::PlayheadChanged(
                proto::PlayheadChanged {
                    time: self.playhead.0,
                    snapped,
                    active_clip: self.active_clip(),
                    playing: self.is_playing(),
                },
            )),
        }
    }

    /// Lets this engine make thumbnails through `host`; without it RequestThumbnails fails.
    pub fn with_thumbnails(self, host: Box<dyn crate::thumbnail::ThumbnailHost>) -> Self {
        Self {
            thumbnails: Some(crate::thumbnail::Thumbnails::new(host)),
            ..self
        }
    }

    /// Lets this engine make preview proxies through `host`; without it the preview always
    /// decodes the originals.
    pub fn with_proxies(self, host: Box<dyn crate::proxy::ProxyHost>) -> Self {
        Self {
            proxies: Some(crate::proxy::Proxies::new(host)),
            ..self
        }
    }

    /// The platform's answer to one proxy request: a made proxy redraws the preview from it.
    /// Starts the next queued request either way.
    pub fn proxy_ready(&mut self, key: crate::proxy::ProxyKey, made: Result<(), String>) {
        let Some(proxies) = self.proxies.as_mut() else {
            return;
        };
        if proxies.finish(key, made.is_ok()) {
            self.redraw_if_changed();
            self.draw_stale();
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
    /// timeline, or [`CommandFailed`] with the timeline unchanged. Draws the preview before it
    /// returns; a lost preview is reported by [`Engine::flush_preview`].
    pub fn handle(&mut self, command: Command) -> Event {
        let event = self.handle_deferred(command);
        self.draw_stale();
        event
    }

    /// [`Engine::handle`] without the draw: the preview is only marked stale, so a burst of
    /// commands (a scrub's Seeks) draws once, at the next [`Engine::flush_preview`].
    pub fn handle_deferred(&mut self, command: Command) -> Event {
        answering(command.id, self.reply(command.kind))
    }

    fn reply(&mut self, kind: Option<command::Kind>) -> Event {
        let Some(kind) = kind else {
            return command_failed("command has no kind");
        };
        match self.apply(kind) {
            // An edit may have shortened the timeline under the playhead.
            Ok(reply @ (Reply::Timeline | Reply::Snapped)) => {
                if let Some(proxies) = self.proxies.as_mut() {
                    proxies.ask(self.history.timeline());
                }
                // An edit may have shortened the timeline under the playhead, or changed what
                // shows there.
                self.move_playhead(self.playhead);
                self.redraw_if_changed();
                let mut event = self.timeline_changed();
                if let Some(proto::event::Kind::TimelineChanged(t)) = event.kind.as_mut() {
                    t.snapped = matches!(reply, Reply::Snapped);
                }
                event
            }
            Ok(Reply::Playhead(snapped)) => self.playhead_changed(snapped),
            Ok(Reply::Saved) => Event {
                kind: Some(proto::event::Kind::ProjectSaved(ProjectSaved {})),
            },
            Ok(Reply::NoSpace { needed, free }) => Event {
                kind: Some(proto::event::Kind::ExportFinished(proto::ExportFinished {
                    ok: false,
                    reason: "not enough storage".into(),
                    cancelled: false,
                    needed_bytes: needed,
                    free_bytes: free,
                })),
            },
            Ok(Reply::Projects(projects)) => Event {
                kind: Some(proto::event::Kind::ProjectList(proto::ProjectList {
                    projects,
                    folders: Vec::new(),
                })),
            },
            Ok(Reply::Accepted) => Event {
                kind: Some(proto::event::Kind::CommandAccepted(
                    proto::CommandAccepted::default(),
                )),
            },
            Err(reason) => command_failed(reason),
        }
    }

    fn apply(&mut self, kind: command::Kind) -> Result<Reply, String> {
        let timeline = |r: Result<(), String>| r.map(|()| Reply::Timeline);
        // A snapping edit's reply: whether the engine moved what was dropped onto a snap point.
        let snapped = |r: Result<(), String>, snapped: bool| {
            r.map(|()| {
                if snapped {
                    Reply::Snapped
                } else {
                    Reply::Timeline
                }
            })
        };
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
                let file = match self.library.clone() {
                    Some(dir) => {
                        self.save_current()?;
                        let id = crate::library::new_id(self.store()?, &dir)?;
                        crate::library::path(&dir, &id)
                    }
                    None => None,
                };
                self.history = History::default();
                if file.is_some() {
                    self.autosave_to(file, Timeline::default());
                }
                self.start_project();
                Ok(Reply::Timeline)
            }
            command::Kind::OpenProject(open) if self.library.is_some() => {
                timeline(self.open_from_library(&open.id))
            }
            command::Kind::OpenProject(open) => timeline(self.open(&open.path).map(|()| {
                self.start_project();
            })),
            command::Kind::OpenLibrary(op) => self.open_library(op.dir).map(|()| Reply::Accepted),
            command::Kind::ListProjects(_) => {
                let dir = self.library.clone().ok_or("no library")?;
                // A failed save was reported by autosave; the list still shows the last save.
                let _ = self.autosave();
                crate::library::list(self.store()?, &dir).map(Reply::Projects)
            }
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
            command::Kind::SetPhotoDuration(op) => {
                timeline(self.edit(|tl| tl.set_photo_durations(Time(op.duration))))
            }
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
            command::Kind::SnapMove(op) => {
                let id = ClipId(op.clip_id);
                let within = snap_tolerance(op.snap_within)?;
                let tl = self.history.timeline();
                let clip = tl
                    .clip(id)
                    .ok_or_else(|| TimelineError::UnknownClip(id).to_string())?;
                // On its own track the clip's old edges are no targets (a small move stays);
                // on another track landing on the same time is a fair target.
                let to = TrackId(op.track_id);
                let same_track = tl
                    .track(to)
                    .is_some_and(|t| t.clips().iter().any(|c| c.id == id));
                let snap = |t: Time| match same_track {
                    true => tl.snap_trim(id, t, within),
                    false => tl.snap(t, within),
                };
                // A start dropped before 0 lands at 0, not on an edge near it.
                let dropped = Time(op.start.max(0));
                let start = match within.0 > 0 && op.start >= 0 {
                    true => snap_span(snap, dropped, clip.duration),
                    false => dropped,
                };
                snapped(
                    self.edit(|tl| tl.move_clip(id, to, start)),
                    start != dropped,
                )
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
            command::Kind::EnableAutosave(op) => timeline(self.enable_autosave(&op.path)),
            command::Kind::CancelExport(_) => self.cancel_export().map(|()| Reply::Accepted),
            command::Kind::ExportProject(op) => self.start_export(op.path),
            command::Kind::FixBitrate(_) => timeline(self.edit(|tl| {
                let settings = tl.export();
                let kbps = settings.effective_kbps(tl.aspect());
                // effective_kbps stays inside KBPS_RANGE, so this is always Some.
                let bitrate = Bitrate::kbps(kbps).unwrap_or(settings.bitrate);
                tl.set_export(ExportSettings {
                    bitrate,
                    ..settings
                });
                Ok::<_, TimelineError>(())
            })),
            command::Kind::ChangeExportSettings(op) => {
                let current = export_proto(self.history.timeline().export());
                let settings = export_settings(proto::SetExportSettings {
                    resolution: op.resolution.unwrap_or(current.resolution),
                    fps: op.fps.unwrap_or(current.fps),
                    kbps: op.kbps.unwrap_or(current.kbps),
                })?;
                timeline(self.edit(|tl| {
                    tl.set_export(settings);
                    Ok::<_, TimelineError>(())
                }))
            }
            command::Kind::SetExportSettings(op) => {
                let settings = export_settings(op)?;
                timeline(self.edit(|tl| {
                    tl.set_export(settings);
                    Ok::<_, TimelineError>(())
                }))
            }
            command::Kind::ReplaceClip(op) => {
                let media = media_from_item(op.media.ok_or("replace without media")?)?;
                timeline(self.edit(|tl| tl.replace_clip(ClipId(op.clip_id), media).map(drop)))
            }
            command::Kind::SetClipTransform(op) => {
                let turns = match op.rotation {
                    0 => 0,
                    90 => 1,
                    180 => 2,
                    270 => 3,
                    other => return Err(format!("rotation {other} is not a quarter turn")),
                };
                let transform = timeline::ClipTransform {
                    turns,
                    flip_h: op.flip_h,
                    flip_v: op.flip_v,
                    crop: timeline::Crop {
                        left: op.crop_left,
                        top: op.crop_top,
                        right: op.crop_right,
                        bottom: op.crop_bottom,
                    },
                    x: op.x,
                    y: op.y,
                    // 0 is what senders before P1-030 leave unset: fit.
                    scale: if op.scale == 0 {
                        timeline::FIT_SCALE
                    } else {
                        op.scale
                    },
                };
                let set = |tl: &mut Timeline| tl.set_clip_transform(ClipId(op.clip_id), transform);
                let applied = if op.gesture == 0 {
                    self.history.apply(set)
                } else {
                    self.history.apply_merged(op.gesture, set)
                };
                timeline(applied.map_err(|e| e.to_string()))
            }
            command::Kind::Seek(seek) => {
                let within = snap_tolerance(seek.snap_within)?;
                let snapped = (within.0 > 0)
                    .then(|| self.history.timeline().snap(Time(seek.time), within))
                    .flatten();
                self.move_playhead(snapped.unwrap_or(Time(seek.time)));
                self.reanchor_playback();
                Ok(Reply::Playhead(snapped.is_some()))
            }
            command::Kind::SnapTrim(op) => {
                let id = ClipId(op.clip_id);
                let (start, end) = (Time(op.start), Time(op.end));
                let within = snap_tolerance(op.snap_within)?;
                let tl = self.history.timeline();
                let clip = tl
                    .clip(id)
                    .ok_or_else(|| TimelineError::UnknownClip(id).to_string())?;
                // Only a moved edge snaps; the clip's own edges are no targets.
                let snap = |t: Time, old: Time| match t != old && within.0 > 0 {
                    true => tl.snap_trim(id, t, within).unwrap_or(t),
                    false => t,
                };
                let (mut s, mut e) = (snap(start, clip.start), snap(end, clip.end()));
                // An edge snapped onto the other one would leave nothing: keep it where dropped.
                if e <= s {
                    (s, e) = if s != start { (start, e) } else { (s, end) };
                }
                let moved = (s, e) != (start, end);
                snapped(
                    self.edit(|tl| tl.trim_clip(ClipId(op.clip_id), s, e)),
                    moved,
                )
            }
            command::Kind::ApplyExportPreset(op) => {
                let preset = match proto::ExportPreset::try_from(op.preset) {
                    Ok(proto::ExportPreset::ShortVideo) => Preset::ShortVideo,
                    Ok(proto::ExportPreset::Youtube) => Preset::YouTube,
                    Ok(proto::ExportPreset::InstagramFeed) => Preset::InstagramFeed,
                    _ => return Err(format!("unknown export preset {}", op.preset)),
                };
                timeline(self.edit(|tl| {
                    tl.set_aspect(preset.aspect());
                    tl.set_export(preset.settings());
                    Ok::<_, TimelineError>(())
                }))
            }
            command::Kind::TrimToPlayhead(op) => {
                let id = ClipId(op.clip_id);
                let start_edge = match proto::ClipEdge::try_from(op.edge) {
                    Ok(proto::ClipEdge::Start) => true,
                    Ok(proto::ClipEdge::End) => false,
                    _ => return Err(format!("unknown clip edge {}", op.edge)),
                };
                let at = self.playhead;
                timeline(self.edit(|tl| {
                    let clip = tl.clip(id).ok_or(TimelineError::UnknownClip(id))?;
                    let (start, end) = if start_edge {
                        (at, clip.end())
                    } else {
                        (clip.start, at)
                    };
                    tl.trim_clip(id, start, end)
                }))
            }
            command::Kind::StepFrame(op) => {
                let rate = self.history.timeline().export().fps.rate();
                // Out of range only past the largest time: the clamp puts it at the end.
                let to = rate
                    .step(self.playhead, i64::from(op.frames))
                    .unwrap_or(Time(i64::MAX));
                self.move_playhead(to);
                self.reanchor_playback();
                Ok(Reply::Playhead(false))
            }
            command::Kind::Play(_) => self.play().map(|()| Reply::Playhead(false)),
            command::Kind::SetLoop(op) => {
                self.loop_range = (op.end > op.start).then_some((Time(op.start), Time(op.end)));
                Ok(Reply::Timeline)
            }
            command::Kind::RenameProject(_) | command::Kind::MoveProject(_) => {
                Err("not implemented".into())
            }
            command::Kind::Pause(_) => {
                self.pause();
                Ok(Reply::Playhead(false))
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

    /// The clip canvas gestures act on at the playhead; 0 for none.
    fn active_clip(&self) -> u64 {
        self.history
            .timeline()
            .top_clip_at(self.playhead)
            .map_or(0, |c| c.0)
    }

    /// After the timeline was replaced by another project: it starts at its beginning, with
    /// its own media ids, so cached thumbnails and the drawn picture's key mean nothing now.
    fn start_project(&mut self) {
        self.project = self.project.wrapping_add(1);
        self.forget_thumbnails();
        self.playing = None;
        self.loop_range = None;
        self.playhead = Time(0);
        self.redraw();
    }

    fn forget_thumbnails(&mut self) {
        if let Some(thumbnails) = self.thumbnails.as_mut() {
            thumbnails.reset(self.project);
        }
        if let Some(proxies) = self.proxies.as_mut() {
            proxies.reset(self.project);
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

    /// Sets the library folder once; refused next to EnableAutosave's single file.
    fn open_library(&mut self, dir: String) -> Result<(), String> {
        let dir = PathBuf::from(dir);
        if !dir.is_absolute() {
            return Err("the library folder must be an absolute path".into());
        }
        match &self.library {
            Some(on) if *on == dir => Ok(()),
            Some(_) => Err("the library is already open on another folder".into()),
            None if self.autosave.is_some() => Err("autosave is on for a single file".into()),
            None => {
                self.library = Some(dir);
                Ok(())
            }
        }
    }

    /// Saves the current project before another one replaces it; refused if that fails, so
    /// switching never loses edits.
    fn save_current(&mut self) -> Result<(), String> {
        let _ = self.autosave();
        match self.autosave_pending() {
            true => Err("the current project could not be saved".into()),
            false => Ok(()),
        }
    }

    /// Autosaves to `file` from now on; `saved` is what the file holds (nothing new to save).
    fn autosave_to(&mut self, file: Option<PathBuf>, saved: Timeline) {
        self.autosave = file;
        self.autosaved = saved;
        self.autosave_failed = false;
    }

    /// Opens library project `id` and autosaves there; the current project is saved first.
    fn open_from_library(&mut self, id: &str) -> Result<(), String> {
        let dir = self.library.as_deref().ok_or("no library")?;
        let file = crate::library::path(dir, id).ok_or("malformed project id")?;
        // Save first: reading first would load stale bytes when `id` is the open project.
        self.save_current()?;
        let store = self.store()?;
        let (timeline, from_backup) =
            store::load_or_backup(store, &file).map_err(|e| e.to_string())?;
        let saved = if from_backup {
            // Best effort: if it stays, the write-back rotates it into .bak1 and the good copy
            // is still the file and .bak2.
            let _ = store.set_aside(&file);
            write_back(store, &file, &timeline)
        } else {
            timeline.clone()
        };
        self.history = History::new(timeline);
        self.autosave_to(Some(file), saved);
        self.start_project();
        Ok(())
    }

    /// Recovers the project at `path` if there is one, then autosaves there. A damaged file is
    /// set aside and its newest good backup recovered (written back at once); a file from a
    /// newer app, one the OS won't read, or one that can't be set aside is refused and kept.
    fn enable_autosave(&mut self, path: &str) -> Result<(), String> {
        if self.library.is_some() {
            return Err("autosave is per project in the library".into());
        }
        let path = PathBuf::from(path);
        // Already on (a retry or a lifecycle repeat): reloading would drop unsaved edits.
        if let Some(on) = &self.autosave {
            return if *on == path {
                Ok(())
            } else {
                Err("autosave is already on for another file".into())
            };
        }
        let store = self.store()?;
        let recovered = match store::load_or_backup(store, &path) {
            Ok(loaded) => Some(loaded),
            // Nothing saved yet: the current project is new work to save.
            Err(LoadError::Missing) => None,
            // Broken with no good backup: the current project is new work, as above.
            Err(e) if e.is_broken() => {
                set_aside(store, &path, &e)?;
                None
            }
            Err(e) => return Err(e.to_string()),
        };
        if let Some((_, true)) = &recovered {
            set_aside(store, &path, &"broken autosave file")?;
        }
        let saved = match &recovered {
            Some((timeline, false)) => timeline.clone(),
            Some((timeline, true)) => write_back(store, &path, timeline),
            // New work: the first autosave writes it.
            None => Timeline::default(),
        };
        if let Some((timeline, _)) = recovered {
            self.history = History::new(timeline);
            self.start_project();
        }
        self.autosave_to(Some(path), saved);
        Ok(())
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
                // The picture's frame on the canvas; nothing for a clip without its media.
                let frame = |c: &timeline::Clip| {
                    timeline.media(c.media).map_or((0.0, 0.0), |m| {
                        framix_core::placement::picture_size(m, &c.transform, timeline.aspect())
                    })
                };
                proto::Track {
                    id: t.id().0,
                    kind: kind as i32,
                    clips: t
                        .clips()
                        .iter()
                        .enumerate()
                        .map(|(i, c)| (i, c, frame(c)))
                        .map(|(i, c, (frame_width, frame_height))| proto::Clip {
                            id: c.id.0,
                            media_id: c.media.0,
                            source_start: c.source_start.0,
                            start: c.start.0,
                            duration: c.duration.0,
                            media_kind: match timeline.media(c.media).map(Media::kind) {
                                Some(media::MediaKind::Video) => proto::MediaKind::Video,
                                Some(media::MediaKind::Image) => proto::MediaKind::Image,
                                Some(media::MediaKind::Color) => proto::MediaKind::Color,
                                None => proto::MediaKind::Unspecified,
                            } as i32,
                            color: timeline.media(c.media).map_or(0, Media::color),
                            rotation: u32::from(c.transform.turns) * 90,
                            flip_h: c.transform.flip_h,
                            flip_v: c.transform.flip_v,
                            crop_left: c.transform.crop.left,
                            crop_top: c.transform.crop.top,
                            crop_right: c.transform.crop.right,
                            crop_bottom: c.transform.crop.bottom,
                            x: c.transform.x,
                            y: c.transform.y,
                            scale: c.transform.scale,
                            mergeable_with_next: t.mergeable_with_next(i),
                            // A locked track refuses every edit (SetClipTransform included).
                            placement_locked: t.flags().locked || !timeline.placeable(c.media),
                            frame_width,
                            frame_height,
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
                active_clip: self.active_clip(),
                export: Some(export_info(timeline)),
                project: self.project,
                // `reply` sets it for the answer to a snapping edit.
                snapped: false,
                playing: self.is_playing(),
                loop_start: self.loop_range.map_or(0, |(start, _)| start.0),
                loop_end: self.loop_range.map_or(0, |(_, end)| end.0),
            })),
        }
    }
}

/// Where a clip of `duration` dropped at `start` lands: its start or its end, whichever is
/// nearer to a `snap` point (the start on a tie), moves onto that point; never before 0.
fn snap_span(snap: impl Fn(Time) -> Option<Time>, start: Time, duration: Time) -> Time {
    let by_start = snap(start).map(|s| s.0 - start.0);
    let end = start.0.saturating_add(duration.0);
    let by_end = snap(Time(end)).map(|e| e.0 - end);
    let shift = match (by_start, by_end) {
        (Some(a), Some(b)) => {
            if b.abs() < a.abs() {
                b
            } else {
                a
            }
        }
        (a, b) => a.or(b).unwrap_or(0),
    };
    // `start` is untrusted; move_clip refuses a span that does not fit.
    Time(start.0.saturating_add(shift).max(0))
}

/// A snap tolerance from a command: negative is refused, more than [`MAX_SNAP`] is capped.
fn snap_tolerance(within: i64) -> Result<Time, String> {
    if within < 0 {
        return Err("negative snap tolerance".into());
    }
    Ok(Time(within.min(MAX_SNAP.0)))
}

/// The layers at the playhead as the preview draws them: each from its proxy once that is ready.
fn preview_layers<'a>(
    timeline: &'a Timeline,
    playhead: Time,
    proxies: Option<&'a crate::proxy::Proxies>,
) -> impl Iterator<Item = Layer<'a>> + Clone {
    timeline.layers_at(playhead).map(move |l| Layer {
        proxy_side: proxies.and_then(|p| p.side(l.media_id)),
        ..l
    })
}

/// Records what a draw showed, reusing the list's memory.
fn remember<'a>(drawn: &mut Vec<LayerKey>, layers: impl Iterator<Item = Layer<'a>>) {
    drawn.clear();
    drawn.extend(layers.map(|l| l.key()));
}

/// What a successful command reports.
enum Reply {
    /// The timeline (changed or not).
    Timeline,
    /// The timeline after a SnapTrim or SnapMove that landed on a snap point.
    Snapped,
    /// The project was saved.
    Saved,
    /// Work started; its result comes later as its own event.
    Accepted,
    /// The library's projects (ListProjects).
    Projects(Vec<proto::ProjectSummary>),
    /// Where the playhead is now, and whether the seek snapped.
    Playhead(bool),
    /// An export was refused before it started: it needs about `needed` bytes, `free` are free.
    NoSpace {
        /// Bytes the export needs.
        needed: u64,
        /// Bytes free.
        free: u64,
    },
}

/// `event` as the reply to command `id`: CommandAccepted and CommandFailed carry the id.
pub fn answering(id: u64, mut event: Event) -> Event {
    match &mut event.kind {
        Some(proto::event::Kind::CommandFailed(f)) => f.command_id = id,
        Some(proto::event::Kind::CommandAccepted(a)) => a.command_id = id,
        _ => {}
    }
    event
}

/// The event for a rejected command. `reason` is for logs, not for display.
pub fn command_failed(reason: impl Into<String>) -> Event {
    Event {
        kind: Some(proto::event::Kind::CommandFailed(CommandFailed {
            reason: reason.into(),
            // `Engine::handle` fills in the command's id.
            command_id: 0,
        })),
    }
}

fn export_settings(op: proto::SetExportSettings) -> Result<ExportSettings, String> {
    let resolution = match proto::ExportResolution::try_from(op.resolution) {
        Ok(proto::ExportResolution::ExportResolution720p) => Resolution::P720,
        Ok(proto::ExportResolution::ExportResolution1080p) => Resolution::P1080,
        Ok(proto::ExportResolution::ExportResolution2k) => Resolution::P2K,
        Ok(proto::ExportResolution::ExportResolution4k) => Resolution::P4K,
        _ => return Err(format!("unknown export resolution {}", op.resolution)),
    };
    let fps = match proto::ExportFps::try_from(op.fps) {
        Ok(proto::ExportFps::ExportFps24) => FrameRate::F24,
        Ok(proto::ExportFps::ExportFps30) => FrameRate::F30,
        Ok(proto::ExportFps::ExportFps60) => FrameRate::F60,
        _ => return Err(format!("unknown export frame rate {}", op.fps)),
    };
    let bitrate = match op.kbps {
        0 => Bitrate::Auto,
        kbps => Bitrate::kbps(kbps).ok_or_else(|| format!("bitrate {kbps} kbps out of range"))?,
    };
    Ok(ExportSettings {
        resolution,
        fps,
        bitrate,
    })
}

/// `settings` on the wire: the inverse of [`export_settings`].
fn export_proto(settings: ExportSettings) -> proto::SetExportSettings {
    proto::SetExportSettings {
        resolution: match settings.resolution {
            Resolution::P720 => proto::ExportResolution::ExportResolution720p,
            Resolution::P1080 => proto::ExportResolution::ExportResolution1080p,
            Resolution::P2K => proto::ExportResolution::ExportResolution2k,
            Resolution::P4K => proto::ExportResolution::ExportResolution4k,
        } as i32,
        fps: match settings.fps {
            FrameRate::F24 => proto::ExportFps::ExportFps24,
            FrameRate::F30 => proto::ExportFps::ExportFps30,
            FrameRate::F60 => proto::ExportFps::ExportFps60,
        } as i32,
        kbps: match settings.bitrate {
            Bitrate::Auto => 0,
            Bitrate::Kbps(kbps) => kbps,
        },
    }
}

fn export_info(timeline: &Timeline) -> proto::ExportInfo {
    let settings = timeline.export();
    let (width, height) = settings.frame_size(timeline.aspect());
    let wire = export_proto(settings);
    proto::ExportInfo {
        resolution: wire.resolution,
        fps: wire.fps,
        kbps: wire.kbps,
        width,
        height,
        effective_kbps: settings.effective_kbps(timeline.aspect()),
        estimated_bytes: settings.estimated_bytes(timeline.aspect(), timeline.duration()),
        min_kbps: *framix_core::export::KBPS_RANGE.start(),
        max_kbps: *framix_core::export::KBPS_RANGE.end(),
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
        Ok(proto::MediaKind::Color) if item.uri.is_empty() => return Ok(Media::solid(item.color)),
        Ok(proto::MediaKind::Color) => return Err("a color item has no file".into()),
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

/// Moves a broken autosave file aside so autosave can go on; refused (autosave stays off and
/// the file is kept) when the store can't.
fn set_aside(
    store: &dyn ProjectStore,
    path: &Path,
    why: &dyn std::fmt::Display,
) -> Result<(), String> {
    store
        .set_aside(path)
        .map_err(|e| format!("{why}; could not set it aside: {}", e.kind()))
}

/// Writes a project recovered from a backup back to `path` at once, so a crash or Home never
/// finds the file missing. Returns what autosave should treat as saved: the project, or an
/// empty one when the write failed, so the next autosave retries and reports it.
fn write_back(store: &dyn ProjectStore, path: &Path, timeline: &Timeline) -> Timeline {
    let written = project::encode_for_save(timeline)
        .ok()
        .is_some_and(|bytes| store.save(path, &bytes).is_ok());
    if written {
        timeline.clone()
    } else {
        Timeline::default()
    }
}
