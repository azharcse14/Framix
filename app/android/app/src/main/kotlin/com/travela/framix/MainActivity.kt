package com.travela.framix

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mediaPicker = MediaPicker(this)
    private var spikePreview: SpikePreview? = null  // SPIKE (P1-001)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "framix/media")
            .setMethodCallHandler(mediaPicker)
        // SPIKE (P1-001)
        val preview = SpikePreview(flutterEngine.renderer, getExternalFilesDir(null))
            .also { spikePreview = it }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "framix/spike_preview")
            .setMethodCallHandler(preview)
    }

    override fun onDestroy() {
        mediaPicker.close()
        spikePreview?.close()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!mediaPicker.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
