# Methods the engine's JNI shim looks up by name (engine/ffi/src/android_platform.rs).
-keep class com.travela.framix.EnginePlatform {
    public void createPreviewTexture(int, int, long);
}
