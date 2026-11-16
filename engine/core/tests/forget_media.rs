//! ENG-055 review: forgetting media never unregisters media a clip of the timeline uses.

use std::collections::BTreeSet;

use framix_core::media::Media;
use framix_core::timeline::Timeline;

#[test]
fn forget_keeps_media_its_own_clips_use() {
    let mut tl = Timeline::default();
    let clips = tl.import(vec![Media::solid(1), Media::solid(2)]).unwrap();
    let media = tl.clip(clips[0]).unwrap().media;
    tl.remove_clip(clips[1]).unwrap();
    tl.forget_media_except(&BTreeSet::new());
    assert!(tl.media(media).is_some());
    assert_eq!(tl.all_media().count(), 1);
}
