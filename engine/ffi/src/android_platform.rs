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
            // The MediaCodec encoder is its own task; until then exports fail to open.
            encoder_open: Some(no_encoder_open),
            encoder_frame: Some(no_encoder_frame),
            encoder_finish: Some(no_encoder_finish),
            decoder_open: Some(no_decoder_open),
            decoder_frame: Some(no_decoder_frame),
            decoder_close: Some(no_decoder_close),
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
        let platform = (jni.NewGlobalRef)(env, this);
        (!platform.is_null()).then_some(Java {
            vm,
            platform,
            create_preview_texture,
            request_thumbnail,
        })
    }
}

/// Runs `call` with a JNIEnv for the current thread and the Kotlin object. A thread that was
/// not attached to the VM is attached for the call and detached after it: the engine thread may
/// exit at any time (it is detached), and ART aborts on an attached thread exiting.
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
        let invoke = &(**java.vm).v1_4;
        let mut env: *mut c_void = null_mut();
        let attached_here = match (invoke.GetEnv)(java.vm, &mut env, jni_sys::JNI_VERSION_1_6) {
            jni_sys::JNI_OK => false,
            jni_sys::JNI_EDETACHED => {
                if (invoke.AttachCurrentThread)(java.vm, &mut env, null_mut()) != jni_sys::JNI_OK {
                    return false;
                }
                true
            }
            _ => return false,
        };
        let env = env.cast::<JNIEnv>();
        call(env, java);
        let jni = &(**env).v1_6;
        let threw = (jni.ExceptionCheck)(env);
        if threw {
            (jni.ExceptionClear)(env);
        }
        if attached_here {
            (invoke.DetachCurrentThread)(java.vm);
        }
        !threw
    }
}

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

/// No encoder on Android yet: every export fails to open.
unsafe extern "C" fn no_encoder_open(
    _: *mut c_void,
    _: u32,
    _: u32,
    _: u32,
    _: u32,
    _: *const u8,
    _: usize,
) -> *mut c_void {
    null_mut()
}

/// Never called: no encoder opens.
unsafe extern "C" fn no_encoder_frame(_: *mut c_void, _: *mut c_void, _: i64) -> *mut c_void {
    null_mut()
}

/// Never called: no encoder opens.
unsafe extern "C" fn no_encoder_finish(_: *mut c_void, _: *mut c_void, _: bool) -> i32 {
    crate::ENGINE_ERR_GPU
}

/// The Android Decoder port is its own task; until then every decoder fails to open.
unsafe extern "C" fn no_decoder_open(_: *mut c_void) -> *mut c_void {
    null_mut()
}

unsafe extern "C" fn no_decoder_frame(
    _: *mut c_void,
    _: *mut c_void,
    _: *const u8,
    _: usize,
    _: u32,
    _: i64,
    _: *mut crate::platform::EngineFrame,
) -> i32 {
    crate::ENGINE_ERR_GPU
}

unsafe extern "C" fn no_decoder_close(_: *mut c_void, _: *mut c_void) {}
