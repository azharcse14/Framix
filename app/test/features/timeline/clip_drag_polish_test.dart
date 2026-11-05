import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Records moves instead of sending them.
class RecordingMoves extends TimelineCubit {
  RecordingMoves(super.engine);

  final moves = <({int clip, int track, int start})>[];

  @override
  void moveClip(Clip clip, Int64 trackId, int start, {int snapWithin = 0}) =>
      moves.add((clip: clip.id.toInt(), track: trackId.toInt(), start: start));
}

const second = 705600000;
const pps = TimelineZoomCubit.initial;

Clip clip(int id, int seconds) => Clip(
  id: Int64(id),
  mediaId: Int64(id),
  duration: Int64(seconds * second),
  mediaKind: MediaKind.MEDIA_KIND_VIDEO,
);

/// P1-086: a dragged clip is drawn over every lane, and the timeline scrolls while it is held
/// near the edge of the view.
void main() {
  late FramixEngine engine;
  late RecordingMoves moves;

  setUp(() {
    engine = FramixEngine.create();
    moves = RecordingMoves(engine);
  });
  tearDown(() async {
    await moves.close();
    engine.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: framixDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineCubit>.value(value: moves),
          BlocProvider(create: (_) => PlayheadCubit(engine)),
          BlocProvider(create: (_) => PlaybackCubit(engine)),
          BlocProvider(create: (_) => TimelineZoomCubit()),
          BlocProvider(create: (_) => ThumbnailCubit(engine)),
        ],
        child: Scaffold(
          body: TimelineView(
            timeline: TimelineChanged(
              tracks: [
                Track(
                  id: Int64(1),
                  kind: TrackKind.TRACK_KIND_VIDEO,
                  number: 1,
                  clips: [clip(1, 2)],
                ),
                Track(
                  id: Int64(2),
                  kind: TrackKind.TRACK_KIND_VIDEO,
                  number: 2,
                  clips: [clip(2, 120)],
                ),
              ],
              duration: Int64(120 * second),
              ticksPerSecond: Int64(second),
              thumbnailStep: Int64(second),
            ),
          ),
        ),
      ),
    ),
  );

  /// The short clip on the first lane (2 s wide).
  Finder short() =>
      find.byWidgetPredicate((w) => w is ClipBox && w.width == 2 * pps);

  Finder lanes() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );

  Future<TestGesture> lift(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(short()));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    return gesture;
  }

  testWidgets('a clip dragged onto the next lane is drawn over its clips', (
    tester,
  ) async {
    await pump(tester);
    final lane = tester.getRect(short()).height + 16;
    final gesture = await lift(tester);
    await gesture.moveBy(Offset(10, lane));
    await tester.pump();
    // The dragged clip, not the long clip under it, is what shows (and is hit) there.
    expect(short().hitTestable(), findsOneWidget);
    await gesture.up();
    await tester.pump();
  });

  testWidgets(
    'held near the right edge, the timeline scrolls and the move counts it',
    (tester) async {
      await pump(tester);
      final window = tester.getRect(lanes());
      final from = tester.getCenter(short());
      final gesture = await lift(tester);
      final to = Offset(window.right - 4, from.dy);
      await gesture.moveTo(to);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrolled = tester.state<ScrollableState>(lanes()).position.pixels;
      expect(scrolled, greaterThan(0), reason: 'the timeline scrolled');
      await gesture.up();
      await tester.pump();
      expect(moves.moves, hasLength(1));
      final moved = (to.dx - from.dx + scrolled) / pps * second;
      expect(moves.moves.single.start, closeTo(moved, second / pps));
    },
  );

  testWidgets('a clip held away from the edges does not scroll the timeline', (
    tester,
  ) async {
    await pump(tester);
    final gesture = await lift(tester);
    await gesture.moveBy(const Offset(60, 0));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.state<ScrollableState>(lanes()).position.pixels, 0);
    await gesture.up();
    await tester.pump();
  });
}
