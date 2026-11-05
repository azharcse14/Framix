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

/// The playhead set by the test instead of the engine.
class SetPlayhead extends PlayheadCubit {
  SetPlayhead(super.engine);
  void at(int ticks) => emit(ticks);
}

/// Playing set by the test instead of the engine.
class SetPlayback extends PlaybackCubit {
  SetPlayback(super.engine);
  void set(bool playing) => emit(playing);
}

const second = 705600000;

/// P1-097: while playing, the timeline scrolls so the playhead stays in view, until the user
/// scrolls it themselves.
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

  /// Whether the playhead line is on screen, inside the lanes (right of the headers).
  bool inView(WidgetTester tester) {
    final line = tester.getRect(find.byKey(TimelineView.playheadKey));
    final ruler = tester.getRect(find.byKey(TimelineView.rulerKey));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    return line.center.dx >= ruler.left && line.center.dx <= screen.width;
  }

  Future<void> moveTo(WidgetTester tester, int seconds) async {
    playhead.at(seconds * second);
    await tester.pumpAndSettle();
  }

  testWidgets('while playing the playhead stays in view', (tester) async {
    await pump(tester);
    playback.set(true);
    await tester.pump();
    for (final s in [10, 30, 60, 100]) {
      await moveTo(tester, s);
      expect(inView(tester), isTrue, reason: 'at $s s');
    }
  });

  testWidgets('a paused playhead moved off screen is not followed', (
    tester,
  ) async {
    await pump(tester);
    await moveTo(tester, 100);
    expect(inView(tester), isFalse);
  });

  testWidgets('scrolling while playing stops following until the next play', (
    tester,
  ) async {
    await pump(tester);
    playback.set(true);
    await tester.pump();
    await moveTo(tester, 5);
    // The user drags the lanes; the playhead goes on without them.
    await tester.flingFrom(
      tester.getTopLeft(find.byType(ClipBox)) + const Offset(20, 20),
      const Offset(-200, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await moveTo(tester, 100);
    expect(inView(tester), isFalse, reason: 'the user scrolled away');

    playback.set(false);
    await tester.pump();
    playback.set(true);
    await tester.pump();
    await moveTo(tester, 110);
    expect(inView(tester), isTrue, reason: 'a new play follows again');
  });
}
