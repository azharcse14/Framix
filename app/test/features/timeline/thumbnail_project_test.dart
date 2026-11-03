import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';

MediaItem _video() => MediaItem(
  uri: 'content://media/external/video/1',
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(4000),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

/// P1-062: a new project starts the thumbnail cubit over (media ids restart in the engine).
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<int> importOne() async {
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(Command(importMedia: ImportMedia(items: [_video()])));
    return (await imported).timelineChanged.tracks.first.clips.first.mediaId
        .toInt();
  }

  test('after a new project the same ask goes out again', () async {
    final cubit = ThumbnailCubit(engine);
    // The host engine has no platform, so each request that goes out fails.
    var replies = 0;
    final counting = engine.events
        .where((e) => e.hasCommandFailed())
        .listen((_) => replies++);

    final media = await importOne();
    cubit.request(media, [0], 96);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(replies, 1);

    final fresh = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(Command(newProject: NewProject()));
    await fresh;
    final again = await importOne();
    expect(again, media, reason: 'ids restart, so the old key would match');
    cubit.request(again, [0], 96);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(replies, 2);

    await counting.cancel();
    await cubit.close();
  });
}
