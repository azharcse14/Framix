package com.travela.framix

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mediaPicker = MediaPicker(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "framix/media")
            .setMethodCallHandler(mediaPicker)
        EnginePlatform.attach(flutterEngine.renderer, getExternalFilesDir(null), this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        EnginePlatform.detach(flutterEngine.renderer)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        mediaPicker.close()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!mediaPicker.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
