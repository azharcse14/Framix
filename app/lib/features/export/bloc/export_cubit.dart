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

/// Rendering: [frame] of [frames] done.
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

/// Mirrors the engine's export. Sends ExportProject and CancelExport only.
class ExportCubit extends Cubit<ExportState> {
  ExportCubit(this._engine) : super(const ExportIdle());

  final FramixEngine _engine;

  /// The state an engine event moves the export to; null if the event is not about it.
  static ExportState? fromEvent(Event event) => null;

  /// Exports the project to [path] (an .mp4 file).
  void start(String path) {}

  /// Stops the running export.
  void cancel() {}
}
