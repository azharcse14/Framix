import 'package:fixnum/fixnum.dart';
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

import 'follow_playhead_test.dart' show SetPlayback, SetPlayhead, second;

/// P1-097 review: the playhead is in the lanes' visible part (bounded on both sides by the
/// horizontal scroll view, which does not move), including after a play from the end jumps back
/// to the start, and when the view appears while already playing.
void main() {
  late FramixEngine engine;
  late SetPlayhead playhead;
  late SetPlayback playback;

  setUp(() {
    engine = FramixEngine.create();
    playhead = SetPlayhead(engine);
    playback = SetPlayback(engine);
  });
  tearDown(() async {
    await playhead.close();
    await playback.close();
    engine.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: framixDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => TimelineCubit(engine)),
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
                  clips: [
                    Clip(
                      id: Int64(1),
                      mediaId: Int64(7),
                      duration: Int64(120 * second),
                      mediaKind: MediaKind.MEDIA_KIND_VIDEO,
                    ),
                  ],
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

  /// The horizontal scroll view: the lanes' window, which stays put while they scroll.
  Finder lanes() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );

  bool inView(WidgetTester tester) {
    final line = tester.getRect(find.byKey(TimelineView.playheadKey)).center;
    final window = tester.getRect(lanes());
    return line.dx >= window.left && line.dx <= window.right;
  }

  Future<void> moveTo(WidgetTester tester, int seconds) async {
    playhead.at(seconds * second);
    await tester.pumpAndSettle();
  }

  testWidgets('each followed step keeps the playhead between both edges', (
    tester,
  ) async {
    await pump(tester);
    playback.set(true);
    await tester.pump();
    for (final s in [10, 30, 60, 100, 119]) {
      await moveTo(tester, s);
      expect(inView(tester), isTrue, reason: 'at $s s');
    }
  });

  testWidgets('a play from the end follows the playhead back to the start', (
    tester,
  ) async {
    await pump(tester);
    playback.set(true);
    await tester.pump();
    await moveTo(tester, 120);
    expect(inView(tester), isTrue);
    // The engine restarts a play from the end at 0.
    playback.set(false);
    await tester.pump();
    playback.set(true);
    await tester.pump();
    await moveTo(tester, 0);
    expect(inView(tester), isTrue);
  });

  testWidgets('a view that appears while playing follows at once', (
    tester,
  ) async {
    playback.set(true);
    await pump(tester);
    await moveTo(tester, 100);
    expect(inView(tester), isTrue);
  });
}
