package com.travela.framix

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Method channel `framix/media` (P1-011): the system document picker plus the metadata the
 * engine needs. Files are not copied: the engine stores the content:// URI and the app keeps
 * a persistable read permission. The engine validates every field.
 */
class MediaPicker(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickGallery" && call.method != "pickFiles") {
            return result.notImplemented()
        }
        if (pending != null) return result.error("busy", null, null)
        pending = result
        // One picker covers the gallery, Google Drive and local files on Android.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        activity.startActivityForResult(intent, REQUEST)
    }

    /** Handles the picker result; returns false for other requests. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uris = if (resultCode == Activity.RESULT_OK) picked(data) else emptyList()
        io.execute {
            val items = uris.mapNotNull { probe(it) }
            main.post { result.success(items) }
        }
        return true
    }

    private fun picked(data: Intent?): List<Uri> {
        val clip = data?.clipData ?: return listOfNotNull(data?.data)
        return (0 until clip.itemCount).map { clip.getItemAt(it).uri }
    }

    private fun probe(uri: Uri): Map<String, Any>? {
        val resolver = activity.contentResolver
        // Keep access across restarts; a provider that refuses still works for this session.
        runCatching {
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val type = resolver.getType(uri) ?: return null
        return when {
            type.startsWith("video/") -> probeVideo(uri)
            type.startsWith("image/") -> probeImage(uri)
            else -> null
        }
    }

    private fun probeVideo(uri: Uri): Map<String, Any>? = runCatching {
        MediaMetadataRetriever().use { r ->
            r.setDataSource(activity, uri)
            fun int(key: Int) = r.extractMetadata(key)?.toIntOrNull() ?: 0
            mapOf(
                "uri" to uri.toString(),
                "kind" to "video",
                "durationValue" to (r.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0L),
                "durationTimescale" to 1000,
                "width" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                "height" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                "rotation" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION),
                "codec" to codecTag(uri),
            )
        }
    }.getOrNull()?.takeIf { readable(it) }

    /**
     * Codec tag: the video track's MIME subtype without `video/` (hevc, avc, x-vnd.on2.vp9),
     * or empty when longer than the engine's 16-character limit. Informational only.
     */
    private fun codecTag(uri: Uri): String =
        videoMime(uri)?.removePrefix("video/")?.takeIf { it.length <= 16 } ?: ""

    private fun videoMime(uri: Uri): String? {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(activity, uri, null)
            (0 until extractor.trackCount)
                .mapNotNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) }
                .firstOrNull { it.startsWith("video/") }
        } catch (e: Exception) {
            null
        } finally {
            extractor.release()
        }
    }

    private fun probeImage(uri: Uri): Map<String, Any>? = runCatching {
        val resolver = activity.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val orientation = resolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
        mapOf(
            "uri" to uri.toString(),
            "kind" to "image",
            "durationValue" to 0L,
            "durationTimescale" to 0,
            "width" to bounds.outWidth,
            "height" to bounds.outHeight,
            "rotation" to rotationOf(orientation),
            "codec" to "",
        )
    }.getOrNull()?.takeIf { readable(it) }

    /** Drops items the platform could not measure, so one bad file doesn't sink the pick. */
    private fun readable(item: Map<String, Any>): Boolean {
        val sides = listOf(item["width"], item["height"]).all { (it as? Int ?: 0) > 0 }
        val video = item["kind"] == "video"
        return sides && (!video || (item["durationValue"] as? Long ?: 0L) > 0L)
    }

    /** Stops the worker thread; call when the activity is destroyed. */
    fun close() = io.shutdown()

    private fun rotationOf(orientation: Int) = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> 90
        ExifInterface.ORIENTATION_ROTATE_180, ExifInterface.ORIENTATION_FLIP_VERTICAL -> 180
        ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> 270
        else -> 0
    }

    private companion object {
        const val REQUEST = 0x46_4D // "FM"
    }
}
