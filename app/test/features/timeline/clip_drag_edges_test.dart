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

import 'clip_drag_polish_test.dart' show RecordingMoves, clip, pps, second;
import 'follow_playhead_test.dart' show SetPlayback, SetPlayhead;

/// P1-086 review: the left edge scrolls back, a clip held still in an edge zone does not scroll,
/// dragging to the edge while playing is not undone by following the playhead, and a clip
/// narrower than its touch target is drawn while dragged.
void main() {
  late FramixEngine engine;
  late RecordingMoves moves;
  late SetPlayhead playhead;
  late SetPlayback playback;

  setUp(() {
    engine = FramixEngine.create();
    moves = RecordingMoves(engine);
    playhead = SetPlayhead(engine);
    playback = SetPlayback(engine);
  });
  tearDown(() async {
    await moves.close();
    await playhead.close();
    await playback.close();
    engine.dispose();
  });

  /// Lane 1: a 0.3 s clip (30 dp, narrower than its 48 dp target); lane 2: a 120 s clip.
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: framixDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineCubit>.value(value: moves),
          BlocProvider<PlayheadCubit>.value(value: playhead),
          BlocProvider<PlaybackCubit>.value(value: playback),
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
                  clips: [clip(1, 1)..duration = Int64(3 * second ~/ 10)],
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

  Finder lanes() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );
  Finder long() =>
      find.byWidgetPredicate((w) => w is ClipBox && w.width == 120 * pps);
  Finder narrow() =>
      find.byWidgetPredicate((w) => w is ClipBox && (w.width - 30).abs() < 1);
  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(lanes()).position;

  Future<TestGesture> lift(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(at);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    return gesture;
  }

  Future<void> hold(WidgetTester tester, [int frames = 60]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('held near the left edge, the timeline scrolls back', (
    tester,
  ) async {
    await pump(tester);
    position(tester).jumpTo(2000);
    await tester.pump();
    final window = tester.getRect(lanes());
    final from = Offset(window.center.dx, tester.getCenter(long()).dy);
    final gesture = await lift(tester, from);
    final to = Offset(window.left + 4, from.dy);
    await gesture.moveTo(to);
    await hold(tester);
    final scrolled = position(tester).pixels - 2000;
    expect(scrolled, lessThan(0));
    await gesture.up();
    await tester.pump();
    final moved = (to.dx - from.dx + scrolled) / pps * second;
    expect(moves.moves.single.start, closeTo(moved, second / pps));
  });

  testWidgets(
    'a clip lifted inside an edge zone and held still does not scroll',
    (tester) async {
      await pump(tester);
      final window = tester.getRect(lanes());
      final gesture = await lift(
        tester,
        Offset(window.right - 10, tester.getCenter(long()).dy),
      );
      await hold(tester);
      expect(position(tester).pixels, 0);
      await gesture.up();
      await tester.pump();
    },
  );

  testWidgets(
    'dragging to the edge while playing is not pulled back to the playhead',
    (tester) async {
      await pump(tester);
      playback.set(true);
      await tester.pump();
      final window = tester.getRect(lanes());
      final from = Offset(window.center.dx, tester.getCenter(long()).dy);
      final gesture = await lift(tester, from);
      await gesture.moveTo(Offset(window.right - 4, from.dy));
      for (var i = 0; i < 60; i++) {
        // Playback goes on at the start of the timeline.
        playhead.at(i * second ~/ 30);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position(tester).pixels, greaterThan(window.width));
      await gesture.up();
      await tester.pump();
    },
  );

  testWidgets('a clip narrower than its touch target is drawn at the finger', (
    tester,
  ) async {
    await pump(tester);
    final before = tester.getRect(narrow());
    final gesture = await lift(tester, before.center);
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    final shown = tester
        .widgetList<ClipBox>(narrow())
        .map((w) => tester.getRect(find.byWidget(w)).left);
    expect(shown, contains(closeTo(before.left + 60, 1)));
    await gesture.up();
    await tester.pump();
  });
}
