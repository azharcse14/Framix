//! What an export produces: frame size, frame rate and bitrate (P1-032). The encoder and the
//! export flow come later; they read these settings.

use crate::aspect::AspectRatio;
use crate::time::{Rate, TICKS_PER_SECOND, Time};

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

/// Audio bitrate of an export (AAC stereo), in kbit/s.
pub const AUDIO_KBPS: u32 = 128;

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
    pub fn kbps(kbps: u32) -> Option<Self> {
        KBPS_RANGE.contains(&kbps).then_some(Self::Kbps(kbps))
    }
}

impl Resolution {
    /// The frame's short side in pixels.
    pub fn short_side(self) -> u32 {
        match self {
            Self::P720 => 720,
            Self::P1080 => 1080,
            Self::P2K => 1440,
            Self::P4K => 2160,
        }
    }
}

impl FrameRate {
    /// The rate as frames per second.
    pub fn rate(self) -> Rate {
        Rate::whole(self.per_second())
    }

    /// Frames per second.
    pub fn per_second(self) -> u32 {
        match self {
            Self::F24 => 24,
            Self::F30 => 30,
            Self::F60 => 60,
        }
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
    pub fn frame_size(&self, aspect: AspectRatio) -> (u32, u32) {
        let short = self.resolution.short_side();
        let (w, h) = (aspect.width(), aspect.height());
        // The long side, rounded to the nearest even pixel: 2 * round(short * long / (2 * other)).
        let long = |long: u32, other: u32| {
            let (n, d) = (u64::from(short) * u64::from(long), 2 * u64::from(other));
            // short <= 2160 and aspect sides are small, so this fits u32.
            u32::try_from(2 * ((n + d / 2) / d)).unwrap_or(u32::MAX)
        };
        if w <= h {
            (short, long(h, w))
        } else {
            (long(w, h), short)
        }
    }

    /// About how many bytes an export of `duration` makes: video plus audio bitrate, plus
    /// ~1 % container overhead, rounded up.
    pub fn estimated_bytes(&self, aspect: AspectRatio, duration: Time) -> u64 {
        // ponytail: audio is counted even without audio clips; drop it once audio tracks
        // carry clips and the timeline can say it has none.
        let kbps = u128::from(self.effective_kbps(aspect)) + u128::from(AUDIO_KBPS);
        let ticks = u128::try_from(duration.0).unwrap_or(0);
        // kbps * 1000 / 8 bytes per second, * ticks / TICKS_PER_SECOND, * 101 / 100, rounded up.
        let num = kbps * 1000 * ticks * 101;
        let den = 8 * u128::from(TICKS_PER_SECOND.unsigned_abs()) * 100;
        u64::try_from(num.div_ceil(den)).unwrap_or(u64::MAX)
    }

    /// The bitrate the encoder gets, in kbit/s.
    pub fn effective_kbps(&self, aspect: AspectRatio) -> u32 {
        match self.bitrate {
            Bitrate::Kbps(kbps) => kbps,
            Bitrate::Auto => {
                // About 0.1 bit per pixel per frame.
                let (w, h) = self.frame_size(aspect);
                let bits = u64::from(w) * u64::from(h) * u64::from(self.fps.per_second()) / 10;
                let kbps = u32::try_from(bits / 1000).unwrap_or(u32::MAX);
                kbps.clamp(*KBPS_RANGE.start(), *KBPS_RANGE.end())
            }
        }
    }
}
