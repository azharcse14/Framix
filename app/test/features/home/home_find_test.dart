import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
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
    dir = Directory.systemTemp.createTempSync('framix-home-find');
  });
  tearDown(() {
    engine.dispose();
    dir.deleteSync(recursive: true);
  });

  /// Saves [count] unnamed projects in the library before Home opens it.
  void seed(int count) {
    engine.send(Command(openLibrary: OpenLibrary(dir: dir.path)));
    for (var i = 0; i < count; i++) {
      engine.send(Command(newProject: NewProject()));
      engine.send(
        Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)),
      );
    }
  }

  Future<void> pumpHome(WidgetTester tester, Locale locale) =>
      tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: locale,
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );

  /// Long-presses [card], picks [action] and saves [text] in its dialog.
  Future<void> act(
    WidgetTester tester,
    Finder card,
    String action,
    String text,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  /// Whether [a] comes before [b] in reading order.
  bool before(WidgetTester tester, String a, String b) {
    final pa = tester.getTopLeft(find.text(a));
    final pb = tester.getTopLeft(find.text(b));
    return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
  }

  testWidgets('projects can be renamed, searched, sorted and put in folders', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    seed(2);
    await pumpHome(tester, const Locale('en'));
    await pumpUntil(tester, find.text(l10n.untitledProject));
    expect(find.text(l10n.untitledProject), findsNWidgets(2));

    await act(
      tester,
      find.text(l10n.untitledProject).first,
      l10n.renameProject,
      'Party',
    );
    await pumpUntil(tester, find.text('Party'));
    await act(
      tester,
      find.text(l10n.untitledProject),
      l10n.renameProject,
      'Beach',
    );
    await pumpUntil(tester, find.text('Beach'));

    // Search.
    final search = find.widgetWithText(TextField, l10n.searchProjects);
    await tester.enterText(search, 'BEA');
    await pumpUntilGone(tester, find.text('Party'));
    expect(find.text('Beach'), findsOneWidget);
    await tester.enterText(search, 'zzz');
    await pumpUntil(tester, find.text(l10n.noMatchingProjects));
    await tester.enterText(search, '');
    await pumpUntil(tester, find.text('Party'));

    // Sort by name.
    await tester.tap(find.byTooltip(l10n.sortProjects));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sortByName));
    await tester.pumpAndSettle();
    // The reply's state change schedules its frame on one pump and draws on the next.
    await pumpUntilTrue(
      tester,
      () => before(tester, 'Beach', 'Party'),
      () => 'never sorted by name',
    );

    // Folders.
    await act(tester, find.text('Party'), l10n.moveToFolder, 'Trips');
    final trips = find.widgetWithText(ChoiceChip, 'Trips');
    await pumpUntil(tester, trips);
    await tester.tap(trips);
    await pumpUntilGone(tester, find.text('Beach'));
    expect(find.text('Party'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, l10n.allProjects));
    await pumpUntil(tester, find.text('Beach'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bangla project menu and rename dialog render', (tester) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    seed(1);
    await pumpHome(tester, const Locale('bn'));
    await pumpUntil(tester, find.text(bn.untitledProject));
    expect(find.widgetWithText(TextField, bn.searchProjects), findsOneWidget);
    await tester.longPress(find.text(bn.untitledProject));
    await tester.pumpAndSettle();
    expect(find.text(bn.moveToFolder), findsOneWidget);
    await tester.tap(find.text(bn.renameProject));
    await tester.pumpAndSettle();
    expect(find.text(bn.projectName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
