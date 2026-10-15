import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';

void main() {
  late FramixEngine engine;
  late TimelineCubit cubit;

  setUp(() {
    engine = FramixEngine.create();
    cubit = TimelineCubit(engine);
  });

  tearDown(() async {
    await cubit.close();
    engine.dispose();
  });

  Future<TimelineChanged> next() =>
      cubit.stream.first.timeout(const Duration(seconds: 5));

  test('starts with an empty timeline', () {
    expect(cubit.state.tracks, isEmpty);
    expect(cubit.state.canUndo, isFalse);
  });

  test('mirrors the engine through add, undo, and redo', () async {
    await next(); // the engine's starting state (GetTimeline reply), see P1-010
    cubit.addTrack(TrackKind.TRACK_KIND_AUDIO);
    var state = await next();
    expect(state.tracks.single.kind, TrackKind.TRACK_KIND_AUDIO);
    expect(state.canUndo, isTrue);

    cubit.undo();
    state = await next();
    expect(state.tracks, isEmpty);
    expect(state.canRedo, isTrue);

    cubit.redo();
    state = await next();
    expect(state.tracks, hasLength(1));
  });

  test('a cubit created after edits mirrors the existing timeline', () async {
    final first = next();
    cubit.addTrack(TrackKind.TRACK_KIND_VIDEO);
    await first;

    final late = TimelineCubit(engine);
    addTearDown(late.close);
    final state = await late.stream.first.timeout(const Duration(seconds: 5));
    expect(state.tracks.single.kind, TrackKind.TRACK_KIND_VIDEO);
    expect(state.canUndo, isTrue);
  });
}
