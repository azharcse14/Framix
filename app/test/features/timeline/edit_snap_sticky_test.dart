import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';

const second = 705600000;

MediaItem _video(int n) => MediaItem(
  uri: 'content://media/external/video/$n',
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(2000),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

/// P1-085 review: the snapped flag answers one edit; the mirrored timeline never keeps it,
/// so a later playhead move into another clip does not tick again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FramixEngine engine;
  late TimelineCubit cubit;
  late List<MethodCall> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
    engine = FramixEngine.create();
    cubit = TimelineCubit(engine);
  });
  tearDown(() async {
    await cubit.close();
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Sends [send] and waits until [done] holds for the cubit's state (at most 2 s).
  Future<void> until(
    void Function() send,
    bool Function(TimelineChanged) done,
  ) async {
    send();
    for (var i = 0; i < 100 && !done(cubit.state); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(done(cubit.state), isTrue);
    // Let a haptic call that the same event caused reach the mock.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test(
    'a seek into another clip after a snapping trim does not tick',
    () async {
      await until(
        () => engine.send(
          Command(importMedia: ImportMedia(items: [_video(1), _video(2)])),
        ),
        (t) => t.tracks.isNotEmpty,
      );
      final track = cubit.state.tracks[0];
      final (a, b) = (track.clips[0], track.clips[1]);
      await until(
        () => cubit.moveClip(b, track.id, 4 * second),
        (t) => t.tracks[0].clips[1].start.toInt() == 4 * second,
      );
      await until(
        () =>
            cubit.trimClip(a, 0, 395 * second ~/ 100, snapWithin: second ~/ 10),
        (t) => t.tracks[0].clips[0].duration.toInt() == 4 * second,
      );
      expect(haptics, hasLength(1));

      await until(
        () => engine.send(Command(seek: Seek(time: Int64(5 * second)))),
        (t) => t.activeClip == b.id,
      );
      expect(haptics, hasLength(1));
      expect(cubit.state.snapped, isFalse);
    },
  );
}
