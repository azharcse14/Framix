import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'channel_media_importer.dart';

/// How a save to the gallery ended.
enum SaveResult { saved, denied, failed }

/// Hands an exported file to the platform over the `framix/media` method channel
/// (app/ios/Runner/MediaPicker.swift, app/android/.../MediaPicker.kt).
class ExportSharer {
  const ExportSharer();

  /// The folder exports go to: one the platform can save and share from (Android's cache,
  /// iOS tmp). Dart's own temp folder when the platform has no answer (tests).
  static Future<String> exportDir() async {
    try {
      return await mediaChannel.invokeMethod<String>('exportDir') ??
          Directory.systemTemp.path;
    } on Exception catch (e) {
      // PlatformException, or MissingPluginException where no platform side runs.
      debugPrint('export folder unavailable: ${e.runtimeType}');
      return Directory.systemTemp.path;
    }
  }

  /// Copies the file at [path] into the gallery (Photos, or Movies/Framix on Android).
  Future<SaveResult> saveToGallery(String path) async {
    try {
      final answer = await mediaChannel.invokeMethod<String>('saveToGallery', {
        'path': path,
      });
      return switch (answer) {
        'saved' => SaveResult.saved,
        'denied' => SaveResult.denied,
        _ => SaveResult.failed,
      };
    } on PlatformException catch (e) {
      // The code only; never the path.
      debugPrint('save to gallery failed: ${e.code}');
      return SaveResult.failed;
    }
  }

  /// Opens the system share sheet for the file at [path]; false if it could not open.
  Future<bool> share(String path) async {
    try {
      await mediaChannel.invokeMethod<void>('share', {'path': path});
      return true;
    } on PlatformException catch (e) {
      debugPrint('share failed: ${e.code}');
      return false;
    }
  }
}
