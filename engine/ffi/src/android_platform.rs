//! Android's [`EnginePlatform`]: Kotlin has no C function pointers, so this JNI shim fills the
//! vtable with trampolines that call `com.travela.framix.EnginePlatform` (ADR 0003, P1-052).

use std::ffi::c_void;
use std::ptr::{NonNull, null_mut};
use std::sync::OnceLock;

use jni_sys::{JNIEnv, JavaVM, jint, jlong, jmethodID, jobject, jvalue};

use crate::platform::{
    ENGINE_PLATFORM_VERSION, EnginePlatform, EnginePreviewTextureDone, engine_platform_register,
    preview_texture_done,
};
use crate::{ENGINE_ERR_GPU, ENGINE_ERR_NULL, ENGINE_OK, ffi_guard};

/// What the trampolines need to reach Kotlin from any engine thread.
struct Java {
    vm: *mut JavaVM,
    /// Global reference to the Kotlin `EnginePlatform` object.
    platform: jobject,
    create_preview_texture: jmethodID,
    frame_available: jmethodID,
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
    pub(crate) fn ANativeWindow_getWidth(window: *mut c_void) -> i32;
    pub(crate) fn ANativeWindow_getHeight(window: *mut c_void) -> i32;
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
        let frame_available = method(c"frameAvailable", c"(J)V")?;
        let platform = (jni.NewGlobalRef)(env, this);
        (!platform.is_null()).then_some(Java {
            vm,
            platform,
            create_preview_texture,
            frame_available,
        })
    }
}

/// Calls a void Kotlin method on the platform object from the current (engine) thread, which
/// stays attached to the VM as a daemon. Returns false if the call could not run or threw.
fn call(method: impl FnOnce(&Java) -> jmethodID, args: &[jvalue]) -> bool {
    let Some(java) = JAVA.get() else {
        return false;
    };
    // SAFETY: `java` holds a live VM, a global reference and method ids of its class (JNI
    // keeps them valid for the process); `args` match the method signatures used by callers.
    unsafe {
        let mut env: *mut c_void = null_mut();
        if ((**java.vm).v1_4.AttachCurrentThreadAsDaemon)(java.vm, &mut env, null_mut())
            != jni_sys::JNI_OK
        {
            return false;
        }
        let env = env.cast::<JNIEnv>();
        let jni = &(**env).v1_6;
        (jni.CallVoidMethodA)(env, java.platform, method(java), args.as_ptr());
        let threw = (jni.ExceptionCheck)(env);
        if threw {
            (jni.ExceptionClear)(env);
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
    if !call(|java| java.create_preview_texture, &args) {
        // Kotlin never got the request (or threw before taking it), so answer it here.
        // SAFETY: as above; Kotlin only answers after a call that returned normally.
        unsafe { done(done_ctx, ENGINE_ERR_GPU, 0, null_mut()) };
    }
}

/// `frame_available`: tells Kotlin; on Android the SurfaceProducer picks up frames by itself.
unsafe extern "C" fn frame_available(_ctx: *mut c_void, texture_id: i64) {
    ffi_guard(|| {
        call(|java| java.frame_available, &[jvalue { j: texture_id }]);
        ENGINE_OK
    });
}

/// JNI entry for `EnginePlatform.nativePreviewTextureDone(doneCtx, status, textureId, surface)`:
/// answers one `createPreviewTexture` call. On success the Surface's `ANativeWindow` becomes
/// the texture handle the renderer draws into; the engine owns that window reference.
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
    status: jint,
    texture_id: jlong,
    surface: jobject,
) {
    ffi_guard(|| {
        let done_ctx = done_ctx as *mut c_void;
        // SAFETY: env and surface are live per this fn's contract; the window reference it
        // returns is handed to the engine with the texture.
        let window = (status == ENGINE_OK && !surface.is_null())
            .then(|| NonNull::new(unsafe { ANativeWindow_fromSurface(env, surface) }))
            .flatten();
        let (status, handle) = match window {
            Some(window) => (ENGINE_OK, window.as_ptr()),
            None if status == ENGINE_OK => (ENGINE_ERR_NULL, null_mut()),
            None => (status, null_mut()),
        };
        // SAFETY: `done_ctx` came from create_preview_texture and is answered once (contract).
        unsafe { preview_texture_done(done_ctx, status, texture_id, handle) };
        ENGINE_OK
    });
}
