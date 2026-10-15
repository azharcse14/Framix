//! Canvas aspect ratio.

/// Width:height of the canvas, always reduced (9:16, never 18:32).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct AspectRatio {
    width: u32,
    height: u32,
}

impl AspectRatio {
    /// Vertical video, the default canvas until import picks one from the first clip.
    pub const PORTRAIT_9_16: Self = Self {
        width: 9,
        height: 16,
    };

    /// `width:height` reduced, or `None` unless both sides are 1..=100 and the ratio lies
    /// between 1:3 and 3:1.
    pub fn new(_width: u32, _height: u32) -> Option<Self> {
        None
    }

    /// Reduced width.
    pub fn width(self) -> u32 {
        self.width
    }

    /// Reduced height.
    pub fn height(self) -> u32 {
        self.height
    }
}

impl Default for AspectRatio {
    fn default() -> Self {
        Self::PORTRAIT_9_16
    }
}
