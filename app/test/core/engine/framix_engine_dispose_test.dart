import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';

void main() {
  test('dispose completes the stream even with commands in flight', () async {
    final engine = FramixEngine.create();
    final done = engine.events.toList();
    engine.send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)));
    engine.dispose();
    await done.timeout(const Duration(seconds: 5));
  });

  test('send after dispose throws instead of touching freed memory', () {
    final engine = FramixEngine.create()..dispose();
    expect(
      () => engine.send(Command(undo: Undo())),
      throwsA(isA<StateError>()),
    );
  });

  test('dispose twice is a no-op', () {
    final engine = FramixEngine.create()..dispose();
    expect(engine.dispose, returnsNormally);
  });
}
