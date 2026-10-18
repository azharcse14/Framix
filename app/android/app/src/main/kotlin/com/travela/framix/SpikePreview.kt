// SPIKE (P1-001): wgpu output shown in a Flutter Texture without copies. Off main until reviewed;
// the real platform layer (native/android, C ABI callbacks) comes with P1-005.
package com.travela.framix

import android.view.Surface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Method channel `framix/spike_preview`: `create` makes a SurfaceProducer, has Rust (wgpu) draw
 * one frame straight into its Surface, and returns the Flutter texture id. Flutter samples the
 * Surface's HardwareBuffers, so the frame is never copied.
 */
class SpikePreview(private val textures: TextureRegistry) : MethodChannel.MethodCallHandler {
    private val producers = mutableListOf<TextureRegistry.SurfaceProducer>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "create") return result.notImplemented()
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        if (width == null || height == null || width <= 0 || height <= 0) {
            return result.error("create", null, null)
        }
        val producer = textures.createSurfaceProducer()
        producer.setSize(width, height)
        val code = nativeRender(producer.surface)
        if (code != 0) {
            producer.release()
            return result.error("create", "render failed ($code)", null)
        }
        producers += producer
        result.success(mapOf("textureId" to producer.id()))
    }

    /** Releases every texture; call when the Flutter engine goes away. */
    fun close() {
        producers.forEach { it.release() }
        producers.clear()
    }

    private companion object {
        init {
            // The engine library Dart already loaded (native assets); same instance.
            System.loadLibrary("framix_ffi")
        }

        /** engine/ffi/src/spike_preview.rs: draws the test pattern, returns an engine code. */
        @JvmStatic
        external fun nativeRender(surface: Surface): Int
    }
}
