//! Attaches native threads to the JVM once (P1-130): the engine, render and export threads call
//! Kotlin per frame, and an attach plus detach on every call is a hot-path cost.

use std::cell::OnceCell;
use std::ffi::c_void;
use std::ptr::null_mut;

use jni_sys::{JNI_EDETACHED, JNI_OK, JNI_VERSION_1_6, JNIEnv, JavaVM};

/// Detaches its thread from the VM when the thread exits.
struct Attachment(*mut JavaVM);

impl Drop for Attachment {
    fn drop(&mut self) {
        // SAFETY: `self.0` is the live VM this thread attached to in `thread_env`, and a
        // thread-local destructor runs on that thread.
        unsafe { ((**self.0).v1_4.DetachCurrentThread)(self.0) };
    }
}

thread_local! {
    static ATTACHMENT: OnceCell<Attachment> = const { OnceCell::new() };
}

/// Returns this thread's `JNIEnv`, attaching the thread to `vm` on its first call. A thread
/// attached here stays attached until it exits, when a thread-local guard detaches it (ART
/// aborts on an attached thread exiting). None if the thread cannot be attached.
///
/// # Safety
/// `vm` is a live `JavaVM` for the rest of the process.
pub(crate) unsafe fn thread_env(vm: *mut JavaVM) -> Option<*mut JNIEnv> {
    // SAFETY: `vm` is live (caller contract).
    unsafe {
        let invoke = &(**vm).v1_4;
        let mut env: *mut c_void = null_mut();
        match (invoke.GetEnv)(vm, &mut env, JNI_VERSION_1_6) {
            JNI_OK => return Some(env.cast()),
            JNI_EDETACHED => {}
            _ => return None,
        }
        // No guard slot (the thread is exiting): attaching would leave it attached at exit.
        ATTACHMENT
            .try_with(|guard| {
                if (invoke.AttachCurrentThread)(vm, &mut env, null_mut()) != JNI_OK {
                    return None;
                }
                guard.get_or_init(|| Attachment(vm));
                Some(env.cast())
            })
            .ok()
            .flatten()
    }
}

#[cfg(test)]
mod tests {
    use std::cell::Cell;
    use std::sync::atomic::{AtomicUsize, Ordering};

    use jni_sys::jint;

    use super::*;

    static ATTACHES: AtomicUsize = AtomicUsize::new(0);
    static DETACHES: AtomicUsize = AtomicUsize::new(0);

    thread_local! {
        static FAKE_ATTACHED: Cell<bool> = const { Cell::new(false) };
    }

    /// Same layout as `JNIInvokeInterface_` (3 reserved pointer-sized slots, then 5 functions).
    #[repr(C)]
    struct FakeInvoke {
        reserved: [usize; 3],
        destroy: unsafe extern "system" fn(*mut JavaVM) -> jint,
        attach: unsafe extern "system" fn(*mut JavaVM, *mut *mut c_void, *mut c_void) -> jint,
        detach: unsafe extern "system" fn(*mut JavaVM) -> jint,
        get_env: unsafe extern "system" fn(*mut JavaVM, *mut *mut c_void, jint) -> jint,
        attach_daemon:
            unsafe extern "system" fn(*mut JavaVM, *mut *mut c_void, *mut c_void) -> jint,
    }

    const FAKE_ENV: *mut c_void = 0x1000 as *mut c_void;

    unsafe extern "system" fn destroy(_: *mut JavaVM) -> jint {
        JNI_OK
    }

    unsafe extern "system" fn attach(
        _: *mut JavaVM,
        env: *mut *mut c_void,
        _: *mut c_void,
    ) -> jint {
        ATTACHES.fetch_add(1, Ordering::SeqCst);
        FAKE_ATTACHED.set(true);
        // SAFETY: `env` is the out pointer thread_env passes.
        unsafe { *env = FAKE_ENV };
        JNI_OK
    }

    unsafe extern "system" fn detach(_: *mut JavaVM) -> jint {
        DETACHES.fetch_add(1, Ordering::SeqCst);
        // The fake's own thread-local may already be gone at thread exit.
        let _ = FAKE_ATTACHED.try_with(|attached| attached.set(false));
        JNI_OK
    }

    unsafe extern "system" fn get_env(_: *mut JavaVM, env: *mut *mut c_void, _: jint) -> jint {
        if !FAKE_ATTACHED.get() {
            return JNI_EDETACHED;
        }
        // SAFETY: `env` is the out pointer thread_env passes.
        unsafe { *env = FAKE_ENV };
        JNI_OK
    }

    static FAKE: FakeInvoke = FakeInvoke {
        reserved: [0; 3],
        destroy,
        attach,
        detach,
        get_env,
        attach_daemon: attach,
    };

    struct FakeVm(*const FakeInvoke);
    // SAFETY: points to an immutable static.
    unsafe impl Sync for FakeVm {}
    static FAKE_VM: FakeVm = FakeVm(&FAKE);

    #[test]
    fn a_thread_attaches_once_and_detaches_at_exit() {
        let vm = (&raw const FAKE_VM).cast::<JavaVM>().cast_mut();
        let vm = vm as usize;
        std::thread::spawn(move || {
            for _ in 0..100 {
                // SAFETY: FAKE_VM lives for the process and has JavaVM's layout.
                let env = unsafe { thread_env(vm as *mut JavaVM) };
                assert_eq!(env, Some(FAKE_ENV.cast()));
            }
            assert_eq!(DETACHES.load(Ordering::SeqCst), 0, "detached while running");
        })
        .join()
        .unwrap();
        assert_eq!(ATTACHES.load(Ordering::SeqCst), 1, "attaches");
        assert_eq!(
            DETACHES.load(Ordering::SeqCst),
            1,
            "detaches at thread exit"
        );
    }
}
