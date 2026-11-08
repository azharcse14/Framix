import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// The loop on the ruler (P1-099): the looped range shows on the ruler even after its clip is
/// deleted, and a Clear loop control ends it.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
      'a loop left on a deleted clip shows on the ruler and clears (${locale.languageCode})',
      (tester) async {
        final l10n = lookupAppLocalizations(locale);
        await tester.pumpWidget(
          FramixApp(
            engine: engine,
            mediaImporter: FakeImporter([
              MediaItem(
                uri: 'content://media/external/video/1',
                kind: MediaKind.MEDIA_KIND_VIDEO,
                durationValue: Int64(2000),
                durationTimescale: 1000,
                width: 1080,
                height: 1920,
                codec: 'avc1',
              ),
            ]),
            locale: locale,
          ),
        );
        await tester.tap(find.byTooltip(l10n.importFromGallery));
        await pumpUntil(tester, find.text(l10n.clipCount(1)));
        TimelineChanged state() => tester
            .element(find.byType(TimelinePage))
            .read<TimelineCubit>()
            .state;

        expect(find.byKey(TimelineView.loopKey), findsNothing);
        expect(find.byTooltip(l10n.clearLoop), findsNothing);

        await tester.tap(find.byType(ClipBox));
        await tester.pump();
        final box = tester.getRect(find.byType(ClipBox));
        await tester.tap(find.byTooltip(l10n.loopClip));
        await pumpUntil(tester, find.byKey(TimelineView.loopKey));
        final band = tester.getRect(find.byKey(TimelineView.loopKey));
        expect(band.left, moreOrLessEquals(box.left, epsilon: 1));
        expect(band.right, moreOrLessEquals(box.right, epsilon: 1));

        await tester.tap(find.byTooltip(l10n.deleteClip));
        await pumpUntil(tester, find.text(l10n.clipCount(0)));
        expect(state().loopEnd, isNot(Int64.ZERO), reason: 'the engine kept it');
        expect(
          find.byKey(TimelineView.loopKey),
          findsOneWidget,
          reason: 'a loop on a deleted clip stays visible',
        );

        await tester.tap(find.byTooltip(l10n.clearLoop));
        await pumpUntil(
          tester,
          find.byWidgetPredicate((_) => state().loopEnd == 0),
        );
        await tester.pump();
        expect(find.byKey(TimelineView.loopKey), findsNothing);
        expect(find.byTooltip(l10n.clearLoop), findsNothing);
      },
    );
  }
}
