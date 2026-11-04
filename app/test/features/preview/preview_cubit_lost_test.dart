import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';

/// Records sent commands; the test plays the engine's events.
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

  void emit(Event event) => _events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P1-053: a preview lost on the GPU stops showing its texture and asks for a new one.
void main() {
  test(
    'PreviewLost clears the texture and sends CreatePreview again',
    () async {
      final engine = _FakeEngine();
      final cubit = PreviewCubit(engine);
      addTearDown(cubit.close);
      expect(engine.sent.where((c) => c.hasCreatePreview()), hasLength(1));

      engine.emit(Event(previewReady: PreviewReady(textureId: Int64(7))));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, 7);

      engine.emit(Event(previewLost: PreviewLost(textureId: Int64(7))));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isNull);
      expect(engine.sent.where((c) => c.hasCreatePreview()), hasLength(2));

      engine.emit(Event(previewReady: PreviewReady(textureId: Int64(8))));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, 8);
    },
  );
}
