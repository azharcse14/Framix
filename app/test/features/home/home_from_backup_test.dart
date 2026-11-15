import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// Opening a project whose last save is damaged says it opened an earlier copy (SYS-040).
void main() {
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('opening a damaged project says a copy was opened ($locale)', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('framix-from-backup');
      final earlier = FramixEngine.create();
      final engine = FramixEngine.create();
      addTearDown(() {
        engine.dispose();
        earlier.dispose();
        dir.deleteSync(recursive: true);
      });

      // An earlier launch saves one project twice (so it has a backup) and stops.
      var lists = 0;
      var stopped = false;
      earlier.events.listen(
        (e) => lists += e.hasProjectList() ? 1 : 0,
        onDone: () => stopped = true,
      );
      final track = Command(
        addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO),
      );
      earlier
        ..send(Command(openLibrary: OpenLibrary(dir: dir.path)))
        ..send(Command(newProject: NewProject()))
        ..send(track.deepCopy())
        ..send(Command(listProjects: ListProjects()))
        ..send(track.deepCopy())
        ..send(Command(listProjects: ListProjects()));
      await pumpUntilTrue(tester, () => lists == 2, () => 'never saved twice');
      earlier.dispose();
      await pumpUntilTrue(tester, () => stopped, () => 'never stopped');
      // Its last save is then damaged.
      dir
          .listSync()
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.framix'))
          .writeAsStringSync('not a project');

      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: locale,
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );
      await pumpUntil(tester, find.text(l10n.recentProjects(1)));
      await tester.tap(find.text(l10n.clipCount(0)));
      await pumpUntil(tester, find.text(l10n.openedFromBackup));
      expect(find.text(l10n.workRecovered), findsNothing);
    });

    // The notice above can match on Home mid-transition; it must stay on the editor (UX-036).
    testWidgets('the copy-opened notice shows on the editor ($locale)', (
      tester,
    ) async {
      final l10n = await _openDamagedProject(tester, locale);
      await pumpUntil(tester, find.byType(TimelinePage));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byType(TimelinePage),
          matching: find.text(l10n.openedFromBackup),
        ),
        findsOneWidget,
      );
    });
  }
}

/// Saves a project twice in an earlier engine, damages its last save, then shows Home in
/// [locale] and taps the project.
Future<AppLocalizations> _openDamagedProject(
  WidgetTester tester,
  Locale locale,
) async {
  final dir = Directory.systemTemp.createTempSync('framix-from-backup');
  final earlier = FramixEngine.create();
  final engine = FramixEngine.create();
  addTearDown(() {
    engine.dispose();
    earlier.dispose();
    dir.deleteSync(recursive: true);
  });

  var lists = 0;
  var stopped = false;
  earlier.events.listen(
    (e) => lists += e.hasProjectList() ? 1 : 0,
    onDone: () => stopped = true,
  );
  final track = Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO));
  earlier
    ..send(Command(openLibrary: OpenLibrary(dir: dir.path)))
    ..send(Command(newProject: NewProject()))
    ..send(track.deepCopy())
    ..send(Command(listProjects: ListProjects()))
    ..send(track.deepCopy())
    ..send(Command(listProjects: ListProjects()));
  await pumpUntilTrue(tester, () => lists == 2, () => 'never saved twice');
  earlier.dispose();
  await pumpUntilTrue(tester, () => stopped, () => 'never stopped');
  dir
      .listSync()
      .whereType<File>()
      .singleWhere((f) => f.path.endsWith('.framix'))
      .writeAsStringSync('not a project');

  final l10n = lookupAppLocalizations(locale);
  await tester.pumpWidget(
    FramixApp(
      engine: engine,
      locale: locale,
      home: HomePage(projectsDir: () async => dir.path),
    ),
  );
  await pumpUntil(tester, find.text(l10n.recentProjects(1)));
  await tester.tap(find.text(l10n.clipCount(0)));
  return l10n;
}
