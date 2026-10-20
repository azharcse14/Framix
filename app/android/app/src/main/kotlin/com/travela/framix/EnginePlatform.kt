// The callbacks only Android can serve, registered into the engine at startup
// (docs/adr/0003-platform-callbacks.md). Thin adapter: the engine decides what to draw and when.
package com.travela.framix

import android.hardware.HardwareBuffer
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.File

/**
 * Fills the engine's `EnginePlatform` vtable through the Rust JNI shim
 * (engine/ffi/src/android_platform.rs). Rust calls [createPreviewTexture] and [frameAvailable]
 * on the engine thread; both return at once and hop to the main thread.
 */
class EnginePlatform(
    private val textures: TextureRegistry,
    /** SPIKE (P1-056): app files dir; `spike_clip.mp4` there (adb push) is drawn over the preview. */
    private val files: File?,
) {
    private val main = Handler(Looper.getMainLooper())
    // ponytail: producers are never released; the preview makes one per launch (P1-055).
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()

    /** Registers with the engine library Dart loads (same process, same instance). */
    fun register() {
        val code = nativeRegister()
        if (code != 0) Log.e("framix", "engine platform register failed: $code")
    }

    /** Called by Rust (JNI): makes a SurfaceProducer and answers [nativePreviewTextureDone] once. */
    fun createPreviewTexture(width: Int, height: Int, doneCtx: Long) {
        main.post {
            val producer = runCatching {
                textures.createSurfaceProducer().also { it.setSize(width, height) }
            }.getOrNull()
            if (producer == null) {
                nativePreviewTextureDone(doneCtx, ERR_GPU, 0, null)
                return@post
            }
            producers[producer.id()] = producer
            nativePreviewTextureDone(doneCtx, 0, producer.id(), producer.surface)
            spikeDecode(producer)
        }
    }

    /** Called by Rust; the SurfaceProducer picks up presented frames by itself. */
    @Suppress("UNUSED_PARAMETER") // Called from Rust through JNI.
    fun frameAvailable(textureId: Long) {}

    /** SPIKE (P1-056): decode the pushed clip off the main thread and draw it over the preview. */
    private fun spikeDecode(producer: TextureRegistry.SurfaceProducer) {
        val clip = files?.resolve("spike_clip.mp4")?.takeIf { it.isFile } ?: return
        Thread {
            runCatching {
                SpikeDecode.withFirstFrame(clip) { frame ->
                    nativeRenderFrame(producer.surface, frame)
                }
            }.onSuccess { Log.i("framix", "spike decode: nativeRenderFrame -> $it") }
                .onFailure { Log.w("framix", "spike decode failed", it) }
        }.start()
    }

    private external fun nativeRegister(): Int

    /** engine/ffi/src/android_platform.rs: hands the producer's Surface to the engine. */
    private external fun nativePreviewTextureDone(
        doneCtx: Long, status: Int, textureId: Long, surface: Surface?,
    )

    /** SPIKE (P1-056): engine/ffi/src/spike_preview.rs, draws an RGBA8 frame. */
    private external fun nativeRenderFrame(surface: Surface, frame: HardwareBuffer): Int

    private companion object {
        /** ENGINE_ERR_GPU in engine/ffi. */
        const val ERR_GPU = -5

        init {
            // The engine library Dart already loaded (native assets); same instance.
            System.loadLibrary("framix_ffi")
        }
    }
}
