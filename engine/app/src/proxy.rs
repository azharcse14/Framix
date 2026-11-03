//! Port for preview proxies (P1-039, docs/adr/0007-proxy-media.md): the platform layer makes a
//! smaller copy of a big video; the engine decides which media get one, makes them one at a
//! time, and has the preview decode from a proxy once it is ready. Tests use fakes.

use std::collections::{BTreeMap, BTreeSet, VecDeque};

use framix_core::timeline::{MediaId, Timeline};

/// One proxy: a media and the proxy's longest side, within one project.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ProxyKey {
    /// Which project the request came from; media ids restart with each project, so a late
    /// answer for an earlier project must not match.
    pub generation: u64,
    /// Which media.
    pub media: MediaId,
    /// Longest side of the proxy in pixels.
    pub max_side: u32,
}

/// What the platform needs to make one proxy.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProxyRequest {
    /// Passed back with the answer.
    pub key: ProxyKey,
    /// The media reference, as imported.
    pub uri: String,
}

/// The platform layer (Swift/Kotlin) side. Calls must return at once; the answer comes back
/// through [`crate::engine::Engine::proxy_ready`]. A proxy that already exists is answered at
/// once.
pub trait ProxyHost: Send {
    /// Starts making one proxy. An error means nothing was started.
    fn request(&self, request: ProxyRequest) -> Result<(), String>;
}

/// Which proxies were asked for, which one is being made, and which are ready.
pub(crate) struct Proxies {
    host: Box<dyn ProxyHost>,
    /// Every media ever asked for: nothing is made twice.
    known: BTreeSet<MediaId>,
    /// Media whose proxy is ready, with its side.
    ready: BTreeMap<MediaId, u32>,
    /// Making a proxy is a whole-file encode, so only one runs.
    in_flight: Option<ProxyKey>,
    queue: VecDeque<ProxyRequest>,
    /// The engine's project number (Engine::start_project), the one home of that count.
    generation: u64,
}

impl Proxies {
    pub(crate) fn new(host: Box<dyn ProxyHost>) -> Self {
        Self {
            host,
            known: BTreeSet::new(),
            ready: BTreeMap::new(),
            in_flight: None,
            queue: VecDeque::new(),
            generation: 0,
        }
    }

    /// A new or opened project: forget everything; answers still on their way
    /// (keyed by the old `project`) are ignored.
    pub(crate) fn reset(&mut self, project: u64) {
        self.known.clear();
        self.ready.clear();
        self.in_flight = None;
        self.queue.clear();
        self.generation = project;
    }

    /// Queues a proxy for every media of `timeline` that needs one and was never asked for,
    /// then starts the next one if none runs.
    pub(crate) fn ask(&mut self, timeline: &Timeline) {
        for (id, media) in timeline.all_media() {
            let Some(max_side) = media.proxy_side() else {
                continue;
            };
            if self.known.insert(id) {
                self.queue.push_back(ProxyRequest {
                    key: ProxyKey {
                        generation: self.generation,
                        media: id,
                        max_side,
                    },
                    uri: media.uri().to_owned(),
                });
            }
        }
        self.start();
    }

    /// The platform answered `key`; true if that made a proxy ready. Starts the next one.
    pub(crate) fn finish(&mut self, key: ProxyKey, ok: bool) -> bool {
        if self.in_flight != Some(key) {
            return false;
        }
        self.in_flight = None;
        if ok {
            self.ready.insert(key.media, key.max_side);
        }
        self.start();
        ok
    }

    /// The side of `media`'s ready proxy, if it has one.
    pub(crate) fn side(&self, media: MediaId) -> Option<u32> {
        self.ready.get(&media).copied()
    }

    /// Starts the next queued request if none runs. If the platform refuses one, the rest of
    /// the queue is dropped too (the preview keeps the originals); media added later are asked
    /// for again.
    fn start(&mut self) {
        if self.in_flight.is_some() {
            return;
        }
        let Some(request) = self.queue.pop_front() else {
            return;
        };
        let key = request.key;
        match self.host.request(request) {
            Ok(()) => self.in_flight = Some(key),
            Err(_) => self.queue.clear(),
        }
    }
}
