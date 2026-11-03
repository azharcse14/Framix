//! Platform export presets (P1-037): one tap sets the canvas and the export settings.

use framix_core::aspect::AspectRatio;
use framix_core::export::{Bitrate, ExportSettings, FrameRate, Preset, Resolution};

#[test]
fn each_preset_has_its_platform_shape_at_1080p() {
    let full_hd = ExportSettings {
        resolution: Resolution::P1080,
        fps: FrameRate::F30,
        bitrate: Bitrate::Auto,
    };
    for (preset, w, h) in [
        (Preset::ShortVideo, 9, 16),
        (Preset::YouTube, 16, 9),
        (Preset::InstagramFeed, 4, 5),
    ] {
        assert_eq!(preset.aspect(), AspectRatio::new(w, h).unwrap(), "{preset:?}");
        assert_eq!(preset.settings(), full_hd, "{preset:?}");
        // 1080 px on the short side.
        let (fw, fh) = preset.settings().frame_size(preset.aspect());
        assert_eq!(fw.min(fh), 1080, "{preset:?}");
    }
}
