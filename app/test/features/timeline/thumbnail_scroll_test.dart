import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Records which times the view asks for, instead of sending them.
class RecordingThumbnails extends ThumbnailCubit {
  RecordingThumbnails(super.engine);

  final asked = <int>{};

  @override
  void request(int media, List<int> times, int maxSide) => asked.addAll(times);
}

const second = 705600000;

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('scrolling a long clip asks for the newly shown times', (
    tester,
  ) async {
    final thumbnails = RecordingThumbnails(engine);
    // One 120 s video clip at the default zoom: far wider than the screen.
    final timeline = TimelineChanged(
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
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => TimelineCubit(engine)),
            BlocProvider(create: (_) => PlayheadCubit(engine)),
            BlocProvider(create: (_) => TimelineZoomCubit()),
            BlocProvider<ThumbnailCubit>.value(value: thumbnails),
          ],
          child: Scaffold(body: TimelineView(timeline: timeline)),
        ),
      ),
    );
    final before = Set.of(thumbnails.asked);
    expect(before, isNotEmpty);

    final start =
        tester.getTopLeft(find.byType(ClipBox)) + const Offset(20, 20);
    await tester.dragFrom(start, const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(thumbnails.asked.difference(before), isNotEmpty);
    // Every slot on screen asked for the time it shows, including reused slots.
    final shown = tester
        .widgetList<ThumbnailTile>(find.byType(ThumbnailTile))
        .map((t) => t.time)
        .toSet();
    expect(thumbnails.asked, containsAll(shown));
  });
}
