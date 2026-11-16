# Methods the engine's JNI shim looks up by name (engine/ffi/src/android_platform.rs).
-keep class com.travela.framix.EnginePlatform {
    public void createPreviewTexture(int, int, long);
    public void requestThumbnail(java.lang.String, boolean, long, int, long);
    public void releasePreviewTexture(long);
    public com.travela.framix.ExportEncoder encoderOpen(int, int, int, int, java.lang.String);
    public android.view.Surface encoderSurface(com.travela.framix.ExportEncoder);
    public boolean encoderFrame(com.travela.framix.ExportEncoder, long);
    public boolean encoderFinish(com.travela.framix.ExportEncoder, boolean);
}
# Named in those methods' JNI signatures.
-keep class com.travela.framix.ExportEncoder
