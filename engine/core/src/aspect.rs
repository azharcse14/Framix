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
    pub fn new(width: u32, height: u32) -> Option<Self> {
        let side = 1..=100;
        if !side.contains(&width) || !side.contains(&height) {
            return None;
        }
        if width > 3 * height || height > 3 * width {
            return None;
        }
        let g = gcd(width, height);
        Some(Self {
            width: width / g,
            height: height / g,
        })
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

fn gcd(a: u32, b: u32) -> u32 {
    if b == 0 { a } else { gcd(b, a % b) }
}
