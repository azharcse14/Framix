// SPIKE (P1-001): shows the engine's wgpu test pattern through a Flutter Texture (iOS only).
// Off main until reviewed; the real preview path comes with P1-005.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/engine_bindings.g.dart';

/// Preview size the engine renders at.
const _width = 1280;
const _height = 720;

/// The engine's preview, or nothing where the zero-copy path is not built yet.
class SpikePreview extends StatefulWidget {
  const SpikePreview({super.key});

  @override
  State<SpikePreview> createState() => _SpikePreviewState();
}

class _SpikePreviewState extends State<SpikePreview> {
  static const _channel = MethodChannel('framix/spike_preview');
  int? _textureId;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) _start();
  }

  Future<void> _start() async {
    try {
      final created = await _channel.invokeMapMethod<String, Object?>(
        'create',
        {'width': _width, 'height': _height},
      );
      final textureId = created!['textureId']! as int;
      final metalTexture = created['metalTexture']! as int;
      // The handle is an opaque id<MTLTexture>; the frame itself never reaches Dart.
      final code = engine_spike_render_metal(
        Pointer.fromAddress(metalTexture),
        _width,
        _height,
      );
      if (code != ENGINE_OK) {
        debugPrint('spike preview: render failed ($code)');
        return;
      }
      await _channel.invokeMethod('frameAvailable', {'textureId': textureId});
      if (mounted) setState(() => _textureId = textureId);
    } on PlatformException catch (e) {
      debugPrint('spike preview: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _textureId;
    if (id == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: _width / _height,
      child: Texture(textureId: id),
    );
  }
}
