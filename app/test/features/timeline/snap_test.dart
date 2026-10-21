import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';

const second = 705600000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FramixEngine engine;
  late PlayheadCubit cubit;
  late List<MethodCall> haptics;

  setUp(() async {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
    engine = FramixEngine.create();
    cubit = PlayheadCubit(engine);
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    // Two videos back to back: [0, 2 s) and [2 s, 5 s).
    engine.send(
      Command(
        importMedia: ImportMedia(
          items: [
            for (final (i, ms) in [(1, 2000), (2, 3000)])
              MediaItem(
                uri: 'content://media/external/video/$i',
                kind: MediaKind.MEDIA_KIND_VIDEO,
                durationValue: Int64(ms),
                durationTimescale: 1000,
                width: 1080,
                height: 1920,
                codec: 'avc1',
              ),
          ],
        ),
      ),
    );
    await imported.timeout(const Duration(seconds: 5));
  });

  tearDown(() async {
    await cubit.close();
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Seeks and waits for the engine's answer (the cubit does not re-emit an equal state).
  Future<void> seekAndWait(int ticks, int snapWithin, int expected) async {
    final landed = engine.events.firstWhere((e) => e.hasPlayheadChanged());
    cubit.seek(ticks, snapWithin: snapWithin);
    expect(
      (await landed.timeout(const Duration(seconds: 5))).playheadChanged.time
          .toInt(),
      expected,
    );
    // Let the cubit handle the same event and the haptic call reach the mock.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('a scrub near an edge snaps to it with one haptic tick', () async {
    const radius = second ~/ 10;
    await seekAndWait(2 * second + second ~/ 20, radius, 2 * second);
    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');

    // Staying on the same snap point does not tick again.
    await seekAndWait(2 * second - second ~/ 30, radius, 2 * second);
    // A seek elsewhere repeats the snap point's leave; this one does not snap.
    await seekAndWait(3 * second, radius, 3 * second);
    expect(haptics, hasLength(1));

    // Coming back to an edge ticks again.
    await seekAndWait(5 * second - second ~/ 40, radius, 5 * second);
    expect(haptics, hasLength(2));
  });
}
