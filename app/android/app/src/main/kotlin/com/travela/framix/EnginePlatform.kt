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

    /** The app context, for media access and the cache folder. */
    @Volatile private var context: Context? = null

    // Two workers, like the engine's in-flight limit; thumbnails never touch the main thread.
    private val thumbnails = Executors.newFixedThreadPool(2)

    /** Producers the engine holds, by texture id, until it releases them. Main thread. */
    private val producers = mutableMapOf<Long, TextureRegistry.SurfaceProducer>()

    /** Registers once per process and serves [textures] until [detach]. Main thread. */
    fun attach(textures: TextureRegistry, context: Context) {
        this.textures = textures
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
            var created: TextureRegistry.SurfaceProducer? = null
            val made = runCatching {
                val registry = checkNotNull(textures) { "no FlutterEngine" }
                val producer = registry.createSurfaceProducer().also { created = it }
                producer.setSize(width, height)
                producer to producer.surface
            }.onFailure {
                Log.w("framix", "preview texture failed", it)
                // A producer made before the failure is nobody's: release it now.
                created?.let(::releaseProducer)
            }.getOrNull()
            if (made == null) {
                nativePreviewTextureDone(doneCtx, 0, null)
                return@post
            }
            val (producer, surface) = made
            producers[producer.id()] = producer
            nativePreviewTextureDone(doneCtx, producer.id(), surface)
        }
    }

    /**
     * Called by Rust (JNI, engine thread) once the engine stopped drawing into texture [id] and
     * dropped its window reference: releases the SurfaceProducer on the main thread (P1-055).
     */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun releasePreviewTexture(id: Long) {
        main.post { producers.remove(id)?.let(::releaseProducer) }
    }

    /**
     * Releases [producer]; its FlutterEngine may be gone already (the Activity finished while
     * the engine lives on), and then release throws. Main thread.
     */
    private fun releaseProducer(producer: TextureRegistry.SurfaceProducer) {
        runCatching { producer.release() }
            .onFailure { Log.w("framix", "preview texture release failed: ${it.javaClass.simpleName}") }
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

    /**
     * The cached thumbnail file for these arguments, made if missing. The engine finds a
     * media's cache files by this name (engine/app/src/cache.rs); change both.
     */
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
            try {
                partial.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
            } catch (e: Exception) {
                partial.delete()
                throw e
            }
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

    // The export encoder (docs/adr/0005-export-encoder.md), called by Rust (JNI) on the export
    // worker only; each call may block. The shim holds the encoder until encoderFinish.

    /** Opens an H.264 encoder writing [path]; null if it can't. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun encoderOpen(width: Int, height: Int, fps: Int, kbps: Int, path: String): ExportEncoder? =
        ExportEncoder.open(width, height, fps, kbps, path)

    /** The Surface Rust draws [encoder]'s frames into. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun encoderSurface(encoder: ExportEncoder): Surface = encoder.surface

    /** Rust is about to draw the frame at [timeUs]; false once the encoder failed. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun encoderFrame(encoder: ExportEncoder, timeUs: Long): Boolean = encoder.frame(timeUs)

    /** Closes the file ([ok]) or cancels it; true on success. Called once per encoder. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun encoderFinish(encoder: ExportEncoder, ok: Boolean): Boolean = encoder.finish(ok)

    // The frame decoder (docs/adr/0006-decoder-port.md, P1-070), called by Rust (JNI) from the
    // engine thread (preview) or the export worker; each thread owns one, and calls may block.

    /** Opens a decoder; null if it can't (not attached, or no GLES). */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun decoderOpen(): FrameDecoder? = context?.let(FrameDecoder::open)

    /** The frame of [uri] at [timeUs] as an RGBA8 buffer valid until the next call; null on failure. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun decoderFrame(decoder: FrameDecoder, uri: String, image: Boolean, timeUs: Long): HardwareBuffer? =
        decoder.frame(uri, image, timeUs)

    /** Frees [decoder]; called once per opened decoder. */
    @Suppress("unused") // Kept for JNI by proguard-rules.pro.
    fun decoderClose(decoder: FrameDecoder) = decoder.close()

    private external fun nativeRegister(): Int

    /** engine/ffi/src/android_platform.rs: hands the producer's Surface (null = failed) over. */
    private external fun nativePreviewTextureDone(doneCtx: Long, textureId: Long, surface: Surface?)

    /** engine/ffi/src/android_platform.rs: the thumbnail file's path, or null if it failed. */
    private external fun nativeThumbnailDone(doneCtx: Long, path: String?)

    init {
        // The engine library Dart already loaded (native assets); same instance.
        System.loadLibrary("framix_ffi")
    }
}
