import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_page_test.dart' show pumpUntil;

void main() {
  late FramixEngine engine;
  late Directory dir;

  setUp(() {
    engine = FramixEngine.create();
    dir = Directory.systemTemp.createTempSync('framix-home-folder');
  });
  tearDown(() {
    engine.dispose();
    dir.deleteSync(recursive: true);
  });

  testWidgets(
    'moving the last project out of the shown folder shows all again',
    (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      engine.send(Command(openLibrary: OpenLibrary(dir: dir.path)));
      engine.send(Command(newProject: NewProject()));
      engine.send(
        Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)),
      );
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: const Locale('en'),
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );
      final card = find.text(l10n.untitledProject);
      await pumpUntil(tester, card);

      Future<void> moveTo(String folder) async {
        await tester.longPress(card);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.moveToFolder));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          folder,
        );
        await tester.tap(find.text(l10n.save));
        await tester.pumpAndSettle();
      }

      await moveTo('Trips');
      final trips = find.widgetWithText(ChoiceChip, 'Trips');
      await pumpUntil(tester, trips);
      await tester.tap(trips);
      await tester.pumpAndSettle();
      await moveTo('');
      await pumpUntil(tester, find.text(l10n.recentProjects(1)));

      // A search lists again: it must not still filter by the folder that is gone.
      await tester.enterText(
        find.widgetWithText(TextField, l10n.searchProjects),
        '',
      );
      await tester.tap(find.byTooltip(l10n.sortProjects));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.sortByName));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.text(l10n.recentProjects(1)));
      expect(card, findsOneWidget);
      expect(find.text(l10n.noMatchingProjects), findsNothing);
    },
  );
}
