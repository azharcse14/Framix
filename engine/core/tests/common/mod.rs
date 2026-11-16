//! Shared test helpers.

use framix_core::media::Media;
use framix_core::time::Time;
use framix_core::timeline::{MediaId, Timeline};

/// An empty timeline with media 1 and 2 registered (missing videos), since
/// `Timeline::insert_clip` refuses clips on unregistered media (ENG-059).
pub fn timeline() -> Timeline {
    let mut tl = Timeline::default();
    for id in [1, 2] {
        tl.restore_media(
            MediaId(id),
            Media::missing(Time(1)).expect("1 tick is valid"),
        );
    }
    tl
}
