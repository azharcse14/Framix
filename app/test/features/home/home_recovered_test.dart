import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// After a crash with a project open, Home says its work is saved (P1-066).
void main() {
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('Home tells the work was saved after a crash ($locale)', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('framix-recovered');
      // The crashed launch: a project is edited and autosaved, and the engine is never
      // stopped before the next launch starts.
      final crashed = FramixEngine.create();
      final engine = FramixEngine.create();
      addTearDown(() {
        engine.dispose();
        crashed.dispose();
        dir.deleteSync(recursive: true);
      });
      crashed
        ..send(Command(openLibrary: OpenLibrary(dir: dir.path)))
        ..send(Command(newProject: NewProject()))
        ..send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)));
      await tester.runAsync(() async {
        for (var i = 0; i < 250; i++) {
          if (dir.listSync().any((f) => f.path.endsWith('.framix'))) return;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        throw TestFailure('the crashed launch never autosaved');
      });

      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          locale: locale,
          home: HomePage(projectsDir: () async => dir.path),
        ),
      );
      await pumpUntil(tester, find.text(l10n.workRecovered));
      expect(find.text(l10n.recentProjects(1)), findsOneWidget);
    });
  }
}
