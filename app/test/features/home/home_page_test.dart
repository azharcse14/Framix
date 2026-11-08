import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

void main() {
  late FramixEngine engine;
  late Directory dir;

  setUp(() {
    engine = FramixEngine.create();
    dir = Directory.systemTemp.createTempSync('framix-home');
  });
  tearDown(() {
    engine.dispose();
    dir.deleteSync(recursive: true);
  });

  Widget app(Locale locale, Future<String?> Function() projectsDir) =>
      FramixApp(
        engine: engine,
        locale: locale,
        home: HomePage(projectsDir: projectsDir),
      );

  testWidgets('a new project is listed on Home and opens again', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(app(const Locale('en'), () async => dir.path));
    await pumpUntil(tester, find.text(l10n.projectsEmpty));

    await tester.tap(find.text(l10n.newProject));
    await pumpUntil(tester, find.text(l10n.timelineEmpty));
    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.text(l10n.videoTrackName(1)));

    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.textContaining(l10n.clipCount(0)));
    expect(find.text(l10n.projectsEmpty), findsNothing);
    expect(
      dir.listSync().where((f) => f.path.endsWith('.framix')),
      hasLength(1),
    );

    await tester.tap(find.textContaining(l10n.clipCount(0)));
    await pumpUntil(tester, find.text(l10n.videoTrackName(1)));
  });

  testWidgets('Home in Bangla', (tester) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    await tester.pumpWidget(app(const Locale('bn'), () async => dir.path));
    await pumpUntil(tester, find.text(bn.projectsEmpty));
    expect(find.text(bn.newProject), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a projects folder Home says so', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(app(const Locale('en'), () async => null));
    await pumpUntil(tester, find.text(l10n.projectsUnavailable));
  });
}
