import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';

/// Records sent commands under ids 1, 2, ...; the test plays the engine's events.
class _FakeEngine implements FramixEngine {
  final sent = <Command>[];
  final _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    sent.add(command);
    return sent.length;
  }

  Future<void> emit(Event event) async {
    _events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// UX-035 review: a preview the engine reports after it was unavailable is shown.
void main() {
  test('PreviewReady after PreviewUnavailable shows the preview', () async {
    final engine = _FakeEngine();
    final cubit = PreviewCubit(engine);
    addTearDown(cubit.close);
    await engine.emit(
      Event(
        commandFailed: CommandFailed(
          commandId: Int64(0),
          kind: FailureKind.FAILURE_KIND_PREVIEW,
        ),
      ),
    );
    expect(cubit.state, const PreviewUnavailable());
    await engine.emit(Event(previewReady: PreviewReady(textureId: Int64(9))));
    expect(cubit.state, const PreviewShown(9));
  });
}
