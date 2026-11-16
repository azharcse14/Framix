//! Android's [`EnginePlatform`]: Kotlin has no C function pointers, so this JNI shim fills the
//! vtable with trampolines that call `com.travela.framix.EnginePlatform` (ADR 0003, P1-052).

use std::ffi::c_void;
use std::ptr::{NonNull, null_mut};
use std::sync::OnceLock;

use jni_sys::{JNIEnv, JavaVM, jint, jlong, jmethodID, jobject, jvalue};

use crate::platform::{
    ENGINE_PLATFORM_VERSION, EnginePlatform, EnginePreviewTextureDone, EngineThumbnailDone,
    engine_platform_register, preview_texture_done, thumbnail_done,
};
use crate::{ENGINE_ERR_GPU, ENGINE_ERR_NULL, ENGINE_OK, ffi_guard};

/// What the trampolines need to reach Kotlin from any engine thread.
struct Java {
    vm: *mut JavaVM,
    /// Global reference to the Kotlin `EnginePlatform` object.
    platform: jobject,
    create_preview_texture: jmethodID,
    request_thumbnail: jmethodID,
    release_preview_texture: jmethodID,
    encoder_open: jmethodID,
    encoder_surface: jmethodID,
    encoder_frame: jmethodID,
    encoder_finish: jmethodID,
    decoder_open: jmethodID,
    decoder_frame: jmethodID,
    decoder_close: jmethodID,
}

// SAFETY: a JavaVM pointer, a global reference and method ids are valid on every thread (JNI
// spec); they are written once and never mutated.
unsafe impl Send for Java {}
// SAFETY: as above.
unsafe impl Sync for Java {}

static JAVA: OnceLock<Java> = OnceLock::new();

// NDK window functions (android/native_window_jni.h, android/native_window.h).
#[link(name = "android")]
unsafe extern "C" {
    pub(crate) fn ANativeWindow_fromSurface(env: *mut JNIEnv, surface: jobject) -> *mut c_void;
    pub(crate) fn ANativeWindow_release(window: *mut c_void);
    fn AHardwareBuffer_fromHardwareBuffer(env: *mut JNIEnv, buffer: jobject) -> *mut c_void;
}

/// JNI entry for `EnginePlatform.nativeRegister()`: registers the vtable for the process.
/// Returns an engine code ([`crate::ENGINE_ERR_ALREADY`] after a successful call).
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*` and `this` a live local reference
/// to a `com.travela.framix.EnginePlatform`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn Java_com_travela_framix_EnginePlatform_nativeRegister(
    env: *mut JNIEnv,
    this: jobject,
) -> jint {
    ffi_guard(|| {
        if env.is_null() || this.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: `env` and `this` are live per this fn's contract.
        let Some(java) = (unsafe { lookup(env, this) }) else {
            return ENGINE_ERR_NULL;
        };
        if JAVA.set(java).is_err() {
            return crate::ENGINE_ERR_ALREADY;
        }
        let platform = EnginePlatform {
            version: ENGINE_PLATFORM_VERSION,
            ctx: null_mut(),
            create_preview_texture: Some(create_preview_texture),
            frame_available: Some(frame_available),
            request_thumbnail: Some(request_thumbnail),
            encoder_open: Some(encoder_open),
            encoder_frame: Some(encoder_frame),
            encoder_finish: Some(encoder_finish),
            decoder_open: Some(decoder_open),
            decoder_frame: Some(decoder_frame),
            decoder_close: Some(decoder_close),
            request_proxy: Some(no_proxy),
            // Android export is its own task; until then the pre-flight does not block.
            free_bytes: Some(unknown_free_bytes),
            release_preview_texture: Some(release_preview_texture),
        };
        // SAFETY: `platform` is a valid EnginePlatform; the callbacks are 'static fns.
        unsafe { engine_platform_register(&platform) }
    })
}

/// Resolves the VM, a global reference to `this` and the Kotlin methods.
///
/// # Safety
/// As [`Java_com_travela_framix_EnginePlatform_nativeRegister`].
unsafe fn lookup(env: *mut JNIEnv, this: jobject) -> Option<Java> {
    // SAFETY: `env` is a live JNIEnv; every call below follows its documented signature, and
    // the method names and signatures are string literals matching EnginePlatform.kt.
    unsafe {
        let jni = &(**env).v1_6;
        let mut vm = null_mut();
        if (jni.GetJavaVM)(env, &mut vm) != jni_sys::JNI_OK || vm.is_null() {
            return None;
        }
        let class = (jni.GetObjectClass)(env, this);
        let method = |name: &std::ffi::CStr, sig: &std::ffi::CStr| {
            let id = (jni.GetMethodID)(env, class, name.as_ptr(), sig.as_ptr());
            if (jni.ExceptionCheck)(env) {
                (jni.ExceptionClear)(env);
            }
            (!id.is_null()).then_some(id)
        };
        let create_preview_texture = method(c"createPreviewTexture", c"(IIJ)V")?;
        let request_thumbnail = method(c"requestThumbnail", c"(Ljava/lang/String;ZJIJ)V")?;
        let release_preview_texture = method(c"releasePreviewTexture", c"(J)V")?;
        let encoder_open = method(
            c"encoderOpen",
            c"(IIIILjava/lang/String;)Lcom/travela/framix/ExportEncoder;",
        )?;
        let encoder_surface = method(
            c"encoderSurface",
            c"(Lcom/travela/framix/ExportEncoder;)Landroid/view/Surface;",
        )?;
        let encoder_frame = method(c"encoderFrame", c"(Lcom/travela/framix/ExportEncoder;J)Z")?;
        let encoder_finish = method(c"encoderFinish", c"(Lcom/travela/framix/ExportEncoder;Z)Z")?;
        let decoder_open = method(c"decoderOpen", c"()Lcom/travela/framix/FrameDecoder;")?;
        let decoder_frame = method(
            c"decoderFrame",
            c"(Lcom/travela/framix/FrameDecoder;Ljava/lang/String;ZJ)Landroid/hardware/HardwareBuffer;",
        )?;
        let decoder_close = method(c"decoderClose", c"(Lcom/travela/framix/FrameDecoder;)V")?;
        let platform = (jni.NewGlobalRef)(env, this);
        (!platform.is_null()).then_some(Java {
            vm,
            platform,
            create_preview_texture,
            request_thumbnail,
            release_preview_texture,
            encoder_open,
            encoder_surface,
            encoder_frame,
            encoder_finish,
            decoder_open,
            decoder_frame,
            decoder_close,
        })
    }
}

/// Runs `call` with a JNIEnv for the current thread and the Kotlin object. A thread not yet
/// attached to the VM is attached once and stays attached until it exits (P1-130,
/// [`crate::jni_thread::thread_env`]); `call` runs in its own local frame, so its local
/// references never pile up on a thread that never returns to Java.
/// Returns false if no env was available or the call threw.
///
/// # Safety
/// `call` must use the env only for JNI calls valid on this thread, and only during the call.
unsafe fn with_kotlin(call: impl FnOnce(*mut JNIEnv, &Java)) -> bool {
    let Some(java) = JAVA.get() else {
        return false;
    };
    // SAFETY: `java` holds a live VM, a global reference and method ids of its class (JNI keeps
    // them valid for the process); `call` follows this fn's contract.
    unsafe {
        let Some(env) = crate::jni_thread::thread_env(java.vm) else {
            return false;
        };
        let jni = &(**env).v1_6;
        if (jni.PushLocalFrame)(env, LOCAL_FRAME) != jni_sys::JNI_OK {
            (jni.ExceptionClear)(env);
            return false;
        }
        call(env, java);
        let threw = (jni.ExceptionCheck)(env);
        if threw {
            (jni.ExceptionClear)(env);
        }
        (jni.PopLocalFrame)(env, null_mut());
        !threw
    }
}

/// Local references a `with_kotlin` call may hold at once (each call makes at most three).
const LOCAL_FRAME: jint = 8;

/// `create_preview_texture`: asks Kotlin for a SurfaceProducer; it answers through
/// [`Java_com_travela_framix_EnginePlatform_nativePreviewTextureDone`].
unsafe extern "C" fn create_preview_texture(
    _ctx: *mut c_void,
    width: u32,
    height: u32,
    done: EnginePreviewTextureDone,
    done_ctx: *mut c_void,
) {
    ffi_guard(|| {
        request_texture(width, height, done, done_ctx);
        ENGINE_OK
    });
}

/// The body of [`create_preview_texture`]; answers `done` itself when Kotlin cannot.
fn request_texture(width: u32, height: u32, done: EnginePreviewTextureDone, done_ctx: *mut c_void) {
    let (Ok(w), Ok(h)) = (jint::try_from(width), jint::try_from(height)) else {
        // SAFETY: answering the request exactly once, with the context it came with.
        return unsafe { done(done_ctx, ENGINE_ERR_GPU, 0, null_mut()) };
    };
    let args = [
        jvalue { i: w },
        jvalue { i: h },
        jvalue {
            j: done_ctx as jlong,
        },
    ];
    // SAFETY: the three values match `(IIJ)V`: width, height, done_ctx.
    let called = unsafe {
        with_kotlin(|env, java| {
            ((**env).v1_6.CallVoidMethodA)(
                env,
                java.platform,
                java.create_preview_texture,
                args.as_ptr(),
            )
        })
    };
    if !called {
        // Kotlin never got the request, or threw before posting it: EnginePlatform.kt's
        // createPreviewTexture only posts and cannot throw after that, so it will not answer.
        // SAFETY: as above, answered exactly once.
        unsafe { done(done_ctx, ENGINE_ERR_GPU, 0, null_mut()) };
    }
}

/// `request_thumbnail`: asks Kotlin for a thumbnail file; it answers through
/// [`Java_com_travela_framix_EnginePlatform_nativeThumbnailDone`].
#[allow(clippy::too_many_arguments)] // The vtable's C signature.
unsafe extern "C" fn request_thumbnail(
    _ctx: *mut c_void,
    uri: *const u8,
    uri_len: usize,
    kind: u32,
    time_us: i64,
    max_side: u32,
    done: EngineThumbnailDone,
    done_ctx: *mut c_void,
) {
    ffi_guard(|| {
        // SAFETY: the engine passes `uri_len` bytes valid for this call (vtable contract).
        let uri = unsafe { std::slice::from_raw_parts(uri, uri_len) };
        if !ask_thumbnail(uri, kind, time_us, max_side, done_ctx) {
            // Kotlin never got the request, or threw before taking it: requestThumbnail only
            // submits to its executor, so it will not answer.
            // SAFETY: answering the request exactly once, with the context it came with.
            unsafe { done(done_ctx, ENGINE_ERR_GPU, null_mut(), 0) };
        }
        ENGINE_OK
    });
}

/// Calls `requestThumbnail(uri, image, timeUs, maxSide, doneCtx)`; false if it did not run.
fn ask_thumbnail(
    uri: &[u8],
    kind: u32,
    time_us: i64,
    max_side: u32,
    done_ctx: *mut c_void,
) -> bool {
    let (Ok(uri), Ok(max_side)) = (std::ffi::CString::new(uri), jint::try_from(max_side)) else {
        return false;
    };
    let image = kind == crate::platform::ENGINE_MEDIA_IMAGE;
    let mut made = false;
    // SAFETY: the env calls follow their JNI signatures; the String is a local reference
    // deleted before returning; the arguments match `(Ljava/lang/String;ZJIJ)V`.
    let called = unsafe {
        with_kotlin(|env, java| {
            let jni = &(**env).v1_6;
            let string = (jni.NewStringUTF)(env, uri.as_ptr());
            if string.is_null() {
                return;
            }
            let args = [
                jvalue { l: string },
                jvalue { z: image },
                jvalue { j: time_us },
                jvalue { i: max_side },
                jvalue {
                    j: done_ctx as jlong,
                },
            ];
            (jni.CallVoidMethodA)(env, java.platform, java.request_thumbnail, args.as_ptr());
            (jni.DeleteLocalRef)(env, string);
            made = true;
        })
    };
    called && made
}

/// JNI entry for `EnginePlatform.nativeThumbnailDone(doneCtx, path)`: answers one
/// `requestThumbnail` call; a null `path` means it failed.
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*`; `done_ctx` comes from exactly one
/// `requestThumbnail` call and is passed once; `path` is a live `String` local reference or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn Java_com_travela_framix_EnginePlatform_nativeThumbnailDone(
    env: *mut JNIEnv,
    _this: jobject,
    done_ctx: jlong,
    path: jobject,
) {
    ffi_guard(|| {
        let done_ctx = done_ctx as *mut c_void;
        if path.is_null() {
            // SAFETY: `done_ctx` came from request_thumbnail and is answered once (contract).
            unsafe { thumbnail_done(done_ctx, ENGINE_ERR_GPU, null_mut(), 0) };
            return ENGINE_OK;
        }
        // SAFETY: `env` and the String are live per this fn's contract; the UTF chars are
        // released right after the engine copied them.
        unsafe {
            let jni = &(**env).v1_6;
            let chars = (jni.GetStringUTFChars)(env, path, null_mut());
            if chars.is_null() {
                thumbnail_done(done_ctx, ENGINE_ERR_GPU, null_mut(), 0);
                return ENGINE_OK;
            }
            let bytes = std::ffi::CStr::from_ptr(chars).to_bytes();
            thumbnail_done(done_ctx, ENGINE_OK, bytes.as_ptr(), bytes.len());
            (jni.ReleaseStringUTFChars)(env, path, chars);
        }
        ENGINE_OK
    });
}

/// `frame_available`: nothing to do on Android; the SurfaceProducer picks up presented frames
/// by itself, so no JNI round trip per frame.
unsafe extern "C" fn frame_available(_ctx: *mut c_void, _texture_id: i64) {}

/// JNI entry for `EnginePlatform.nativePreviewTextureDone(doneCtx, textureId, surface)`: answers
/// one `createPreviewTexture` call; a null `surface` means it failed. On success the Surface's
/// `ANativeWindow` becomes the texture handle the renderer draws into; the engine owns that
/// window reference.
///
/// # Safety
/// Called by the JVM: `env` is the calling thread's `JNIEnv*`; `done_ctx` comes from exactly one
/// `createPreviewTexture` call and is passed once; `surface` is a live `android.view.Surface`
/// local reference or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn Java_com_travela_framix_EnginePlatform_nativePreviewTextureDone(
    env: *mut JNIEnv,
    _this: jobject,
    done_ctx: jlong,
    texture_id: jlong,
    surface: jobject,
) {
    ffi_guard(|| {
        let done_ctx = done_ctx as *mut c_void;
        // SAFETY: env and surface are live per this fn's contract; the window reference it
        // returns is handed to the engine with the texture.
        let window = (!surface.is_null())
            .then(|| NonNull::new(unsafe { ANativeWindow_fromSurface(env, surface) }))
            .flatten();
        let (status, handle) = match window {
            Some(window) => (ENGINE_OK, window.as_ptr()),
            None => (ENGINE_ERR_GPU, null_mut()),
        };
        // SAFETY: `done_ctx` came from create_preview_texture and is answered once (contract).
        unsafe { preview_texture_done(done_ctx, status, texture_id, handle) };
        ENGINE_OK
    });
}

/// `release_preview_texture`: drops the engine's window reference, then asks Kotlin to release
/// the SurfaceProducer (P1-055).
unsafe extern "C" fn release_preview_texture(
    _ctx: *mut c_void,
    texture_id: i64,
    texture: *mut c_void,
) {
    ffi_guard(|| {
        if !texture.is_null() {
            // SAFETY: `texture` is the ANativeWindow reference nativePreviewTextureDone gave the
            // engine, given back once; the renderer already dropped its own reference.
            unsafe { ANativeWindow_release(texture) };
        }
        let args = [jvalue { j: texture_id }];
        // SAFETY: the value matches `(J)V`: the texture id.
        unsafe {
            with_kotlin(|env, java| {
                ((**env).v1_6.CallVoidMethodA)(
                    env,
                    java.platform,
                    java.release_preview_texture,
                    args.as_ptr(),
                )
            })
        };
        ENGINE_OK
    });
}

/// An open Kotlin `ExportEncoder` and the engine's reference to its input Surface's window, the
/// render target of every frame (docs/adr/0005-export-encoder.md, P1-069).
struct AndroidEncoder {
    /// Global reference to the `ExportEncoder`.
    encoder: jobject,
    /// `ANativeWindow_fromSurface` reference, released by `encoder_finish`.
    window: NonNull<c_void>,
}

/// `encoder_open`: opens a Kotlin `ExportEncoder`. Export worker only; may block.
unsafe extern "C" fn encoder_open(
    _ctx: *mut c_void,
    width: u32,
    height: u32,
    fps: u32,
    kbps: u32,
    path: *const u8,
    path_len: usize,
) -> *mut c_void {
    let mut opened = null_mut();
    ffi_guard(|| {
        // SAFETY: the engine passes `path_len` bytes valid for this call (vtable contract).
        let path = unsafe { std::slice::from_raw_parts(path, path_len) };
        if let Some(encoder) = open_encoder([width, height, fps, kbps], path) {
            opened = Box::into_raw(Box::new(encoder)).cast();
        }
        ENGINE_OK
    });
    opened
}

/// Calls `encoderOpen(width, height, fps, kbps, path)` and takes its Surface's window. An
/// encoder that opened but has no window is cancelled at once.
fn open_encoder(ints: [u32; 4], path: &[u8]) -> Option<AndroidEncoder> {
    let [Ok(width), Ok(height), Ok(fps), Ok(kbps)] = ints.map(jint::try_from) else {
        return None;
    };
    let path = std::ffi::CString::new(path).ok()?;
    let mut opened = None;
    // SAFETY: the env calls follow their JNI signatures and run only while no exception is
    // pending (checked after each Java call); the arguments match the method signatures looked
    // up in `lookup`; local references are deleted before returning.
    unsafe {
        with_kotlin(|env, java| {
            let jni = &(**env).v1_6;
            let string = (jni.NewStringUTF)(env, path.as_ptr());
            if string.is_null() {
                return;
            }
            let args = [
                jvalue { i: width },
                jvalue { i: height },
                jvalue { i: fps },
                jvalue { i: kbps },
                jvalue { l: string },
            ];
            let encoder =
                (jni.CallObjectMethodA)(env, java.platform, java.encoder_open, args.as_ptr());
            (jni.DeleteLocalRef)(env, string);
            if (jni.ExceptionCheck)(env) || encoder.is_null() {
                return;
            }
            let args = [jvalue { l: encoder }];
            let surface =
                (jni.CallObjectMethodA)(env, java.platform, java.encoder_surface, args.as_ptr());
            let window = if (jni.ExceptionCheck)(env) {
                (jni.ExceptionClear)(env);
                None
            } else {
                (!surface.is_null())
                    .then(|| NonNull::new(ANativeWindow_fromSurface(env, surface)))
                    .flatten()
            };
            if !surface.is_null() {
                (jni.DeleteLocalRef)(env, surface);
            }
            let global = window.map(|_| (jni.NewGlobalRef)(env, encoder));
            match (window, global) {
                (Some(window), Some(global)) if !global.is_null() => {
                    opened = Some(AndroidEncoder {
                        encoder: global,
                        window,
                    });
                }
                _ => {
                    if let Some(window) = window {
                        ANativeWindow_release(window.as_ptr());
                    }
                    let args = [jvalue { l: encoder }, jvalue { z: false }];
                    (jni.CallBooleanMethodA)(
                        env,
                        java.platform,
                        java.encoder_finish,
                        args.as_ptr(),
                    );
                }
            }
            (jni.DeleteLocalRef)(env, encoder);
        })
    };
    opened
}

/// `encoder_frame`: tells Kotlin the frame time, then returns the encoder's window. Rust draws
/// into it and presents, which queues the frame into the codec; so the previous frame is
/// already appended.
unsafe extern "C" fn encoder_frame(
    _ctx: *mut c_void,
    encoder: *mut c_void,
    time_us: i64,
) -> *mut c_void {
    let mut target = null_mut();
    ffi_guard(|| {
        // SAFETY: `encoder` came from encoder_open and is not finished (vtable contract).
        let Some(encoder) = (unsafe { encoder.cast::<AndroidEncoder>().as_ref() }) else {
            return ENGINE_ERR_NULL;
        };
        let mut taken = false;
        let args = [jvalue { l: encoder.encoder }, jvalue { j: time_us }];
        // SAFETY: the arguments match `(Lcom/travela/framix/ExportEncoder;J)Z`; the global
        // reference is live until encoder_finish.
        let called = unsafe {
            with_kotlin(|env, java| {
                taken = ((**env).v1_6.CallBooleanMethodA)(
                    env,
                    java.platform,
                    java.encoder_frame,
                    args.as_ptr(),
                );
            })
        };
        if called && taken {
            target = encoder.window.as_ptr();
        }
        ENGINE_OK
    });
    target
}

/// `encoder_finish`: closes or cancels the file in Kotlin, then drops the engine's references.
unsafe extern "C" fn encoder_finish(_ctx: *mut c_void, encoder: *mut c_void, ok: bool) -> i32 {
    ffi_guard(|| {
        if encoder.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: `encoder` is the Box::into_raw from encoder_open, finished exactly once
        // (vtable contract), so ownership returns here.
        let encoder = unsafe { Box::from_raw(encoder.cast::<AndroidEncoder>()) };
        let mut finished = false;
        let args = [jvalue { l: encoder.encoder }, jvalue { z: ok }];
        // SAFETY: the arguments match `(Lcom/travela/framix/ExportEncoder;Z)Z`; the global
        // reference is deleted after its last use (DeleteGlobalRef is valid with an exception
        // pending).
        let called = unsafe {
            with_kotlin(|env, java| {
                let jni = &(**env).v1_6;
                finished = (jni.CallBooleanMethodA)(
                    env,
                    java.platform,
                    java.encoder_finish,
                    args.as_ptr(),
                );
                (jni.DeleteGlobalRef)(env, encoder.encoder);
            })
        };
        // SAFETY: the reference encoder_open took, released once; Kotlin released its Surface,
        // and the renderer holds its own reference while it keeps a surface on it.
        unsafe { ANativeWindow_release(encoder.window.as_ptr()) };
        if called && finished {
            ENGINE_OK
        } else {
            ENGINE_ERR_GPU
        }
    })
}

/// `decoder_open`: opens a Kotlin `FrameDecoder` (its own thread and EGL context). The handle
/// is a global reference to it, deleted by `decoder_close`. Null if it could not open.
unsafe extern "C" fn decoder_open(_ctx: *mut c_void) -> *mut c_void {
    let mut opened = null_mut();
    ffi_guard(|| {
        // SAFETY: no arguments match `()Lcom/travela/framix/FrameDecoder;`; the local reference
        // is deleted once a global one was taken.
        unsafe {
            with_kotlin(|env, java| {
                let jni = &(**env).v1_6;
                let decoder =
                    (jni.CallObjectMethodA)(env, java.platform, java.decoder_open, [].as_ptr());
                if (jni.ExceptionCheck)(env) || decoder.is_null() {
                    return;
                }
                opened = (jni.NewGlobalRef)(env, decoder).cast();
                (jni.DeleteLocalRef)(env, decoder);
            })
        };
        ENGINE_OK
    });
    opened
}

/// `decoder_frame`: Kotlin draws the frame into an RGBA8 HardwareBuffer it keeps until the next
/// call or `decoder_close`; its `AHardwareBuffer*` is the frame's one plane (P1-070). The
/// proxy side is ignored: Android makes no proxies yet, so it reads the original.
#[allow(clippy::too_many_arguments)] // The vtable's C signature.
unsafe extern "C" fn decoder_frame(
    _ctx: *mut c_void,
    decoder: *mut c_void,
    uri: *const u8,
    uri_len: usize,
    kind: u32,
    time_us: i64,
    _proxy_side: u32,
    out: *mut crate::platform::EngineFrame,
) -> i32 {
    ffi_guard(|| {
        if decoder.is_null() || out.is_null() {
            return ENGINE_ERR_NULL;
        }
        // SAFETY: the engine passes `uri_len` bytes valid for this call (vtable contract).
        let uri = unsafe { std::slice::from_raw_parts(uri, uri_len) };
        let Ok(uri) = std::ffi::CString::new(uri) else {
            return ENGINE_ERR_NULL;
        };
        let image = kind == crate::platform::ENGINE_MEDIA_IMAGE;
        let mut ahb = null_mut();
        // SAFETY: the env calls follow their JNI signatures; the arguments match
        // `(Lcom/travela/framix/FrameDecoder;Ljava/lang/String;ZJ)Landroid/hardware/HardwareBuffer;`;
        // `decoder` is the global reference decoder_open made, live until decoder_close. The
        // buffer's AHardwareBuffer stays valid after its local reference goes: Kotlin keeps the
        // HardwareBuffer until its next call.
        unsafe {
            with_kotlin(|env, java| {
                let jni = &(**env).v1_6;
                let string = (jni.NewStringUTF)(env, uri.as_ptr());
                if string.is_null() {
                    return;
                }
                let args = [
                    jvalue { l: decoder.cast() },
                    jvalue { l: string },
                    jvalue { z: image },
                    jvalue { j: time_us },
                ];
                let buffer =
                    (jni.CallObjectMethodA)(env, java.platform, java.decoder_frame, args.as_ptr());
                (jni.DeleteLocalRef)(env, string);
                if (jni.ExceptionCheck)(env) || buffer.is_null() {
                    return;
                }
                ahb = AHardwareBuffer_fromHardwareBuffer(env, buffer);
                (jni.DeleteLocalRef)(env, buffer);
            })
        };
        if ahb.is_null() {
            return ENGINE_ERR_GPU;
        }
        // SAFETY: `out` is a valid EngineFrame out pointer for the call (vtable contract).
        unsafe {
            *out = crate::platform::EngineFrame {
                format: crate::platform::ENGINE_FRAME_RGBA,
                planes: [ahb, null_mut()],
                matrix: crate::platform::ENGINE_YCBCR_UNKNOWN,
                range: crate::platform::ENGINE_RANGE_UNKNOWN,
            }
        };
        ENGINE_OK
    })
}

/// `decoder_close`: frees the Kotlin decoder (its thread, codec and buffers) and the reference.
unsafe extern "C" fn decoder_close(_ctx: *mut c_void, decoder: *mut c_void) {
    ffi_guard(|| {
        if decoder.is_null() {
            return ENGINE_ERR_NULL;
        }
        let args = [jvalue { l: decoder.cast() }];
        // SAFETY: the arguments match `(Lcom/travela/framix/FrameDecoder;)V`; `decoder` is the
        // global reference from decoder_open, closed once (vtable contract) and deleted after its
        // last use (DeleteGlobalRef is valid with an exception pending).
        unsafe {
            with_kotlin(|env, java| {
                let jni = &(**env).v1_6;
                (jni.CallVoidMethodA)(env, java.platform, java.decoder_close, args.as_ptr());
                (jni.DeleteGlobalRef)(env, decoder.cast());
            })
        };
        ENGINE_OK
    });
}

unsafe extern "C" fn unknown_free_bytes(_: *mut c_void, _: *const u8, _: usize) -> i64 {
    -1
}

/// Android proxies come with its Decoder port (P1-070); until then every request fails at once.
unsafe extern "C" fn no_proxy(
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    done: crate::platform::EngineProxyDone,
    done_ctx: *mut c_void,
) {
    // SAFETY: `done_ctx` came with this request and is answered exactly once, here.
    unsafe { done(done_ctx, crate::ENGINE_ERR_GPU) };
}
