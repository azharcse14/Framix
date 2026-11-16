// The decoder behind the engine's decoder_open, decoder_frame and decoder_close
// (docs/adr/0006-decoder-port.md, P1-070). Thin adapter: the engine picks the time and places the
// picture (rotation, crop, fit), so frames are handed over as stored.
package com.travela.framix

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.hardware.HardwareBuffer
import android.media.Image
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLUtils
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/**
 * One engine thread's decoder (preview, export worker). Every call blocks the caller until the
 * frame is ready. The picture always reaches the engine as one RGBA8 HardwareBuffer: wgpu cannot
 * sample MediaCodec's opaque YCbCr buffers, so one GLES pass draws them (and photos) into an
 * ImageReader (ADR 0004, P1-056). The returned buffer stays valid until the next call or [close].
 *
 * All GL and codec work runs on this decoder's own thread, where its EGL context stays current;
 * the engine thread's GL state (wgpu's GLES backend) is never touched.
 */
class FrameDecoder private constructor(private val context: Context) {
    private val work = Executors.newSingleThreadExecutor { Thread(it, "framix decoder") }

    /** Listener callbacks (SurfaceTexture, ImageReader) land here while [work] waits on them. */
    private val callbacks = HandlerThread("framix decoder callbacks").apply { start() }
    private val callbackHandler = Handler(callbacks.looper)

    private lateinit var gl: Gl

    // Least recently used first (access order), at most CACHED of each: PIP with two videos or
    // photos keeps both open instead of reopening a codec every frame (P1-131).
    private val outputs = LinkedHashMap<Pair<Int, Int>, Output>(4, 0.75f, true)
    private val videos = LinkedHashMap<String, Video>(4, 0.75f, true)
    private val photos = LinkedHashMap<String, Photo>(4, 0.75f, true)

    /** The frame handed out last and the media range it shows; kept until the next call. */
    private var shown: Shown? = null

    /** Fills the buffer with the frame of [uri] at [timeUs] (photos: their one frame); null on failure. */
    fun frame(uri: String, image: Boolean, timeUs: Long): HardwareBuffer? = onThread {
        runCatching { frameOnThread(uri, image, timeUs) }
            // Only the kind of failure: messages can carry the uri.
            .onFailure {
                Log.w("framix", "decode failed: ${it.javaClass.simpleName}")
                videos.remove(uri)?.let(::closeVideo)
            }
            .getOrNull()
    }

    /** Frees everything; the decoder is unusable after. */
    fun close() {
        try {
            onThread {
                shown?.release()
                shown = null
                videos.values.forEach(::closeVideo)
                videos.clear()
                photos.values.forEach(::closePhoto)
                photos.clear()
                outputs.values.forEach { it.close(gl) }
                outputs.clear()
                gl.close()
            }
        } finally {
            work.shutdown()
            callbacks.quitSafely()
        }
    }

    private fun <T> onThread(task: () -> T): T = work.submit(task).get()

    /**
     * The entry for [key], else [make]'s, after closing the least recently used one if the cache
     * is full (first, so no more than CACHED codecs are ever open). Runs only once the frame
     * handed out last is released, so closing never frees a buffer the engine still reads.
     */
    private fun <K, V> LinkedHashMap<K, V>.cached(key: K, close: (V) -> Unit, make: () -> V): V {
        get(key)?.let { return it }
        evictDownTo(CACHED - 1, close)
        return make().also { put(key, it) }
    }

    /** Closes the least recently used entries until at most [count] are left. */
    private fun <K, V> LinkedHashMap<K, V>.evictDownTo(count: Int, close: (V) -> Unit) {
        while (size > count) {
            val eldest = entries.first()
            remove(eldest.key)
            close(eldest.value)
        }
    }

    private fun frameOnThread(uri: String, image: Boolean, timeUs: Long): HardwareBuffer? {
        shown?.let { if (it.uri == uri && it.image == image && it.covers(timeUs)) return it.buffer }
        // The previous frame's buffer is free again only now (decoder_frame's contract).
        shown?.release()
        shown = null
        val (out, range) = if (image) drawPhoto(uri) else drawVideo(uri, timeUs) ?: return null
        val img = out.take() ?: return null
        val buffer = img.hardwareBuffer
        if (buffer == null) {
            img.close()
            return null
        }
        shown = Shown(uri, image, range, img, buffer)
        return buffer
    }

    // MARK: Photo

    /** Draws the photo (stored orientation: the engine applies EXIF) into the output. */
    private fun drawPhoto(uri: String): Pair<Output, LongRange> {
        val cached = photos.cached(uri, ::closePhoto) { loadPhoto(uri) }
        val out = outputFor(cached.width, cached.height)
        gl.draw(out, Gl.Source.Photo(cached.texture), Gl.FLIP_V)
        return out to Long.MIN_VALUE..Long.MAX_VALUE
    }

    private fun loadPhoto(uri: String): Photo {
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(parsed)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        check(bounds.outWidth > 0 && bounds.outHeight > 0) { "no photo" }
        var sample = 1
        // ponytail: photos are capped at 4096 px a side, as on iOS; a quality setting is ENG-008.
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > PHOTO_MAX_SIDE) sample *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = checkNotNull(
            resolver.openInputStream(parsed)?.use { BitmapFactory.decodeStream(it, null, options) },
        ) { "no photo" }
        try {
            val texture = IntArray(1).also { GLES20.glGenTextures(1, it, 0) }[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture)
            Gl.linearClamp(GLES20.GL_TEXTURE_2D)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            return Photo(texture, bitmap.width, bitmap.height)
        } finally {
            bitmap.recycle()
        }
    }

    // MARK: Video

    /**
     * Draws the frame still showing at [timeUs] (the first one whose successor starts after it,
     * like iOS) into the output; null if there is none. Reads forward while the target is under
     * a second ahead, else seeks to the sync frame before it.
     */
    private fun drawVideo(uri: String, timeUs: Long): Pair<Output, LongRange>? {
        // ponytail: forward reads up to 1 s, else seek to the previous sync frame; keyframe-aware
        // seeking and caching are ENG-006.
        val v = videos.cached(uri, ::closeVideo) { openVideo(uri) }
        // The latched frame still shows: draw it again (another call may have used the output since).
        v.latched?.let { (range, transform) ->
            if (timeUs in range) {
                val out = outputFor(v.width, v.height)
                gl.draw(out, Gl.Source.External(v.textureId), transform)
                return out to range
            }
        }
        if (timeUs < v.position || timeUs - v.position > SEEK_AHEAD_US) v.seek(timeUs)
        var current: Video.Out? = null
        while (true) {
            val next = v.pending ?: v.nextOutput()
            v.pending = null
            if (next == null) break
            if (current != null && next.ptsUs > timeUs) {
                v.pending = next
                break
            }
            current?.let { v.codec.releaseOutputBuffer(it.index, false) }
            current = next
            if (next.ptsUs > timeUs) {
                // A first frame after the target: read one ahead too, so its range ends where
                // the next frame starts.
                v.pending = v.nextOutput()
                break
            }
        }
        val chosen = current ?: return null
        v.position = chosen.ptsUs
        // Showing until the next frame starts; the last frame shows to the end. A first frame
        // that starts after the target also shows from the target on.
        val start = minOf(timeUs, chosen.ptsUs)
        val end = v.pending?.ptsUs ?: if (v.outputDone) Long.MAX_VALUE else chosen.ptsUs + 1
        v.render(chosen, callbackHandler)
        val out = outputFor(v.width, v.height)
        val transform = FloatArray(16).also { v.texture.getTransformMatrix(it) }
        v.latched = (start until end) to transform
        gl.draw(out, Gl.Source.External(v.textureId), transform)
        return out to (start until end)
    }

    /**
     * Opens [uri]'s video. If the device is out of codecs, closes this decoder's other cached
     * videos and tries once more (P1-132); any other failure (a bad file) is thrown as is.
     */
    private fun openVideo(uri: String): Video = try {
        Video.open(context, uri)
    } catch (e: MediaCodec.CodecException) {
        if (!isCodecShortage(e) || videos.isEmpty()) throw e
        videos.evictDownTo(0, ::closeVideo)
        Video.open(context, uri)
    }

    private fun closeVideo(video: Video) {
        try {
            video.close()
        } finally {
            GLES20.glDeleteTextures(1, intArrayOf(video.textureId), 0)
        }
    }

    private fun closePhoto(photo: Photo) = GLES20.glDeleteTextures(1, intArrayOf(photo.texture), 0)

    /** The output sized [width] x [height] (one per size, cached like the media). */
    private fun outputFor(width: Int, height: Int): Output =
        outputs.cached(width to height, { it.close(gl) }) { Output(width, height, gl, callbackHandler) }

    /** The frame handed out: [image] owns [buffer] until released. */
    private class Shown(
        val uri: String,
        val image: Boolean,
        private val range: LongRange,
        private val img: Image,
        val buffer: HardwareBuffer,
    ) {
        fun covers(timeUs: Long) = timeUs in range

        fun release() {
            buffer.close()
            img.close()
        }
    }

    private class Photo(val texture: Int, val width: Int, val height: Int)

    /** An ImageReader of RGBA8 HardwareBuffers the engine samples, and the EGL surface on it. */
    private class Output(val width: Int, val height: Int, gl: Gl, handler: Handler) {
        private val ready = Semaphore(0)
        private val reader = ImageReader.newInstance(
            width, height, PixelFormat.RGBA_8888, 2,
            HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or HardwareBuffer.USAGE_GPU_COLOR_OUTPUT,
        )
        val surface: EGLSurface = try {
            gl.windowSurface(reader.surface)
        } catch (e: Exception) {
            reader.close()
            throw e
        }

        init {
            reader.setOnImageAvailableListener({ ready.release() }, handler)
        }

        /** The image the last draw queued; waits for it. Null if it never came. */
        fun take(): Image? {
            if (!ready.tryAcquire(FRAME_WAIT_MS, TimeUnit.MILLISECONDS)) return null
            ready.drainPermits()
            return reader.acquireLatestImage()
        }

        /** Drops an image a failed call left queued, so [take] sees only the next draw. */
        fun discard() {
            reader.acquireLatestImage()?.close()
            ready.drainPermits()
        }

        fun close(gl: Gl) {
            gl.destroySurface(surface)
            reader.close()
        }
    }

    /** One video's extractor and codec, decoding into a SurfaceTexture on [textureId]. */
    private class Video(
        val extractor: MediaExtractor,
        val codec: MediaCodec,
        val textureId: Int,
        val texture: SurfaceTexture,
        private val surface: Surface,
        val width: Int,
        val height: Int,
    ) {
        class Out(val index: Int, val ptsUs: Long)

        private val info = MediaCodec.BufferInfo()
        private val arrived = Semaphore(0)
        private var inputDone = false
        var outputDone = false
            private set

        /** A dequeued output not yet released: the frame after the last one shown. */
        var pending: Out? = null

        /** The frame in [texture] (its time range and transform); stays there until [render]. */
        var latched: Pair<LongRange, FloatArray>? = null

        /** Start time of the last frame shown, or where the last seek landed. */
        var position = 0L

        /** Seeks to the sync frame at or before [timeUs]. */
        fun seek(timeUs: Long) {
            extractor.seekTo(timeUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            // Drops every queued and dequeued buffer, so `pending` is gone too.
            codec.flush()
            pending = null
            inputDone = false
            outputDone = false
            position = maxOf(0L, extractor.sampleTime)
        }

        /** The next decoded frame (not yet rendered), or null at the end of the stream. */
        fun nextOutput(): Out? {
            if (outputDone) return null
            val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(FRAME_WAIT_MS)
            while (System.nanoTime() < deadline) {
                if (!inputDone) feed()
                val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (index < 0) continue
                val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                if (info.size > 0) {
                    outputDone = end
                    return Out(index, info.presentationTimeUs)
                }
                codec.releaseOutputBuffer(index, false)
                if (end) {
                    outputDone = true
                    return null
                }
            }
            error("decoder stalled")
        }

        private fun feed() {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index < 0) return
            val size = extractor.readSampleData(checkNotNull(codec.getInputBuffer(index)), 0)
            if (size < 0) {
                codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                inputDone = true
            } else {
                codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                extractor.advance()
            }
        }

        /** Sends [frame] to the SurfaceTexture and latches it into [textureId]. GL thread. */
        fun render(frame: Out, handler: Handler) {
            latched = null
            arrived.drainPermits()
            texture.setOnFrameAvailableListener({ arrived.release() }, handler)
            codec.releaseOutputBuffer(frame.index, true)
            check(arrived.tryAcquire(FRAME_WAIT_MS, TimeUnit.MILLISECONDS)) { "no frame" }
            texture.updateTexImage()
        }

        fun close() {
            runCatching { codec.stop() }
            codec.release()
            extractor.release()
            surface.release()
            texture.release()
        }

        companion object {
            /** Opens the first video track of [uri]. Needs the GL thread (makes the texture). */
            fun open(context: Context, uri: String): Video {
                val extractor = MediaExtractor()
                var codec: MediaCodec? = null
                var texture: SurfaceTexture? = null
                var surface: Surface? = null
                val textureId = IntArray(1).also { GLES20.glGenTextures(1, it, 0) }[0]
                try {
                    extractor.setDataSource(context, Uri.parse(uri), null)
                    val track = (0 until extractor.trackCount).first {
                        extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                            ?.startsWith("video/") == true
                    }
                    extractor.selectTrack(track)
                    val format = extractor.getTrackFormat(track)
                    // Stored orientation: the engine applies the rotation itself.
                    format.setInteger(MediaFormat.KEY_ROTATION, 0)
                    val width = format.getInteger(MediaFormat.KEY_WIDTH)
                    val height = format.getInteger(MediaFormat.KEY_HEIGHT)
                    GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
                    Gl.linearClamp(GLES11Ext.GL_TEXTURE_EXTERNAL_OES)
                    texture = SurfaceTexture(textureId).apply { setDefaultBufferSize(width, height) }
                    surface = Surface(texture)
                    val mime = checkNotNull(format.getString(MediaFormat.KEY_MIME))
                    codec = MediaCodec.createDecoderByType(mime)
                    codec.configure(format, surface, null, 0)
                    codec.start()
                    return Video(extractor, codec, textureId, texture, surface, width, height)
                } catch (e: Exception) {
                    codec?.release()
                    surface?.release()
                    texture?.release()
                    extractor.release()
                    GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
                    throw e
                }
            }
        }
    }

    /** The decoder thread's EGL context and the two conversion programs. */
    private class Gl {
        sealed interface Source {
            /** A SurfaceTexture's OES texture: the driver converts YCbCr to RGB. */
            data class External(val texture: Int) : Source

            /** A 2D RGBA texture. */
            data class Photo(val texture: Int) : Source
        }

        private val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val config: EGLConfig
        private val context: EGLContext

        /** 1x1, current whenever no output is: GL calls need a surface without surfaceless EGL. */
        private val idle: EGLSurface
        private val external: Int
        private val flat: Int
        private val quad = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
            .also { it.position(0) }

        init {
            val version = IntArray(2)
            check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            val attributes = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT or EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_NONE,
            )
            check(
                EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) &&
                    count[0] > 0,
            ) { "eglChooseConfig" }
            config = checkNotNull(configs[0])
            context = EGL14.eglCreateContext(
                display, config, EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext" }
            idle = EGL14.eglCreatePbufferSurface(
                display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
            )
            if (idle == EGL14.EGL_NO_SURFACE || !EGL14.eglMakeCurrent(display, idle, idle, context)) {
                if (idle != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, idle)
                EGL14.eglDestroyContext(display, context)
                error("eglMakeCurrent")
            }
            try {
                external = program(EXTERNAL_FRAGMENT)
                flat = program(FLAT_FRAGMENT)
            } catch (e: Exception) {
                EGL14.eglMakeCurrent(
                    display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
                )
                EGL14.eglDestroySurface(display, idle)
                EGL14.eglDestroyContext(display, context)
                throw e
            }
        }

        fun windowSurface(target: Surface): EGLSurface {
            val surface = EGL14.eglCreateWindowSurface(
                display, config, target, intArrayOf(EGL14.EGL_NONE), 0,
            )
            check(surface != EGL14.EGL_NO_SURFACE) { "eglCreateWindowSurface" }
            return surface
        }

        fun destroySurface(surface: EGLSurface) {
            EGL14.eglMakeCurrent(display, idle, idle, context)
            EGL14.eglDestroySurface(display, surface)
        }

        /** Draws [source] over the whole [out] through [transform] and queues it to the reader. */
        fun draw(out: Output, source: Source, transform: FloatArray) {
            out.discard()
            check(EGL14.eglMakeCurrent(display, out.surface, out.surface, context)) { "eglMakeCurrent" }
            GLES20.glViewport(0, 0, out.width, out.height)
            val (program, target, texture) = when (source) {
                is Source.External -> Triple(external, GLES11Ext.GL_TEXTURE_EXTERNAL_OES, source.texture)
                is Source.Photo -> Triple(flat, GLES20.GL_TEXTURE_2D, source.texture)
            }
            GLES20.glUseProgram(program)
            val position = GLES20.glGetAttribLocation(program, "position")
            GLES20.glEnableVertexAttribArray(position)
            GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, quad)
            GLES20.glUniformMatrix4fv(
                GLES20.glGetUniformLocation(program, "transform"), 1, false, transform, 0,
            )
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(target, texture)
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "frame"), 0)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            // The engine imports the buffer without a fence yet (P1-053): finish so it is complete.
            GLES20.glFinish()
            check(EGL14.eglSwapBuffers(display, out.surface)) { "eglSwapBuffers" }
        }

        fun close() {
            GLES20.glDeleteProgram(external)
            GLES20.glDeleteProgram(flat)
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(display, idle)
            EGL14.eglDestroyContext(display, context)
            // No eglTerminate: the default display is shared with Flutter's own GLES renderer.
        }

        private fun program(fragment: String): Int {
            val program = GLES20.glCreateProgram()
            listOf(GLES20.GL_VERTEX_SHADER to VERTEX, GLES20.GL_FRAGMENT_SHADER to fragment)
                .forEach { (type, source) ->
                    val shader = GLES20.glCreateShader(type)
                    GLES20.glShaderSource(shader, source)
                    GLES20.glCompileShader(shader)
                    GLES20.glAttachShader(program, shader)
                    GLES20.glDeleteShader(shader)
                }
            GLES20.glLinkProgram(program)
            val linked = IntArray(1).also { GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, it, 0) }
            check(linked[0] == GLES20.GL_TRUE) { "shader link" }
            return program
        }

        companion object {
            /** Maps v to 1 - v: a 2D texture's first row is the picture's top. Column-major. */
            val FLIP_V = floatArrayOf(1f, 0f, 0f, 0f, 0f, -1f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 1f, 0f, 1f)

            fun linearClamp(target: Int) {
                GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
                GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
                GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
                GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            }

            private const val VERTEX = """
                attribute vec2 position;
                uniform mat4 transform;
                varying vec2 uv;
                void main() {
                  uv = (transform * vec4((position + 1.0) * 0.5, 0.0, 1.0)).xy;
                  gl_Position = vec4(position, 0.0, 1.0);
                }
            """

            // ponytail: the driver picks the YCbCr matrix and range; reading the stream's tags
            // and converting in wgpu (a YCbCr sampler) is the P1-002 follow-up.
            private const val EXTERNAL_FRAGMENT = """
                #extension GL_OES_EGL_image_external : require
                precision mediump float;
                uniform samplerExternalOES frame;
                varying vec2 uv;
                void main() { gl_FragColor = texture2D(frame, uv); }
            """

            private const val FLAT_FRAGMENT = """
                precision mediump float;
                uniform sampler2D frame;
                varying vec2 uv;
                void main() { gl_FragColor = texture2D(frame, uv); }
            """
        }
    }

    companion object {
        private const val TIMEOUT_US = 10_000L
        private const val FRAME_WAIT_MS = 2_000L
        private const val SEEK_AHEAD_US = 1_000_000L
        private const val PHOTO_MAX_SIDE = 4096

        // ponytail: 2 of each per decoder: PIP with two videos or photos. Each decoder (preview,
        // export) holds up to 2 MediaCodecs, so up to 4 app-wide; a phone that has fewer makes
        // openVideo free this decoder's others and retry once. Photos are up to 64 MB textures.
        // Three or more alternating media evict each other every frame (as before); a decoder
        // pool is ENG-007.
        private const val CACHED = 2

        /**
         * True if [e] says the device ran out of codec resources, not that the file is bad:
         * MediaCodec reports a codec it cannot allocate at create (NO_MEMORY) as transient, and
         * one it cannot configure or start as ERROR_INSUFFICIENT_RESOURCE or recoverable.
         */
        private fun isCodecShortage(e: MediaCodec.CodecException) =
            e.isTransient || e.isRecoverable ||
                e.errorCode == MediaCodec.CodecException.ERROR_INSUFFICIENT_RESOURCE

        /** A decoder with its own thread and EGL context, or null if GLES is unavailable. */
        fun open(context: Context): FrameDecoder? {
            val decoder = FrameDecoder(context.applicationContext)
            val ready = runCatching { decoder.onThread { decoder.gl = Gl() } }
            return if (ready.isSuccess) {
                decoder
            } else {
                Log.w("framix", "decoder open failed: ${ready.exceptionOrNull()?.javaClass?.simpleName}")
                decoder.work.shutdown()
                decoder.callbacks.quitSafely()
                null
            }
        }
    }
}
