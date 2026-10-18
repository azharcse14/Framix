import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Mirrors the engine's preview: the Flutter texture id once the engine reports PreviewReady,
/// null before that (or where the platform has no preview yet).
class PreviewCubit extends Cubit<int?> {
  PreviewCubit(this._engine) : super(null) {
    _events = _engine.events
        .where((e) => e.hasPreviewReady())
        .map((e) => e.previewReady.textureId.toInt())
        .listen(emit);
    _engine.send(
      Command(
        createPreview: CreatePreview(width: width, height: height),
      ),
    );
  }

  /// Size the engine renders the preview at.
  static const width = 1280;
  static const height = 720;

  final FramixEngine _engine;
  late final StreamSubscription<int> _events;

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
