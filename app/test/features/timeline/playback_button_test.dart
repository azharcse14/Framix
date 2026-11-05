import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// P1-061: the play button plays, turns into pause, and the ruler pauses while scrubbing.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<AppLocalizations> importOneClip(
    WidgetTester tester,
    Locale locale,
  ) async {
    final l10n = lookupAppLocalizations(locale);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(10000),
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
    await pumpUntil(tester, find.byType(ClipBox));
    return l10n;
  }

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(done(), isTrue);
  }

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('play plays and pause stops ($locale)', (tester) async {
      final l10n = await importOneClip(tester, locale);
      int playhead() =>
          tester.element(find.byType(TimelinePage)).read<PlayheadCubit>().state;
      expect(find.byTooltip(l10n.pause), findsNothing);

      await tester.tap(find.byTooltip(l10n.play));
      await until(tester, () => playhead() > 0);
      await until(
        tester,
        () => find.byTooltip(l10n.pause).evaluate().isNotEmpty,
      );
      expect(find.byTooltip(l10n.play), findsNothing);

      await tester.tap(find.byTooltip(l10n.pause));
      await until(
        tester,
        () => find.byTooltip(l10n.play).evaluate().isNotEmpty,
      );
      final stopped = playhead();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(playhead(), stopped, reason: 'paused stays put');
    });
  }

  testWidgets('scrubbing the ruler pauses playback', (tester) async {
    final l10n = await importOneClip(tester, const Locale('en'));
    await tester.tap(find.byTooltip(l10n.play));
    await until(tester, () => find.byTooltip(l10n.pause).evaluate().isNotEmpty);

    final ruler = tester.getTopLeft(find.byKey(TimelineView.rulerKey));
    await tester.dragFrom(ruler + const Offset(2, 4), const Offset(80, 0));
    await until(tester, () => find.byTooltip(l10n.play).evaluate().isNotEmpty);
  });
}
