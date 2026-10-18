// SPIKE (P1-001): Android only. Kotlin draws the engine's test pattern through a method
// channel; Android moves to the platform callbacks (PreviewCubit) once it has a vtable.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/preview_cubit.dart';

const _width = PreviewCubit.width;
const _height = PreviewCubit.height;

/// The Android spike preview.
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
    _startAndroid();
  }

  /// Kotlin makes a SurfaceProducer and the engine draws into its Surface (JNI), so Dart only
  /// gets the texture id; Flutter picks the frame up when it is presented.
  Future<void> _startAndroid() async {
    try {
      final created = await _channel.invokeMapMethod<String, Object?>(
        'create',
        {'width': _width, 'height': _height},
      );
      final textureId = created!['textureId']! as int;
      if (mounted) setState(() => _textureId = textureId);
    } on PlatformException catch (e) {
      debugPrint('spike preview: ${e.code} ${e.message}');
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
