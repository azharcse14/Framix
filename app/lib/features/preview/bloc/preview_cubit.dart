import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// The engine's preview as the UI shows it.
sealed class PreviewState {
  const PreviewState();
}

/// Asked for, not reported yet.
final class PreviewPending extends PreviewState {
  const PreviewPending();
}

/// The engine draws into the Flutter texture [textureId].
final class PreviewShown extends PreviewState {
  const PreviewShown(this.textureId);
  final int textureId;

  @override
  bool operator ==(Object other) =>
      other is PreviewShown && other.textureId == textureId;

  @override
  int get hashCode => textureId.hashCode;
}

/// The engine refused CreatePreview (no GPU, no preview on this platform) or could not make
/// the preview it accepted (UX-035).
final class PreviewUnavailable extends PreviewState {
  const PreviewUnavailable();
}

/// Mirrors the engine's preview: shown once the engine reports PreviewReady, unavailable when
/// it refuses CreatePreview or fails it later (CommandFailed of FAILURE_KIND_PREVIEW). A
/// PreviewLost for the shown texture asks the engine for a new preview.
class PreviewCubit extends Cubit<PreviewState> {
  PreviewCubit(this._engine) : super(const PreviewPending()) {
    _events = _engine.events.listen((e) {
      if (e.hasPreviewReady()) {
        emit(PreviewShown(e.previewReady.textureId.toInt()));
      }
      // A late loss of an older texture must not drop the one now shown.
      if (e.hasPreviewLost() &&
          state == PreviewShown(e.previewLost.textureId.toInt())) {
        emit(const PreviewPending());
        _create();
      }
      if (e.hasCommandFailed() && _isPreviewFailure(e.commandFailed)) {
        emit(const PreviewUnavailable());
      }
    });
    _create();
  }

  /// Size the engine renders the preview at.
  static const width = 1280;
  static const height = 720;

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;

  /// Id of the last CreatePreview; its refusal makes the preview unavailable.
  int _createId = 0;

  bool _isPreviewFailure(CommandFailed failed) => failed.commandId == 0
      ? failed.kind == FailureKind.FAILURE_KIND_PREVIEW
      : failed.commandId.toInt() == _createId;

  /// A refused preview is shown in the canvas, not as the generic failure message (UX-034).
  void _create() => _createId = _engine.send(
    Command(
      createPreview: CreatePreview(width: width, height: height),
    ),
    reportsFailure: true,
  );

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
