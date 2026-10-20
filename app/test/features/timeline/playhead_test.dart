import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';

/// 705,600,000 ticks per second (engine core::time); the engine also reports it.
const second = 705600000;

void main() {
  late FramixEngine engine;
  late PlayheadCubit cubit;

  setUp(() async {
    engine = FramixEngine.create();
    cubit = PlayheadCubit(engine);
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(
      Command(
        importMedia: ImportMedia(
          items: [
            MediaItem(
              uri: 'content://media/external/video/1',
              kind: MediaKind.MEDIA_KIND_VIDEO,
              durationValue: Int64(4000),
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
  });

  Future<int> playheadBecomes(int ticks) => cubit.stream
      .firstWhere((t) => t == ticks)
      .timeout(const Duration(seconds: 5));

  test(
    'seek moves the playhead; the engine clamps it to the timeline',
    () async {
      cubit.seek(second);
      expect(await playheadBecomes(second), second);
      cubit.seek(100 * second);
      expect(await playheadBecomes(4 * second), 4 * second);
    },
  );

  test('quick seeks are coalesced into one, ending at the last', () async {
    var replies = 0;
    final counting = engine.events
        .where((e) => e.hasPlayheadChanged())
        .listen((_) => replies++);
    cubit
      ..seek(second)
      ..seek(2 * second)
      ..seek(3 * second);
    expect(await playheadBecomes(3 * second), 3 * second);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(replies, 1);
    await counting.cancel();
  });
}
