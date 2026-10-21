// The callbacks only Android can serve, registered into the engine at startup
// (docs/adr/0003-platform-callbacks.md). Thin adapter: the engine decides what to draw and when.
package com.travela.framix

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.hardware.HardwareBuffer
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

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

    /** The app context, for media access and the cache folder. */
    @Volatile private var context: Context? = null

    // Two workers, like the engine's in-flight limit; thumbnails never touch the main thread.
    private val thumbnails = Executors.newFixedThreadPool(2)

    // ponytail: producers are never released; the preview makes one per launch (P1-055).
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()

    /** Registers once per process and serves [textures] until [detach]. Main thread. */
    fun attach(textures: TextureRegistry, files: File?, context: Context) {
        this.textures = textures
        this.files = files
        this.context = context.applicationContext
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

    /**
     * Called by Rust (JNI, engine thread): writes a JPEG thumbnail of [uri] at [timeUs] (videos)
     * no larger than [maxSide] into the cache folder, then answers [nativeThumbnailDone] exactly
     * once from a worker. The body only submits the work and must not throw after that.
     */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun requestThumbnail(uri: String, image: Boolean, timeUs: Long, maxSide: Int, doneCtx: Long) {
        thumbnails.execute {
            val path = runCatching { thumbnailFile(uri, image, timeUs, maxSide) }
                // Only the kind of failure: messages can carry the uri or a cache path.
                .onFailure { Log.w("framix", "thumbnail failed: ${it.javaClass.simpleName}") }
                .getOrNull()
            nativeThumbnailDone(doneCtx, path)
        }
    }

    /** The cached thumbnail file for these arguments, made if missing. */
    private fun thumbnailFile(uri: String, image: Boolean, timeUs: Long, maxSide: Int): String {
        val ctx = checkNotNull(context) { "not attached" }
        val dir = File(ctx.cacheDir, "thumbs").apply { mkdirs() }
        val name = MessageDigest.getInstance("SHA-256").digest(uri.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val file = File(dir, "$name-$timeUs-$maxSide.jpg")
        if (file.isFile) return file.path
        val bitmap = if (image) photo(ctx, Uri.parse(uri), maxSide) else frame(ctx, Uri.parse(uri), timeUs, maxSide)
        try {
            // Unique per worker: the same uri can be imported twice and made at once.
            val partial = File.createTempFile(file.name, ".part", dir)
            partial.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
            if (!partial.renameTo(file)) {
                partial.delete()
                check(file.isFile) { "rename" }
            }
        } finally {
            bitmap.recycle()
        }
        return file.path
    }

    private fun frame(ctx: Context, uri: Uri, timeUs: Long, maxSide: Int): Bitmap =
        MediaMetadataRetriever().use { r ->
            r.setDataSource(ctx, uri)
            // Scales to fit maxSide x maxSide and keeps the aspect ratio.
            checkNotNull(
                r.getScaledFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, maxSide, maxSide),
            ) { "no frame" }
        }

    private fun photo(ctx: Context, uri: Uri, maxSide: Int): Bitmap =
        ImageDecoder.decodeBitmap(ImageDecoder.createSource(ctx.contentResolver, uri)) { d, info, _ ->
            val (w, h) = info.size.width to info.size.height
            val scale = minOf(1f, maxSide.toFloat() / maxOf(w, h, 1))
            d.setTargetSize(maxOf((w * scale).toInt(), 1), maxOf((h * scale).toInt(), 1))
            d.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
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

    /** engine/ffi/src/android_platform.rs: the thumbnail file's path, or null if it failed. */
    private external fun nativeThumbnailDone(doneCtx: Long, path: String?)

    /** SPIKE (P1-056): engine/ffi/src/spike_preview.rs, draws an RGBA8 frame. */
    private external fun nativeRenderFrame(surface: Surface, frame: HardwareBuffer): Int

    init {
        // The engine library Dart already loaded (native assets); same instance.
        System.loadLibrary("framix_ffi")
    }
}
