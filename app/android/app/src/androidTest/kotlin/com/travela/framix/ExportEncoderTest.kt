// ExportEncoder on a real codec (P1-128): frames the GPU draws into its input Surface come out as an
// MP4 with one sample per frame, at the frame times given to frame() (not the queue times),
// at the configured size and close to the configured bitrate.
package com.travela.framix

import android.content.Context
import android.graphics.Bitmap
import android.graphics.HardwareRenderer
import android.graphics.RenderNode
import android.media.MediaExtractor
import android.media.MediaFormat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import java.nio.ByteBuffer
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ExportEncoderTest {
    @Test
    fun encodesEveryFrameAtItsFrameTime() {
        val file = File(ApplicationProvider.getApplicationContext<Context>().cacheDir, "export-test.mp4")
        val encoder = checkNotNull(ExportEncoder.open(WIDTH, HEIGHT, FPS, KBPS, file.path))
        val times = List(FRAMES) { it * 1_000_000L / FPS }
        // Noise in 8x8 blocks, so rate control decides the bitrate: on the emulator's encoder this
        // content costs about 1.5 Mbps at the highest QP and 4.4 Mbps at the lowest, so an encoder
        // that undershoots KBPS (rate control misled by queue times) falls below the band.
        val noise = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(WIDTH * HEIGHT)
        val random = Random(1)
        // GPU drawing like the engine's. Not Surface.lockHardwareCanvas: its unlockCanvasAndPost
        // queues the buffer later on HWUI's RenderThread, so the end of stream overtook the last
        // frames. waitForPresent returns once the buffer is queued, like the engine's Vulkan
        // present.
        val node = RenderNode("frame").apply { setPosition(0, 0, WIDTH, HEIGHT) }
        val renderer = HardwareRenderer().apply {
            setContentRoot(node)
            setSurface(encoder.surface)
        }
        var drawn = false
        try {
            for (time in times) {
                assertTrue(encoder.frame(time))
                fillBlocks(pixels, random)
                noise.setPixels(pixels, 0, WIDTH, 0, 0, WIDTH, HEIGHT)
                node.beginRecording().drawBitmap(noise, 0f, 0f, null)
                node.endRecording()
                draw(renderer)
            }
            drawn = true
        } finally {
            renderer.destroy()
            // A failed draw cancels the export so the codec and its thread don't outlive the test.
            if (!drawn) encoder.finish(false)
        }
        assertTrue(encoder.finish(true))

        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.path)
            assertEquals(1, extractor.trackCount)
            val format = extractor.getTrackFormat(0)
            assertEquals(MediaFormat.MIMETYPE_VIDEO_AVC, format.getString(MediaFormat.KEY_MIME))
            assertEquals(WIDTH, format.getInteger(MediaFormat.KEY_WIDTH))
            assertEquals(HEIGHT, format.getInteger(MediaFormat.KEY_HEIGHT))
            extractor.selectTrack(0)
            val sampleTimes = mutableListOf<Long>()
            var bytes = 0L
            val buffer = ByteBuffer.allocate(WIDTH * HEIGHT * 4)
            while (true) {
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                sampleTimes.add(extractor.sampleTime)
                bytes += size
                extractor.advance()
            }
            assertEquals(times, sampleTimes)
            val kbps = bytes * 8 * FPS / FRAMES / 1000
            assertTrue("bitrate $kbps kbps, configured $KBPS", kbps in KBPS * 3 / 4..KBPS * 5 / 4)
        } finally {
            extractor.release()
            file.delete()
        }
    }

    /** Fills [pixels] with opaque random colors in BLOCK x BLOCK squares. */
    private fun fillBlocks(pixels: IntArray, random: Random) {
        for (top in 0 until HEIGHT step BLOCK) for (left in 0 until WIDTH step BLOCK) {
            val color = random.nextInt() or 0xFF000000.toInt()
            for (y in top until top + BLOCK) pixels.fill(color, y * WIDTH + left, y * WIDTH + left + BLOCK)
        }
    }

    /** Draws one frame, again while HWUI drops it (it does when the codec holds every buffer). */
    private fun draw(renderer: HardwareRenderer) {
        repeat(DRAW_ATTEMPTS) {
            val result = renderer.createRenderRequest().setWaitForPresent(true).syncAndDraw()
            if (result != HardwareRenderer.SYNC_FRAME_DROPPED) {
                assertEquals(HardwareRenderer.SYNC_OK, result)
                return
            }
            Thread.sleep(DRAW_RETRY_MS)
        }
        fail("frame dropped $DRAW_ATTEMPTS times")
    }

    private companion object {
        const val WIDTH = 320
        const val HEIGHT = 240
        const val FPS = 30
        const val KBPS = 4_000
        const val BLOCK = 8
        const val FRAMES = 60
        const val DRAW_ATTEMPTS = 100
        const val DRAW_RETRY_MS = 10L
    }
}
