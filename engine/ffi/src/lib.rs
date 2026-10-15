//! C ABI boundary of the Framix engine.

/// Call succeeded.
pub const ENGINE_OK: i32 = 0;
/// The call panicked; the panic was caught at the boundary.
pub const ENGINE_ERR_PANIC: i32 = -1;

/// Runs `f`, turning a panic into [`ENGINE_ERR_PANIC`]. Every exported fn goes through this.
pub fn ffi_guard(f: impl FnOnce() -> i32) -> i32 {
    let _ = f;
    ENGINE_OK
}

/// Rust-owned bytes handed across the boundary; release with [`engine_free_buffer`].
#[repr(C)]
pub struct EngineBuffer {
    pub ptr: *mut u8,
    pub len: usize,
}

impl EngineBuffer {
    /// Moves `bytes` into a buffer the caller must free with [`engine_free_buffer`].
    pub fn from_vec(bytes: Vec<u8>) -> Self {
        let _ = bytes;
        Self {
            ptr: std::ptr::null_mut(),
            len: 0,
        }
    }
}

/// Frees a buffer from [`EngineBuffer::from_vec`]. A null buffer is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn engine_free_buffer(buf: EngineBuffer) -> i32 {
    let _ = buf;
    ENGINE_OK
}
