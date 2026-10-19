// SPIKE (P1-001): wgpu output shown in a Flutter Texture without copies. Off main until reviewed;
// the real platform layer (native/android, C ABI callbacks) comes with P1-005.
package com.travela.framix

import android.hardware.HardwareBuffer
import android.util.Log
import android.view.Surface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

/**
 * Method channel `framix/spike_preview`: `create` makes a SurfaceProducer, has Rust (wgpu) draw
 * one frame straight into its Surface, and returns the Flutter texture id. Flutter samples the
 * Surface's HardwareBuffers, so the frame is never copied.
 */
class SpikePreview(
    private val textures: TextureRegistry,
    /** SPIKE (P1-056): app files dir; `spike_clip.mp4` there (adb push) replaces the pattern. */
    private val files: File?,
) : MethodChannel.MethodCallHandler {
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
        files?.resolve("spike_clip.mp4")?.takeIf { it.isFile }?.let { clip ->
            // SPIKE (P1-056): decode off the main thread, then draw over the test pattern.
            Thread {
                runCatching {
                    SpikeDecode.withFirstFrame(clip) { frame ->
                        nativeRenderFrame(producer.surface, frame)
                    }
                }.onSuccess { Log.i("framix", "spike decode: nativeRenderFrame -> $it") }
                    .onFailure { Log.w("framix", "spike decode failed", it) }
            }.start()
        }
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

        /** engine/ffi/src/spike_preview.rs: draws an RGBA8 frame, returns an engine code. */
        @JvmStatic
        external fun nativeRenderFrame(surface: Surface, frame: HardwareBuffer): Int
    }
}
