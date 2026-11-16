//! Shared test helpers.

use framix_core::media::Media;
use framix_core::time::{TICKS_PER_SECOND, Time};
use framix_core::timeline::{MediaId, Timeline};

/// An empty timeline with media 1 and 2 registered (missing videos), since
/// `Timeline::insert_clip` refuses clips on unregistered media (ENG-059). They are as long as a
/// video may be (24 h), so a test's source range stays inside them (ENG-053).
pub fn timeline() -> Timeline {
    let mut tl = Timeline::default();
    for id in [1, 2] {
        tl.restore_media(
            MediaId(id),
            Media::missing(Time(24 * 3600 * TICKS_PER_SECOND)).expect("24 h is valid"),
        );
    }
    tl
}
