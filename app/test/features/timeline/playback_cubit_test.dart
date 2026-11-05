import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';

/// P1-061: the engine plays; the cubit mirrors whether it does.
void main() {
  late FramixEngine engine;
  late PlaybackCubit playback;
  late PlayheadCubit playhead;

  Future<void> importVideo(int ms) async {
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(
      Command(
        importMedia: ImportMedia(
          items: [
            MediaItem(
              uri: 'content://media/external/video/1',
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
  }

  setUp(() {
    engine = FramixEngine.create();
    playback = PlaybackCubit(engine);
    playhead = PlayheadCubit(engine);
  });

  tearDown(() async {
    await playback.close();
    await playhead.close();
    engine.dispose();
  });

  Future<bool> playingBecomes(bool playing) => playback.stream
      .firstWhere((p) => p == playing)
      .timeout(const Duration(seconds: 5));

  test('play moves the playhead until pause', () async {
    await importVideo(4000);
    playback.play();
    expect(await playingBecomes(true), isTrue);
    await playhead.stream
        .firstWhere((t) => t > 0)
        .timeout(const Duration(seconds: 5));
    playback.pause();
    expect(await playingBecomes(false), isFalse);
  });

  test('playback stops by itself at the end', () async {
    await importVideo(300);
    playback.play();
    expect(await playingBecomes(true), isTrue);
    expect(await playingBecomes(false), isFalse);
  });

  test('a new project stops playback', () async {
    await importVideo(4000);
    playback.play();
    expect(await playingBecomes(true), isTrue);
    engine.send(Command(newProject: NewProject()));
    expect(await playingBecomes(false), isFalse);
  });
}
