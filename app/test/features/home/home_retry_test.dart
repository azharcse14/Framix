import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_open_test.dart' show pumpUntil;

/// P1-092: Home without a projects folder offers Try again instead of a dead end.
void main() {
  testWidgets('Try again opens the folder once it is available', (
    tester,
  ) async {
    final engine = FramixEngine.create();
    final dir = Directory.systemTemp.createTempSync('framix-home-retry');
    addTearDown(() {
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    final l10n = lookupAppLocalizations(const Locale('en'));
    var available = false;
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: HomePage(projectsDir: () async => available ? dir.path : null),
      ),
    );
    await pumpUntil(tester, find.text(l10n.projectsUnavailable));

    available = true;
    await tester.tap(find.text(l10n.retry));
    await pumpUntil(tester, find.text(l10n.projectsEmpty));
    expect(find.text(l10n.newProject), findsOneWidget);
  });
}
