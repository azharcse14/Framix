import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_find_test.dart' show pumpUntilGone;
import 'home_page_test.dart' show pumpUntil;

void main() {
  late FramixEngine engine;
  late Directory dir;

  setUp(() {
    engine = FramixEngine.create();
    dir = Directory.systemTemp.createTempSync('framix-home-trash');
  });
  tearDown(() {
    engine.dispose();
    dir.deleteSync(recursive: true);
  });

  /// Saves one unnamed project in the library before Home opens it.
  void seed() {
    engine.send(Command(openLibrary: OpenLibrary(dir: dir.path)));
    engine.send(Command(newProject: NewProject()));
    engine.send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)));
  }

  Future<void> pumpHome(WidgetTester tester, Locale locale) =>
      tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: locale,
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );

  testWidgets('a deleted project waits in Recently deleted and comes back', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    seed();
    await pumpHome(tester, const Locale('en'));
    final card = find.text(l10n.untitledProject);
    await pumpUntil(tester, card);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteProject));
    await tester.pumpAndSettle();
    await pumpUntilGone(tester, card);

    final deleted = find.widgetWithText(ChoiceChip, l10n.recentlyDeleted);
    await pumpUntil(tester, deleted);
    await tester.tap(deleted);
    await pumpUntil(tester, card);
    expect(find.text(l10n.daysLeft(30)), findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.restoreProject));
    await tester.pumpAndSettle();
    await pumpUntilGone(tester, card);
    await tester.tap(find.widgetWithText(ChoiceChip, l10n.allProjects));
    await pumpUntil(tester, card);
    expect(find.text(l10n.daysLeft(30)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bangla delete and restore render', (tester) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    seed();
    await pumpHome(tester, const Locale('bn'));
    final card = find.text(bn.untitledProject);
    await pumpUntil(tester, card);
    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text(bn.deleteProject));
    await tester.pumpAndSettle();
    final deleted = find.widgetWithText(ChoiceChip, bn.recentlyDeleted);
    await pumpUntil(tester, deleted);
    await tester.tap(deleted);
    await pumpUntil(tester, find.text(bn.daysLeft(30)));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text(bn.restoreProject), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
