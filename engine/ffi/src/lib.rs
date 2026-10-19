//! C ABI boundary of the Framix engine: decode command -> `framix_app` -> encode event.

use std::sync::mpsc::{Receiver, Sender, channel};
use std::thread::JoinHandle;

use framix_app::engine::command_failed;
use framix_app::preview::PlatformTexture;
use framix_app::proto::{Command, Event};
use prost::Message as _;

mod platform;
#[cfg(any(target_os = "android", target_vendor = "apple"))]
mod spike_preview;
pub use platform::{
    ENGINE_PLATFORM_VERSION, EnginePlatform, EnginePreviewTextureDone, engine_platform_register,
};
#[cfg(target_vendor = "apple")]
pub use spike_preview::engine_spike_draw_nv12;
#[cfg(target_os = "android")]
pub use spike_preview::{
    Java_com_travela_framix_SpikePreview_nativeRender,
    Java_com_travela_framix_SpikePreview_nativeRenderFrame,
};

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
/// The GPU could not be opened, or this platform has no preview path yet.
pub const ENGINE_ERR_GPU: i32 = -5;
/// Something that may happen only once already happened (`engine_platform_register`).
pub const ENGINE_ERR_ALREADY: i32 = -6;

/// Version of the command/event contract (proto/framix/v1/engine.proto).
pub const ENGINE_PROTOCOL_VERSION: u32 = 10;

/// Receives one encoded `framix.v1.Event`. The callee owns the bytes and must release them
/// with [`engine_free_buffer`]. Called on the engine thread, so it must not call
/// [`engine_destroy`] (that would join the engine thread from itself). Dart's
/// `NativeCallable.listener` posts to the isolate, so it is safe there.
pub type EngineEventCallback = Option<unsafe extern "C" fn(ptr: *mut u8, len: usize)>;

/// Opaque engine instance: a channel into the engine thread.
pub struct Engine {
    messages: Sender<EngineMessage>,
    thread: JoinHandle<()>,
}

enum EngineMessage {
    Command(Vec<u8>),
    SetCallback(EngineEventCallback),
    /// The platform's answer to a preview texture request.
    PreviewTexture(Result<PlatformTexture, String>),
    /// Stop after the messages queued before this one. Needed because pending platform
    /// answers hold senders, so the queue never closes by itself.
    Shutdown,
}

/// Creates an engine if `protocol_version` matches [`ENGINE_PROTOCOL_VERSION`] and writes it
/// to `*out`.
///
/// # Safety
/// `out` must be null or valid for one pointer write.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_create(protocol_version: u32, out: *mut *mut Engine) -> i32 {
    ffi_guard(|| {
        if out.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: `out` is non-null and, per the contract, valid for a pointer write.
        unsafe { *out = std::ptr::null_mut() };
        if protocol_version != ENGINE_PROTOCOL_VERSION {
            return ENGINE_ERR_PROTOCOL;
        }
        let (messages, inbox) = channel();
        let host = platform::PlatformHost {
            engine: messages.clone(),
        };
        let Ok(thread) = std::thread::Builder::new()
            .name("framix-engine".into())
            .spawn(move || run_engine(inbox, host))
        else {
            return ENGINE_ERR_STOPPED;
        };
        // SAFETY: as above.
        unsafe { *out = Box::into_raw(Box::new(Engine { messages, thread })) };
        ENGINE_OK
    })
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
    ffi_guard(|| {
        // SAFETY: per the contract, a non-null `engine` is live.
        post(
            unsafe { engine.as_ref() },
            EngineMessage::SetCallback(callback),
        )
    })
}

/// Queues one encoded `framix.v1.Command`. Copies the bytes and returns at once; the
/// engine thread answers with exactly one event.
///
/// # Safety
/// `engine` must come from [`engine_create`] and not be destroyed; `bytes` must be valid
/// for `len` reads (or null with `len == 0`).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_send(engine: *const Engine, bytes: *const u8, len: usize) -> i32 {
    ffi_guard(|| {
        let command = if len == 0 {
            Vec::new()
        } else if bytes.is_null() {
            return ENGINE_ERR_NULL;
        } else {
            // SAFETY: per the contract, `bytes` is valid for `len` reads.
            unsafe { std::slice::from_raw_parts(bytes, len) }.to_vec()
        };
        // SAFETY: per the contract, a non-null `engine` is live.
        post(unsafe { engine.as_ref() }, EngineMessage::Command(command))
    })
}

/// Stops the engine thread after it finishes queued commands, then frees the engine.
///
/// Exception to "every exported fn returns immediately": this blocks until queued
/// commands are answered, which is what lets callbacks stop safely. P1-044 removes it.
///
/// # Safety
/// `engine` must be null or come from [`engine_create`], and no other call may use it
/// during or after this one. Never call it from the event callback.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn engine_destroy(engine: *mut Engine) -> i32 {
    ffi_guard(|| {
        if engine.is_null() {
            return ENGINE_OK;
        }
        // SAFETY: per the contract, `engine` came from engine_create (Box::into_raw) and
        // nothing else uses it, so ownership returns here exactly once.
        let Engine { messages, thread } = *unsafe { Box::from_raw(engine) };
        // Ends the engine loop after queued commands. A send error means it already ended.
        let _ = messages.send(EngineMessage::Shutdown);
        match thread.join() {
            Ok(()) => ENGINE_OK,
            Err(_) => ENGINE_ERR_PANIC,
        }
    })
}

fn post(engine: Option<&Engine>, message: EngineMessage) -> i32 {
    let Some(engine) = engine else {
        return ENGINE_ERR_NULL;
    };
    match engine.messages.send(message) {
        Ok(()) => ENGINE_OK,
        Err(_) => ENGINE_ERR_STOPPED,
    }
}

/// The engine thread: answers every command with one event, in order, plus the results of
/// platform work as they arrive.
fn run_engine(inbox: Receiver<EngineMessage>, host: platform::PlatformHost) {
    let mut engine = framix_app::engine::Engine::with_store(Box::new(framix_storage::FileStore))
        .with_preview(
            Box::new(host),
            Box::new(
                // SAFETY: app::Engine draws only textures from preview_texture_done, which passes
                // on only non-null handles the platform reported as made (EnginePreviewTextureDone).
                unsafe { framix_render::GpuRenderer::new() },
            ),
        );
    let mut callback: EngineEventCallback = None;
    for message in inbox {
        let event = match message {
            EngineMessage::SetCallback(new) => {
                callback = new;
                continue;
            }
            EngineMessage::Shutdown => break,
            EngineMessage::Command(bytes) => match Command::decode(bytes.as_slice()) {
                Ok(command) => guarded(|| engine.handle(command)),
                Err(_) => command_failed("undecodable command"),
            },
            EngineMessage::PreviewTexture(texture) => {
                guarded(|| engine.preview_texture_ready(texture))
            }
        };
        if let Some(deliver) = callback {
            let buf = EngineBuffer::from_vec(event.encode_to_vec());
            // SAFETY: engine_set_event_callback's contract keeps `deliver` callable
            // until engine_destroy, which joins this thread first.
            unsafe { deliver(buf.ptr, buf.len) };
        }
    }
}

/// A panic while handling one message becomes an event instead of killing the engine thread.
/// History::apply edits a copy, so a panicking edit leaves the timeline as it was.
fn guarded(f: impl FnOnce() -> Event) -> Event {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(f))
        .unwrap_or_else(|_| command_failed("internal error"))
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
