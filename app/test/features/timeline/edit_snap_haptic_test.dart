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

/// P1-085: a trim or move that snaps gives one haptic tick, like a snapping scrub.
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

  /// The TimelineChanged that answers [send] (the cubit's own GetTimeline answer has no tracks).
  Future<TimelineChanged> next(void Function() send) async {
    final changed = engine.events.firstWhere(
      (e) => e.hasTimelineChanged() && e.timelineChanged.tracks.isNotEmpty,
    );
    send();
    final t = (await changed).timelineChanged;
    // Let the cubit handle the same event and the haptic call reach the mock.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return t;
  }

  test('a trim that snaps ticks once; one that does not, never', () async {
    final t = await next(
      () => engine.send(
        Command(importMedia: ImportMedia(items: [_video(1), _video(2)])),
      ),
    );
    final track = t.tracks[0];
    final (a, b) = (track.clips[0], track.clips[1]);
    await next(() => cubit.moveClip(b, track.id, 4 * second));
    expect(haptics, isEmpty);

    await next(
      () => cubit.trimClip(a, 0, 395 * second ~/ 100, snapWithin: second ~/ 10),
    );
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');

    await next(() => cubit.trimClip(a, 0, second, snapWithin: second ~/ 10));
    expect(haptics, hasLength(1));
  });
}
