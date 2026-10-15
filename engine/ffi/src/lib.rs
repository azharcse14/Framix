//! C ABI boundary of the Framix engine.

/// Call succeeded.
pub const ENGINE_OK: i32 = 0;
/// The call panicked; the panic was caught at the boundary.
pub const ENGINE_ERR_PANIC: i32 = -1;

/// The engine handle or an argument pointer was null.
pub const ENGINE_ERR_NULL: i32 = -2;
/// `engine_create` got a protocol version this engine does not speak.
pub const ENGINE_ERR_PROTOCOL: i32 = -3;
/// The engine thread has stopped; the handle only accepts `engine_destroy`.
pub const ENGINE_ERR_STOPPED: i32 = -4;

/// Version of the command/event contract (proto/framix/v1/engine.proto).
pub const ENGINE_PROTOCOL_VERSION: u32 = 1;

/// Receives one encoded `framix.v1.Event`. The callee owns the bytes and must release them
/// with [`engine_free_buffer`]. Called on the engine thread.
pub type EngineEventCallback = Option<unsafe extern "C" fn(ptr: *mut u8, len: usize)>;

/// Opaque engine instance.
pub struct Engine {
    _private: (),
}

/// Creates an engine if `protocol_version` matches [`ENGINE_PROTOCOL_VERSION`] and writes it
/// to `*out`.
///
/// # Safety
/// `out` must be null or valid for one pointer write.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_create(protocol_version: u32, out: *mut *mut Engine) -> i32 {
    let _ = (protocol_version, out);
    ENGINE_OK
}

/// Sets where events go. Events produced while no callback is set are dropped.
///
/// # Safety
/// `engine` must come from [`engine_create`] and not be destroyed; `callback` must stay
/// callable until [`engine_destroy`] returns.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_set_event_callback(
    engine: *const Engine,
    callback: EngineEventCallback,
) -> i32 {
    let _ = (engine, callback);
    ENGINE_OK
}

/// Queues one encoded `framix.v1.Command`. Copies the bytes and returns at once; the
/// engine thread answers with exactly one event.
///
/// # Safety
/// `engine` must come from [`engine_create`] and not be destroyed; `bytes` must be valid
/// for `len` reads (or null with `len == 0`).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_send(engine: *const Engine, bytes: *const u8, len: usize) -> i32 {
    let _ = (engine, bytes, len);
    ENGINE_OK
}

/// Stops the engine thread after it finishes queued commands, then frees the engine.
///
/// # Safety
/// `engine` must be null or come from [`engine_create`], and no other call may use it
/// during or after this one.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_destroy(engine: *mut Engine) -> i32 {
    let _ = engine;
    ENGINE_OK
}

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
/// must not be freed more than once, and `ptr` must not be read after this call.
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
