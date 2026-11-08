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

/// Loop playback (P1-027): the selected clip's Loop button asks the engine to repeat its range;
/// tapped again it clears the loop.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
      'loop the selected clip, then clear it (${locale.languageCode})',
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

        await tester.tap(find.byType(ClipBox));
        await tester.pump();
        await tester.tap(find.byTooltip(l10n.loopClip));
        await pumpUntil(
          tester,
          find.byWidgetPredicate((_) => state().loopEnd != 0),
        );
        final clip = state().tracks.first.clips.first;
        expect(state().loopStart, clip.start);
        expect(state().loopEnd, clip.start + clip.duration);
        final button = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(l10n.loopClip),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.isSelected, isTrue, reason: 'shows that it loops');

        await tester.tap(find.byTooltip(l10n.loopClip));
        await pumpUntil(
          tester,
          find.byWidgetPredicate((_) => state().loopEnd == 0),
        );
        expect(state().loopStart, Int64.ZERO);
      },
    );
  }
}
