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

import 'canvas_gestures_test.dart' show RecordingTimeline;

/// P1-063: the outline draws the frame the engine reports, not the canvas box times scale.
void main() {
  testWidgets('a wide picture on a tall canvas gets a short outline', (
    tester,
  ) async {
    final engine = FramixEngine.create();
    final cubit = RecordingTimeline(engine);
    addTearDown(() async {
      await cubit.close();
      engine.dispose();
    });
    cubit.seed(
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
                mediaKind: MediaKind.MEDIA_KIND_VIDEO,
                y: -2000,
                scale: 1000,
                frameWidth: 1,
                frameHeight: 81 / 256,
              ),
            ],
          ),
        ],
        aspectWidth: 9,
        aspectHeight: 16,
        activeClip: Int64(5),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TimelineCubit>.value(
          value: cubit,
          child: const Center(
            child: SizedBox(width: 225, height: 400, child: CanvasGestures()),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(CanvasGestures.outlineKey));
    final canvas = tester.getRect(find.byType(CanvasGestures));
    expect(box.width, closeTo(canvas.width, 1));
    expect(box.height, closeTo(canvas.height * 81 / 256, 1));
    expect(box.center.dy, closeTo(canvas.center.dy - canvas.height / 5, 1));
  });
}
