import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_open_test.dart' show pumpUntil;

/// P1-092 review: Try again also recovers when the engine refused to list the folder
/// (it does not exist yet), in English and Bangla.
void main() {
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('Try again after the engine refused the folder ($locale)', (
      tester,
    ) async {
      final engine = FramixEngine.create();
      final root = Directory.systemTemp.createTempSync('framix-home-retry');
      final dir = Directory('${root.path}/projects');
      addTearDown(() {
        engine.dispose();
        root.deleteSync(recursive: true);
      });
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: locale,
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );
      await pumpUntil(tester, find.text(l10n.retry));
      expect(find.text(l10n.projectsUnavailable), findsOneWidget);

      dir.createSync();
      await tester.tap(find.text(l10n.retry));
      await pumpUntil(tester, find.text(l10n.projectsEmpty));
      expect(tester.takeException(), isNull);
    });
  }
}
