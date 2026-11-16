// The hardware encoder behind the engine's encoder_open, encoder_frame and encoder_finish
// (docs/adr/0005-export-encoder.md): H.264 MP4 through MediaCodec and MediaMuxer. The codec's
// input Surface is the render target; Rust draws each frame into it with the preview's window
// path (ADR 0004), so frames never copy. Every call comes from the engine's export worker and
// may block.
package com.travela.framix

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.io.File
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class ExportEncoder private constructor(
    private val file: File,
    private val codec: MediaCodec,
    private val muxer: MediaMuxer,
) {
    /** Runs the codec's callbacks; the only thread that writes [muxer] until [finish]. */
    private val thread = HandlerThread("framix-encoder").apply { start() }

    /** The render target Rust draws into. */
    lateinit var surface: Surface
        private set

    /**
     * Frame times in microseconds, in the order Rust drew them. A frame queued into the Surface
     * carries its queue time, not its frame time (wgpu cannot set it), so each encoded frame
     * takes the next time from here instead. Without B-frames the codec outputs frames in input
     * order.
     */
    private val times = ConcurrentLinkedQueue<Long>()

    /** The muxer's video track once the codec reported its format; codec thread. */
    private var track = -1

    /** The codec's own time of the last frame it output; codec thread. */
    private var lastCodecTimeUs = Long.MIN_VALUE

    @Volatile private var failed = false

    /** Counted down when the end of stream is out, or on failure. */
    private val ended = CountDownLatch(1)

    private fun start(format: MediaFormat) {
        codec.setCallback(callback, Handler(thread.looper))
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = codec.createInputSurface()
        codec.start()
    }

    /** Rust is about to draw the frame at [timeUs]; false once the codec failed. */
    fun frame(timeUs: Long): Boolean {
        if (failed) return false
        times.add(timeUs)
        return true
    }

    /**
     * [ok]: ends the stream and closes the file, true once it is complete. Otherwise cancels
     * and removes the file (true). Releases everything either way.
     */
    fun finish(ok: Boolean): Boolean {
        var complete = false
        try {
            if (ok && !failed) {
                codec.signalEndOfInputStream()
                complete = ended.await(FINISH_TIMEOUT_S, TimeUnit.SECONDS) && !failed &&
                    times.isEmpty() // A frame left over was never encoded.
            }
            codec.stop()
        } catch (e: Exception) {
            Log.w("framix", "export encoder finish failed: ${e.javaClass.simpleName}")
            complete = false
        }
        codec.release()
        surface.release()
        // No callback runs after this; the join also makes [track] visible here.
        thread.quitSafely()
        thread.join()
        try {
            if (track >= 0) muxer.stop()
        } catch (e: Exception) {
            Log.w("framix", "export muxer stop failed: ${e.javaClass.simpleName}")
            complete = false
        }
        muxer.release()
        // A file that did not complete is not a usable video.
        if (!complete) file.delete()
        return complete || !ok
    }

    private val callback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
            // Input comes through the Surface.
        }

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
            runCatching {
                track = muxer.addTrack(format)
                muxer.start()
            }.onFailure(::fail)
        }

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            runCatching {
                val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                if (info.size > 0 && !config) {
                    check(track >= 0) { "no format" }
                    // Reordered output (B-frames despite KEY_MAX_B_FRAMES) would mismatch times.
                    check(info.presentationTimeUs > lastCodecTimeUs) { "reordered frame" }
                    lastCodecTimeUs = info.presentationTimeUs
                    info.presentationTimeUs = checkNotNull(times.poll()) { "unqueued frame" }
                    muxer.writeSampleData(track, checkNotNull(codec.getOutputBuffer(index)), info)
                }
                codec.releaseOutputBuffer(index, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) ended.countDown()
            }.onFailure(::fail)
        }

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) = fail(e)
    }

    private fun fail(e: Throwable) {
        // Only the kind of failure: messages can carry the path.
        Log.w("framix", "export encoder failed: ${e.javaClass.simpleName}")
        failed = true
        ended.countDown()
    }

    companion object {
        /** How long [finish] waits for the codec to drain. */
        private const val FINISH_TIMEOUT_S = 10L

        /** Opens an encoder writing [path] (an old file there is replaced); null if it can't. */
        fun open(width: Int, height: Int, fps: Int, kbps: Int, path: String): ExportEncoder? {
            val file = File(path)
            // The engine only sends .mp4 paths.
            if (file.extension != "mp4") return null
            file.delete()
            var codec: MediaCodec? = null
            var muxer: MediaMuxer? = null
            var encoder: ExportEncoder? = null
            return try {
                codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                encoder = ExportEncoder(file, codec, muxer)
                encoder.start(format(width, height, fps, kbps))
                encoder
            } catch (e: Exception) {
                Log.w("framix", "export encoder failed to open: ${e.javaClass.simpleName}")
                encoder?.let { made ->
                    if (made::surface.isInitialized) made.surface.release()
                    made.thread.quitSafely()
                }
                codec?.release()
                muxer?.release()
                file.delete()
                null
            }
        }

        /** H.264 from the Surface, BT.709 video range like the iOS export. */
        private fun format(width: Int, height: Int, fps: Int, kbps: Int) =
            MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, kbps * 1000)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                // Output order is input order, so frame times map one to one (see `times`).
                setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
                setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
            }
    }
}
