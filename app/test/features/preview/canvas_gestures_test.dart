import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/preview/view/canvas_gestures.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Records placements instead of sending them; `seed` sets the mirrored timeline.
class RecordingTimeline extends TimelineCubit {
  RecordingTimeline(super.engine);

  final placed = <({int x, int y, int scale, int gesture})>[];

  void seed(TimelineChanged t) => emit(t..freeze());

  @override
  void placeClip(
    Clip clip, {
    required int x,
    required int y,
    required int scale,
    required int gesture,
  }) => placed.add((x: x, y: y, scale: scale, gesture: gesture));
}

TimelineChanged timeline({int x = 0, int scale = 1000, int active = 5}) =>
    TimelineChanged(
      tracks: [
        Track(
          id: Int64(1),
          kind: TrackKind.TRACK_KIND_VIDEO,
          number: 1,
          clips: [
            Clip(
              id: Int64(5),
              mediaId: Int64(2),
              duration: Int64(1000),
              mediaKind: MediaKind.MEDIA_KIND_IMAGE,
              x: x,
              scale: scale,
            ),
          ],
        ),
      ],
      aspectWidth: 16,
      aspectHeight: 9,
      activeClip: Int64(active),
    );

void main() {
  late FramixEngine engine;
  late RecordingTimeline cubit;

  setUp(() {
    engine = FramixEngine.create();
    cubit = RecordingTimeline(engine);
  });
  tearDown(() async {
    await cubit.close();
    engine.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: framixDarkTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<TimelineCubit>.value(
        value: cubit,
        child: const Center(
          child: SizedBox(width: 400, height: 225, child: CanvasGestures()),
        ),
      ),
    ),
  );

  testWidgets('a drag moves the active clip in canvas units, one gesture', (
    tester,
  ) async {
    cubit.seed(timeline());
    await pump(tester);
    await tester.drag(find.byType(CanvasGestures), const Offset(100, 0));
    await tester.pump();
    expect(cubit.placed, isNotEmpty);
    // 100 px of a 400 px wide canvas is a quarter: 2500 units.
    expect(cubit.placed.last.x, closeTo(2500, 50));
    expect(cubit.placed.last.scale, 1000);
    expect(cubit.placed.map((p) => p.gesture).toSet(), hasLength(1));
    expect(cubit.placed.first.gesture, isNot(0));
  });

  testWidgets('the outline follows the clip position and scale', (
    tester,
  ) async {
    cubit.seed(timeline(x: 2500, scale: 500));
    await pump(tester);
    final box = tester.getRect(find.byKey(CanvasGestures.outlineKey));
    final canvas = tester.getRect(find.byType(CanvasGestures));
    expect(box.width, closeTo(canvas.width / 2, 1));
    expect(box.center.dx, closeTo(canvas.center.dx + canvas.width / 4, 1));
  });

  testWidgets('without an active clip nothing is placed or outlined', (
    tester,
  ) async {
    cubit.seed(timeline(active: 0));
    await pump(tester);
    await tester.drag(find.byType(CanvasGestures), const Offset(100, 0));
    await tester.pump();
    expect(cubit.placed, isEmpty);
    expect(find.byKey(CanvasGestures.outlineKey), findsNothing);
  });
}
