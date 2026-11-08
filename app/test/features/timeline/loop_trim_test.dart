import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// P1-101: after a looped clip is trimmed, the ruler band shows the loop range the engine
/// reports, wherever that is.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('trimming a looped clip keeps the band on the engine loop', (
    tester,
  ) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(4000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
    TimelineChanged state() =>
        tester.element(find.byType(TimelinePage)).read<TimelineCubit>().state;

    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(tester, find.byKey(TimelineView.loopKey));
    final before = state().tracks.first.clips.first.duration;

    // Playhead into the clip, then trim its end there.
    final box = tester.getRect(find.byType(ClipBox));
    await tester.tapAt(
      Offset(
        box.left + box.width / 2,
        tester.getCenter(find.byKey(TimelineView.rulerKey)).dy,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.trimEndToPlayhead));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (_) => state().tracks.first.clips.first.duration < before,
      ),
    );
    await tester.pump();

    final loop = state();
    expect(loop.loopEnd, greaterThan(loop.loopStart), reason: 'still looping');
    final pps = tester
        .element(find.byType(TimelineView))
        .read<TimelineZoomCubit>()
        .state;
    double px(Int64 ticks) => ticks.toInt() / loop.ticksPerSecond.toInt() * pps;
    final ruler = tester.getRect(find.byKey(TimelineView.rulerKey));
    final band = tester.getRect(find.byKey(TimelineView.loopKey));
    expect(
      band.left,
      moreOrLessEquals(ruler.left + px(loop.loopStart), epsilon: 1),
    );
    expect(
      band.right,
      moreOrLessEquals(ruler.left + px(loop.loopEnd), epsilon: 1),
    );
  });
}
