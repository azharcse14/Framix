import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// P1-091: a double tap on New project opens one editor, not two.
void main() {
  testWidgets('a double tap on New project opens one editor', (tester) async {
    final engine = FramixEngine.create();
    final dir = Directory.systemTemp.createTempSync('framix-home-double');
    addTearDown(() {
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: HomePage(projectsDir: () async => dir.path),
      ),
    );
    await pumpUntil(tester, find.text(l10n.newProject));

    await tester.tap(find.text(l10n.newProject));
    await tester.tap(find.text(l10n.newProject), warnIfMissed: false);
    await pumpUntil(tester, find.byType(TimelinePage));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(TimelinePage, skipOffstage: false), findsOneWidget);
  });
}
