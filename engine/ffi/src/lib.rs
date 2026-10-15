//! C ABI boundary of the Framix engine.

/// Call succeeded.
pub const ENGINE_OK: i32 = 0;
/// The call panicked; the panic was caught at the boundary.
pub const ENGINE_ERR_PANIC: i32 = -1;

/// Runs `f`, turning a panic into [`ENGINE_ERR_PANIC`]. Every exported fn goes through this.
pub fn ffi_guard(f: impl FnOnce() -> i32) -> i32 {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(f)).unwrap_or(ENGINE_ERR_PANIC)
}

/// Rust-owned bytes handed across the boundary; release with [`engine_free_buffer`].
#[repr(C)]
pub struct EngineBuffer {
    /// Start of the bytes; null means nothing to free.
    pub ptr: *mut u8,
    /// Number of bytes at `ptr`.
    pub len: usize,
}

impl EngineBuffer {
    /// Moves `bytes` into a buffer the caller must free with [`engine_free_buffer`].
    pub fn from_vec(bytes: Vec<u8>) -> Self {
        // A boxed slice has capacity == len, so `len` alone is enough to rebuild it on free.
        let len = bytes.len();
        let ptr = Box::into_raw(bytes.into_boxed_slice()).cast::<u8>();
        Self { ptr, len }
    }
}

/// Frees a buffer from [`EngineBuffer::from_vec`]. A null buffer is a no-op.
///
/// # Safety
/// A non-null `buf` must come from [`EngineBuffer::from_vec`] with `ptr` and `len` unchanged,
/// and must not be freed more than once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_free_buffer(buf: EngineBuffer) -> i32 {
    ffi_guard(|| {
        if !buf.ptr.is_null() {
            let slice = std::ptr::slice_from_raw_parts_mut(buf.ptr, buf.len);
            // SAFETY: the caller upholds this fn's contract: `buf` is an unchanged, not yet freed
            // Box<[u8]> of exactly `len` bytes leaked by `from_vec`, so ownership returns here.
            drop(unsafe { Box::from_raw(slice) });
        }
        ENGINE_OK
    })
}
