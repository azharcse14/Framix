use framix_ffi::{ENGINE_ERR_PANIC, ENGINE_OK, EngineBuffer, engine_free_buffer, ffi_guard};

#[test]
fn guard_passes_through_return_code() {
    assert_eq!(ffi_guard(|| 7), 7);
}

#[test]
fn guard_turns_panic_into_error_code() {
    assert_eq!(ffi_guard(|| panic!("boom")), ENGINE_ERR_PANIC);
}

#[test]
fn buffer_holds_bytes_and_frees() {
    let buf = EngineBuffer::from_vec(vec![1, 2, 3]);
    assert!(!buf.ptr.is_null());
    assert_eq!(buf.len, 3);
    // SAFETY: from_vec returned a live allocation of exactly `len` bytes.
    let bytes = unsafe { std::slice::from_raw_parts(buf.ptr, buf.len) };
    assert_eq!(bytes, &[1, 2, 3]);
    // SAFETY: `buf` came from from_vec and is freed once.
    assert_eq!(unsafe { engine_free_buffer(buf) }, ENGINE_OK);
}

#[test]
fn empty_and_null_buffers_free_cleanly() {
    let empty = EngineBuffer::from_vec(Vec::new());
    // SAFETY: `empty` came from from_vec and is freed once.
    assert_eq!(unsafe { engine_free_buffer(empty) }, ENGINE_OK);
    let null = EngineBuffer {
        ptr: std::ptr::null_mut(),
        len: 0,
    };
    // SAFETY: a null buffer is documented as a no-op.
    assert_eq!(unsafe { engine_free_buffer(null) }, ENGINE_OK);
}
