//! What an export produces: frame size, frame rate and bitrate (P1-032). The encoder and the
//! export flow come later; they read these settings.

use crate::aspect::AspectRatio;
use crate::time::Rate;

/// Output size class, by the frame's short side.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum Resolution {
    /// 720 px short side.
    P720,
    /// 1080 px short side.
    #[default]
    P1080,
    /// 1440 px short side.
    P2K,
    /// 2160 px short side.
    P4K,
}

/// Output frame rate.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FrameRate {
    /// 24 fps.
    F24,
    /// 30 fps.
    #[default]
    F30,
    /// 60 fps.
    F60,
}

/// Lowest and highest bitrate a user may set, in kbit/s.
pub const KBPS_RANGE: std::ops::RangeInclusive<u32> = 1_000..=150_000;

/// Output bitrate: chosen from the frame size and rate, or set by the user.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum Bitrate {
    /// Picked from pixels per second.
    #[default]
    Auto,
    /// Set by the user, in kbit/s; build with [`Bitrate::kbps`].
    Kbps(u32),
}

impl Bitrate {
    /// A set bitrate, if inside [`KBPS_RANGE`].
    pub fn kbps(_kbps: u32) -> Option<Self> {
        None
    }
}

impl Resolution {
    /// The frame's short side in pixels.
    pub fn short_side(self) -> u32 {
        0
    }
}

impl FrameRate {
    /// The rate as frames per second.
    pub fn rate(self) -> Rate {
        Rate::new(1, 1).expect("1/1 is a valid rate")
    }
}

/// How the project exports.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct ExportSettings {
    /// Size class.
    pub resolution: Resolution,
    /// Frame rate.
    pub fps: FrameRate,
    /// Bitrate.
    pub bitrate: Bitrate,
}

impl ExportSettings {
    /// Output width and height for a canvas of `aspect`: the short side from the resolution,
    /// the long side from the aspect, both even (encoders need even sizes).
    pub fn frame_size(&self, _aspect: AspectRatio) -> (u32, u32) {
        (0, 0)
    }

    /// The bitrate the encoder gets, in kbit/s.
    pub fn effective_kbps(&self, _aspect: AspectRatio) -> u32 {
        0
    }
}
