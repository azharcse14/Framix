import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// Where the export is, as the engine reports it.
sealed class ExportState {
  const ExportState();
}

/// No export has run (or the last one was dismissed).
final class ExportIdle extends ExportState {
  const ExportIdle();
}

/// Rendering: [frame] of [frames] done. Right after the engine accepts the export both are 0
/// until its first progress, so never divide by [frames] without checking it.
final class ExportRunning extends ExportState {
  const ExportRunning(this.frame, this.frames);

  final int frame;
  final int frames;

  @override
  bool operator ==(Object other) =>
      other is ExportRunning && other.frame == frame && other.frames == frames;

  @override
  int get hashCode => Object.hash(frame, frames);
}

/// The file is complete.
final class ExportDone extends ExportState {
  const ExportDone();
}

/// Stopped by the user or the engine; the file was removed.
final class ExportCancelled extends ExportState {
  const ExportCancelled();
}

/// The engine refused or the export failed, with the engine's [reason] (never a path).
final class ExportFailed extends ExportState {
  const ExportFailed(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is ExportFailed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// The engine refused the export before it started: the file needs about [neededBytes] and
/// only [freeBytes] are free.
final class ExportNoSpace extends ExportState {
  const ExportNoSpace(this.neededBytes, this.freeBytes);

  final int neededBytes;
  final int freeBytes;

  @override
  bool operator ==(Object other) =>
      other is ExportNoSpace &&
      other.neededBytes == neededBytes &&
      other.freeBytes == freeBytes;

  @override
  int get hashCode => Object.hash(neededBytes, freeBytes);
}

/// Mirrors the engine's export. Sends ExportProject and CancelExport only.
class ExportCubit extends Cubit<ExportState> {
  ExportCubit(this._engine) : super(const ExportIdle()) {
    _events = _engine.events.listen((event) {
      final next = fromEvent(event);
      if (next != null) {
        _starting = null;
        return emit(next);
      }
      final starting = _starting;
      if (starting == null) return;
      // Only the reply to our own ExportProject.
      if (event.hasCommandFailed() &&
          event.commandFailed.commandId.toInt() == starting) {
        _starting = null;
        emit(ExportFailed(event.commandFailed.reason));
      } else if (event.hasCommandAccepted() &&
          event.commandAccepted.commandId.toInt() == starting) {
        _starting = null;
        emit(const ExportRunning(0, 0));
      }
    });
  }

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;

  /// The id of the ExportProject waiting for its reply.
  int? _starting;

  /// The state an engine event moves the export to; null if the event is not about it.
  static ExportState? fromEvent(Event event) {
    if (event.hasExportProgress()) {
      final p = event.exportProgress;
      return ExportRunning(p.frame, p.frames);
    }
    if (!event.hasExportFinished()) return null;
    final f = event.exportFinished;
    if (f.ok) return const ExportDone();
    if (f.cancelled) return const ExportCancelled();
    if (f.neededBytes > 0) {
      return ExportNoSpace(f.neededBytes.toInt(), f.freeBytes.toInt());
    }
    return ExportFailed(f.reason);
  }

  /// Exports the project to [path] (an .mp4 file). Ignored while an export runs.
  void start(String path) {
    if (state is ExportRunning) return;
    // A retry that fails the same way is a new state again, so it is reported again.
    emit(const ExportIdle());
    // Only once it was sent: a send that throws must not leave a start waiting for a reply.
    _starting = _engine.send(
      Command(exportProject: ExportProject(path: path)),
      reportsFailure: true,
    );
  }

  /// Stops the running export; the engine refuses it when none runs.
  void cancel() => _engine.send(Command(cancelExport: CancelExport()));

  @override
  Future<void> close() async {
    await _events.cancel();
    return super.close();
  }
}
