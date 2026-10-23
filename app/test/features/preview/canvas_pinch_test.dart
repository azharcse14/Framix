import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/preview/view/canvas_gestures.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'canvas_gestures_test.dart' show RecordingTimeline, timeline;

void main() {
  testWidgets(
    'a pinch spreading the fingers to twice the gap doubles the scale',
    (tester) async {
      final engine = FramixEngine.create();
      final cubit = RecordingTimeline(engine)..seed(timeline());
      // Not in the body: closing the cubit cancels the engine's event stream, which
      // completes on the real event loop, so awaiting it under fake async never returns.
      addTearDown(() async {
        await cubit.close();
        engine.dispose();
      });
      await tester.pumpWidget(
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
      final centre = tester.getCenter(find.byType(CanvasGestures));
      final a = await tester.startGesture(
        centre - const Offset(40, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        centre + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var i = 1; i <= 4; i++) {
        await a.moveTo(centre - Offset(40.0 + 10 * i, 0));
        await b.moveTo(centre + Offset(40.0 + 10 * i, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      expect(cubit.placed.last.scale, closeTo(2000, 20));
      // A symmetric pinch does not move it.
      expect(cubit.placed.last.x, closeTo(0, 20));
    },
  );

  testWidgets('a second finger landing mid-drag does not move the clip', (
    tester,
  ) async {
    final engine = FramixEngine.create();
    final cubit = RecordingTimeline(engine)..seed(timeline());
    addTearDown(() async {
      await cubit.close();
      engine.dispose();
    });
    await tester.pumpWidget(
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
    final centre = tester.getCenter(find.byType(CanvasGestures));
    final a = await tester.startGesture(centre, pointer: 1);
    for (var i = 1; i <= 6; i++) {
      await a.moveTo(centre + Offset(10.0 * i, 0));
      await tester.pump();
    }
    final dragged = cubit.placed.last.x;
    // The focal point jumps 40 px right when the second finger lands.
    final b = await tester.startGesture(
      centre + const Offset(140, 0),
      pointer: 2,
    );
    await tester.pump();
    await b.moveTo(centre + const Offset(140, 1));
    await tester.pump();
    await a.up();
    await b.up();
    expect(cubit.placed.last.x, closeTo(dragged, 50));
  });

  testWidgets('after a pinch, the next drag is a new gesture from the mirror', (
    tester,
  ) async {
    final engine = FramixEngine.create();
    final cubit = RecordingTimeline(engine)..seed(timeline());
    addTearDown(() async {
      await cubit.close();
      engine.dispose();
    });
    await tester.pumpWidget(
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
    final centre = tester.getCenter(find.byType(CanvasGestures));
    final a = await tester.startGesture(
      centre - const Offset(40, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      centre + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    for (var i = 1; i <= 4; i++) {
      await a.moveTo(centre - Offset(40.0 + 10 * i, 0));
      await b.moveTo(centre + Offset(40.0 + 10 * i, 0));
      await tester.pump();
    }
    // Both lift with no move between: the recognizer reports no final end.
    await a.up();
    await b.up();
    await tester.pump();
    final pinch = cubit.placed.last.gesture;
    await tester.drag(find.byType(CanvasGestures), const Offset(100, 0));
    await tester.pump();
    expect(cubit.placed.last.gesture, isNot(pinch));
    // The mirror still says scale 1000: the drag starts from it, not the pinch.
    expect(cubit.placed.last.scale, 1000);
  });
}
