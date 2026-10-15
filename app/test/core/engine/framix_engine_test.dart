import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';

Command _addVideoTrack() =>
    Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO));

void main() {
  test('a command comes back as an event', () async {
    final engine = FramixEngine.create();
    addTearDown(engine.dispose);
    final next = engine.events.first;
    engine.send(_addVideoTrack());
    final event = await next.timeout(const Duration(seconds: 5));
    expect(event.timelineChanged.tracks, hasLength(1));
  });

  test('commands are answered in order', () async {
    final engine = FramixEngine.create();
    addTearDown(engine.dispose);
    final three = engine.events.take(3).toList();
    for (var i = 0; i < 3; i++) {
      engine.send(_addVideoTrack());
    }
    final events = await three.timeout(const Duration(seconds: 5));
    expect(events.map((e) => e.timelineChanged.tracks.length), [1, 2, 3]);
  });

  test('a rejected command reports failure', () async {
    final engine = FramixEngine.create();
    addTearDown(engine.dispose);
    final next = engine.events.first;
    engine.send(Command(undo: Undo()));
    final event = await next.timeout(const Duration(seconds: 5));
    expect(event.hasCommandFailed(), isTrue);
  });

  test('dispose closes the event stream', () async {
    final engine = FramixEngine.create();
    final done = engine.events.toList();
    engine.dispose();
    expect(await done.timeout(const Duration(seconds: 5)), isEmpty);
  });
}
