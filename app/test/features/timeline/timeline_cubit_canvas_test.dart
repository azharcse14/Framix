import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';

const second = 705600000;

void main() {
  late FramixEngine engine;
  late TimelineCubit cubit;

  Future<TimelineChanged> next(bool Function(TimelineChanged) test) =>
      cubit.stream.firstWhere(test).timeout(const Duration(seconds: 5));

  setUp(() async {
    engine = FramixEngine.create();
    cubit = TimelineCubit(engine);
    final imported = next((t) => t.tracks.isNotEmpty);
    engine.send(
      Command(
        importMedia: ImportMedia(
          items: [
            MediaItem(
              uri: 'content://media/external/images/1',
              kind: MediaKind.MEDIA_KIND_IMAGE,
              width: 1080,
              height: 1920,
            ),
          ],
        ),
      ),
    );
    await imported;
  });

  tearDown(() async {
    await cubit.close();
    engine.dispose();
  });

  test('a seek updates the active clip in the mirror', () async {
    final clip = cubit.state.tracks.first.clips.first.id;
    expect(cubit.state.activeClip, clip);
    // Past the 3 s photo: nothing under the playhead.
    final gone = next((t) => t.activeClip == 0);
    engine.send(Command(seek: Seek(time: Int64(60 * second))));
    await gone;
  });

  test(
    'placements in one turn send once, the latest, keeping the clip look',
    () async {
      final clip = cubit.state.tracks.first.clips.first;
      final rotated = next((t) => t.tracks.first.clips.first.rotation == 90);
      engine.send(
        Command(
          setClipTransform: SetClipTransform(clipId: clip.id, rotation: 90),
        ),
      );
      final turned = (await rotated).tracks.first.clips.first;
      var replies = 0;
      final counting = engine.events
          .where((e) => e.hasTimelineChanged())
          .listen((_) => replies++);
      final placed = next((t) => t.tracks.first.clips.first.x == 300);
      cubit
        ..placeClip(turned, x: 100, y: 0, scale: 1000, gesture: 1)
        ..placeClip(turned, x: 300, y: 0, scale: 1200, gesture: 1);
      final c = (await placed).tracks.first.clips.first;
      expect((c.x, c.scale, c.rotation), (300, 1200, 90));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(replies, 1);
      await counting.cancel();
    },
  );
}
