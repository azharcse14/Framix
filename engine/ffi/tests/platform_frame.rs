//! Decoded frames from the platform (P1-060): EngineFrame's C fields become the engine's Frame,
//! the engine picks the colour space from the platform's raw tags, and bad frames are refused.

use std::ffi::c_void;

use framix_app::preview::{Frame, YcbcrMatrix, YcbcrRange, YcbcrSpace};
use framix_ffi::{
    ENGINE_FRAME_NV12, ENGINE_FRAME_RGBA, ENGINE_RANGE_FULL, ENGINE_RANGE_UNKNOWN,
    ENGINE_YCBCR_601, ENGINE_YCBCR_UNKNOWN, EngineFrame,
};

fn ptr(v: usize) -> *mut c_void {
    v as *mut c_void
}

fn frame(format: u32, planes: [usize; 2], matrix: u32, range: u32) -> EngineFrame {
    EngineFrame {
        format,
        planes: [ptr(planes[0]), ptr(planes[1])],
        matrix,
        range,
    }
}

#[test]
fn nv12_keeps_both_planes_and_the_tagged_space() {
    let f = frame(ENGINE_FRAME_NV12, [0x10, 0x20], ENGINE_YCBCR_601, ENGINE_RANGE_FULL);
    assert_eq!(
        Frame::try_from(&f),
        Ok(Frame::Nv12 {
            y: 0x10,
            cbcr: 0x20,
            space: YcbcrSpace {
                matrix: YcbcrMatrix::Bt601,
                range: YcbcrRange::Full,
            },
        })
    );
}

#[test]
fn untagged_video_is_bt709_video_range() {
    let f = frame(
        ENGINE_FRAME_NV12,
        [0x10, 0x20],
        ENGINE_YCBCR_UNKNOWN,
        ENGINE_RANGE_UNKNOWN,
    );
    let Ok(Frame::Nv12 { space, .. }) = Frame::try_from(&f) else {
        panic!("nv12 expected");
    };
    assert_eq!(
        space,
        YcbcrSpace {
            matrix: YcbcrMatrix::Bt709,
            range: YcbcrRange::Video,
        }
    );
}

#[test]
fn rgba_uses_the_first_plane() {
    let f = frame(ENGINE_FRAME_RGBA, [0x30, 0], 0, 0);
    assert_eq!(Frame::try_from(&f), Ok(Frame::Rgba { texture: 0x30 }));
}

#[test]
fn missing_planes_and_unknown_formats_are_refused() {
    assert!(Frame::try_from(&frame(ENGINE_FRAME_NV12, [0x10, 0], 0, 0)).is_err());
    assert!(Frame::try_from(&frame(ENGINE_FRAME_RGBA, [0, 0], 0, 0)).is_err());
    assert!(Frame::try_from(&frame(99, [0x10, 0x20], 0, 0)).is_err());
}
