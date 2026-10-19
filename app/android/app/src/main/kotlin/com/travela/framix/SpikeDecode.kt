// SPIKE (P1-056): a hardware-decoded video frame reaches the engine with no CPU copy. MediaCodec
// decodes into a SurfaceTexture (opaque YCbCr, GL_TEXTURE_EXTERNAL_OES); one GLES pass converts
// it to RGBA8 in an ImageReader's HardwareBuffer, which Rust imports into wgpu (Vulkan). wgpu
// cannot sample the opaque YCbCr buffer itself. The Decoder port replaces this (P1-057).
package com.travela.framix

import android.graphics.PixelFormat
import android.graphics.SurfaceTexture
import android.hardware.HardwareBuffer
import android.media.ImageReader
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object SpikeDecode {
    private const val TIMEOUT_US = 10_000L
    private const val FRAME_WAIT_MS = 2_000L

    /**
     * Decodes the first video frame of [clip], converts it to RGBA8 on the GPU, and calls [use]
     * with that HardwareBuffer once the GPU is done writing it. Returns [use]'s result, or null
     * when the clip has no video or no frame came out. Blocking; call off the main thread.
     */
    fun <T> withFirstFrame(clip: File, use: (HardwareBuffer) -> T): T? {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(clip.path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("video/") == true
            } ?: return null
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            val width = format.getInteger(MediaFormat.KEY_WIDTH)
            val height = format.getInteger(MediaFormat.KEY_HEIGHT)
            ImageReader.newInstance(
                width, height, PixelFormat.RGBA_8888, 1,
                HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or HardwareBuffer.USAGE_GPU_COLOR_OUTPUT,
            ).use { reader ->
                Gles(reader.surface).use { gles ->
                    val drawn = gles.decodeAndConvert(extractor, format, width, height)
                    if (!drawn) return null
                }
                val image = waitForImage(reader) ?: return null
                return image.use { img -> img.hardwareBuffer?.use(use) }
            }
        } finally {
            extractor.release()
        }
    }

    private fun waitForImage(reader: ImageReader): android.media.Image? {
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(FRAME_WAIT_MS)
        while (System.nanoTime() < deadline) {
            reader.acquireLatestImage()?.let { return it }
            Thread.sleep(5)
        }
        return null
    }

    /** A private EGL context drawing into [target] (the ImageReader's Surface). */
    private class Gles(target: Surface) : AutoCloseable {
        private val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val context: android.opengl.EGLContext
        private val surface: android.opengl.EGLSurface

        init {
            val (context, surface) = create(target)
            this.context = context
            this.surface = surface
        }

        /** Makes the context and window surface current; frees what it made if a step fails. */
        private fun create(
            target: Surface,
        ): Pair<android.opengl.EGLContext, android.opengl.EGLSurface> {
            val version = IntArray(2)
            check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            val attributes = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT, EGL14.EGL_NONE,
            )
            check(EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) &&
                count[0] > 0) { "eglChooseConfig" }
            val context = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext" }
            val surface = EGL14.eglCreateWindowSurface(
                display, configs[0], target, intArrayOf(EGL14.EGL_NONE), 0,
            )
            if (surface == EGL14.EGL_NO_SURFACE ||
                !EGL14.eglMakeCurrent(display, surface, surface, context)
            ) {
                if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
                EGL14.eglDestroyContext(display, context)
                error("eglCreateWindowSurface / eglMakeCurrent")
            }
            return context to surface
        }

        /** Decodes one frame into an OES texture and draws it into the target. */
        fun decodeAndConvert(
            extractor: MediaExtractor, format: MediaFormat, width: Int, height: Int,
        ): Boolean {
            val texture = IntArray(1).also { GLES20.glGenTextures(1, it, 0) }[0]
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
            GLES20.glTexParameteri(
                GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
            )
            val frames = HandlerThread("framix spike frames").apply { start() }
            val decoded = SurfaceTexture(texture)
            val decoderSurface = Surface(decoded)
            var created: MediaCodec? = null
            try {
                val mime = format.getString(MediaFormat.KEY_MIME) ?: return false
                val codec = MediaCodec.createDecoderByType(mime).also { created = it }
                decoded.setDefaultBufferSize(width, height)
                val arrived = CountDownLatch(1)
                decoded.setOnFrameAvailableListener({ arrived.countDown() }, Handler(frames.looper))
                codec.configure(format, decoderSurface, null, 0)
                codec.start()
                android.util.Log.i("framix", "spike decode: ${codec.name}")
                if (!renderFirstFrame(codec, extractor)) return false
                if (!arrived.await(FRAME_WAIT_MS, TimeUnit.MILLISECONDS)) return false
                decoded.updateTexImage()
                val transform = FloatArray(16).also { decoded.getTransformMatrix(it) }
                GLES20.glViewport(0, 0, width, height)
                drawExternal(texture, transform)
                // The import has no fence yet (P1-053): finish here so the buffer is complete.
                GLES20.glFinish()
                return EGL14.eglSwapBuffers(display, surface)
            } finally {
                created?.let {
                    runCatching { it.stop() }
                    it.release()
                }
                decoderSurface.release()
                decoded.release()
                frames.quitSafely()
                GLES20.glDeleteTextures(1, intArrayOf(texture), 0)
            }
        }

        override fun close() {
            EGL14.eglMakeCurrent(
                display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
            )
            EGL14.eglDestroySurface(display, surface)
            EGL14.eglDestroyContext(display, context)
            // No eglTerminate: the default display is shared with Flutter's own GLES renderer.
        }
    }

    /** Feeds samples until the decoder outputs a frame, and renders it to its Surface. */
    private fun renderFirstFrame(codec: MediaCodec, extractor: MediaExtractor): Boolean {
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        repeat(500) {
            if (!inputDone) {
                val input = codec.dequeueInputBuffer(TIMEOUT_US)
                if (input >= 0) {
                    val size = extractor.readSampleData(codec.getInputBuffer(input)!!, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(input, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(input, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }
            val output = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            if (output >= 0) {
                val hasFrame = info.size > 0
                codec.releaseOutputBuffer(output, hasFrame)
                if (hasFrame) return true
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return false
            }
        }
        return false
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
    private const val FRAGMENT = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        uniform samplerExternalOES frame;
        varying vec2 uv;
        void main() { gl_FragColor = texture2D(frame, uv); }
    """

    /** Draws the external texture over the whole target; the YCbCr -> RGB is the driver's. */
    private fun drawExternal(texture: Int, transform: FloatArray) {
        val program = GLES20.glCreateProgram()
        listOf(GLES20.GL_VERTEX_SHADER to VERTEX, GLES20.GL_FRAGMENT_SHADER to FRAGMENT)
            .forEach { (type, source) ->
                val shader = GLES20.glCreateShader(type)
                GLES20.glShaderSource(shader, source)
                GLES20.glCompileShader(shader)
                GLES20.glAttachShader(program, shader)
                GLES20.glDeleteShader(shader)
            }
        GLES20.glLinkProgram(program)
        GLES20.glUseProgram(program)
        val quad = ByteBuffer.allocateDirect(8 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
            .put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)).also { it.position(0) }
        val position = GLES20.glGetAttribLocation(program, "position")
        GLES20.glEnableVertexAttribArray(position)
        GLES20.glVertexAttribPointer(position, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glUniformMatrix4fv(
            GLES20.glGetUniformLocation(program, "transform"), 1, false, transform, 0,
        )
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "frame"), 0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDeleteProgram(program)
    }
}
