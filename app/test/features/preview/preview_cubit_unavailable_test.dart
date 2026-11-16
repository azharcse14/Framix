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

Event _failed(int commandId, [FailureKind? kind]) => Event(
  commandFailed: CommandFailed(
    reason: 'no preview on this platform',
    commandId: Int64(commandId),
    kind: kind,
  ),
);

/// UX-035: a refused CreatePreview, or one that fails after it was accepted, makes the
/// preview unavailable; other failures leave it alone.
void main() {
  late _FakeEngine engine;
  late PreviewCubit cubit;

  setUp(() {
    engine = _FakeEngine();
    cubit = PreviewCubit(engine);
  });
  tearDown(() => cubit.close());

  test('a refused CreatePreview makes the preview unavailable', () async {
    await engine.emit(_failed(1));
    expect(cubit.state, const PreviewUnavailable());
  });

  test(
    'a preview failure after CreatePreview was accepted makes it unavailable',
    () async {
      await engine.emit(
        Event(commandAccepted: CommandAccepted(commandId: Int64(1))),
      );
      await engine.emit(_failed(0, FailureKind.FAILURE_KIND_PREVIEW));
      expect(cubit.state, const PreviewUnavailable());
    },
  );

  test(
    'a new preview after a loss that is refused makes it unavailable',
    () async {
      await engine.emit(Event(previewReady: PreviewReady(textureId: Int64(7))));
      await engine.emit(Event(previewLost: PreviewLost(textureId: Int64(7))));
      expect(engine.sent, hasLength(2));
      await engine.emit(_failed(2));
      expect(cubit.state, const PreviewUnavailable());
    },
  );

  test('other failures leave the preview alone', () async {
    await engine.emit(Event(previewReady: PreviewReady(textureId: Int64(7))));
    await engine.emit(_failed(5));
    await engine.emit(_failed(0, FailureKind.FAILURE_KIND_AUTOSAVE));
    await engine.emit(_failed(0));
    expect(cubit.state, const PreviewShown(7));
  });
}
