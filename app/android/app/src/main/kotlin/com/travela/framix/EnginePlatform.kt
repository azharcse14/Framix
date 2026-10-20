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
 * (engine/ffi/src/android_platform.rs). The registration is once per process, like the engine
 * library; each FlutterEngine (one per Activity) attaches its TextureRegistry while it lives.
 */
object EnginePlatform {
    private val main = Handler(Looper.getMainLooper())
    private var registered = false

    /** The current FlutterEngine's textures; null between engines. */
    @Volatile private var textures: TextureRegistry? = null

    /** SPIKE (P1-056): app files dir; `spike_clip.mp4` there (adb push) is drawn over the preview. */
    @Volatile private var files: File? = null

    // ponytail: producers are never released; the preview makes one per launch (P1-055).
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()

    /** Registers once per process and serves [textures] until [detach]. Main thread. */
    fun attach(textures: TextureRegistry, files: File?) {
        this.textures = textures
        this.files = files
        if (registered) return
        registered = true
        val code = nativeRegister()
        if (code != 0) Log.e("framix", "engine platform register failed: $code")
    }

    /** The FlutterEngine is going away; later requests fail until the next [attach]. */
    fun detach(textures: TextureRegistry) {
        if (this.textures === textures) this.textures = null
    }

    /**
     * Called by Rust (JNI, engine thread): makes a SurfaceProducer and answers
     * [nativePreviewTextureDone] exactly once on the main thread. The body is only the post and
     * must not throw after it: Rust answers itself when this call throws.
     */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun createPreviewTexture(width: Int, height: Int, doneCtx: Long) {
        main.post {
            val made = runCatching {
                val registry = checkNotNull(textures) { "no FlutterEngine" }
                val producer = registry.createSurfaceProducer().also { it.setSize(width, height) }
                producer to producer.surface
            }.onFailure { Log.w("framix", "preview texture failed", it) }.getOrNull()
            if (made == null) {
                nativePreviewTextureDone(doneCtx, 0, null)
                return@post
            }
            val (producer, surface) = made
            producers[producer.id()] = producer
            nativePreviewTextureDone(doneCtx, producer.id(), surface)
            spikeDecode(producer)
        }
    }

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

    /** engine/ffi/src/android_platform.rs: hands the producer's Surface (null = failed) over. */
    private external fun nativePreviewTextureDone(doneCtx: Long, textureId: Long, surface: Surface?)

    /** SPIKE (P1-056): engine/ffi/src/spike_preview.rs, draws an RGBA8 frame. */
    private external fun nativeRenderFrame(surface: Surface, frame: HardwareBuffer): Int

    init {
        // The engine library Dart already loaded (native assets); same instance.
        System.loadLibrary("framix_ffi")
    }
}
