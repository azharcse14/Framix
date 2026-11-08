import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/edited_label.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

void main() {
  group('editedLabel', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 11, 4, 14, 0);
    String at(Duration ago) => editedLabel(l10n, 'en', now, now.subtract(ago));

    test('says how long ago, then the date', () {
      expect(at(const Duration(seconds: 30)), l10n.editedJustNow);
      expect(at(const Duration(minutes: 5)), l10n.editedMinutesAgo(5));
      expect(at(const Duration(hours: 3)), l10n.editedHoursAgo(3));
      expect(at(const Duration(hours: 26)), l10n.editedYesterday);
      expect(at(const Duration(days: 3)), l10n.projectEdited('Nov 1, 2026'));
    });

    test('a time in the future (clock moved) reads as just now', () {
      expect(at(const Duration(minutes: -10)), l10n.editedJustNow);
    });
  });

  group('Home', () {
    late FramixEngine engine;
    late Directory dir;

    setUp(() {
      engine = FramixEngine.create();
      dir = Directory.systemTemp.createTempSync('framix-home-design');
    });
    tearDown(() {
      engine.dispose();
      dir.deleteSync(recursive: true);
    });

    Future<void> pumpHome(WidgetTester tester, Locale locale) =>
        tester.pumpWidget(
          FramixApp(
            engine: engine,
            locale: locale,
            home: HomePage(projectsDir: () async => dir.path),
          ),
        );

    testWidgets('shows the wordmark, a project card, and New project low', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pumpHome(tester, const Locale('en'));
      await pumpUntil(tester, find.text(l10n.projectsEmpty));
      expect(find.text(l10n.appTitle), findsOneWidget);

      // The primary action sits in the lower half of the screen.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final button = tester.getCenter(find.text(l10n.newProject));
      expect(button.dy, greaterThan(screen.height / 2));

      await tester.tap(find.text(l10n.newProject));
      await pumpUntil(tester, find.text(l10n.addVideoTrack));
      await tester.tap(find.text(l10n.addVideoTrack));
      await pumpUntil(tester, find.text(l10n.videoTrackName(1)));
      await tester.tap(find.byType(BackButton));

      await pumpUntil(tester, find.text(l10n.editedJustNow));
      expect(find.text('00:00.00'), findsOneWidget);
      expect(find.text(l10n.recentProjects(1)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bangla Home with a project renders without overflow', (
      tester,
    ) async {
      final bn = lookupAppLocalizations(const Locale('bn'));
      await pumpHome(tester, const Locale('bn'));
      await pumpUntil(tester, find.text(bn.projectsEmpty));
      await tester.tap(find.text(bn.newProject));
      await pumpUntil(tester, find.text(bn.addVideoTrack));
      await tester.tap(find.text(bn.addVideoTrack));
      await pumpUntil(tester, find.text(bn.videoTrackName(1)));
      await tester.tap(find.byType(BackButton));
      await pumpUntil(tester, find.text(bn.editedJustNow));
      expect(tester.takeException(), isNull);
    });
  });
}
