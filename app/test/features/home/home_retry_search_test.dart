import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// P1-107: after Try again, the search box is empty and every project is listed, so the
/// list never hides projects behind a search the box no longer shows.
void main() {
  testWidgets('Try again clears the search', (tester) async {
    final engine = FramixEngine.create();
    final root = Directory.systemTemp.createTempSync(
      'framix-home-retry-search',
    );
    final dir = Directory('${root.path}/projects')..createSync();
    final away = '${root.path}/away';
    addTearDown(() {
      engine.dispose();
      root.deleteSync(recursive: true);
    });
    engine.send(Command(openLibrary: OpenLibrary(dir: dir.path)));
    engine.send(Command(newProject: NewProject()));
    engine.send(Command(addTrack: AddTrack(kind: TrackKind.TRACK_KIND_VIDEO)));
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        home: HomePage(projectsDir: () async => dir.path),
      ),
    );
    await pumpUntil(tester, find.text(l10n.untitledProject));

    final search = find.widgetWithText(TextField, l10n.searchProjects);
    await tester.enterText(search, 'zzz');
    await pumpUntil(tester, find.text(l10n.noMatchingProjects));
    // The folder goes away: the next list is refused and Home offers Try again.
    dir.renameSync(away);
    await tester.enterText(search, 'zzzz');
    await pumpUntil(tester, find.text(l10n.retry));

    Directory(away).renameSync(dir.path);
    await tester.tap(find.text(l10n.retry));
    await pumpUntil(tester, find.text(l10n.untitledProject));
    final box = tester.widget<TextField>(find.byType(TextField));
    expect(box.controller?.text ?? '', isEmpty);
    expect(find.text('zzzz'), findsNothing);
    expect(find.text(l10n.noMatchingProjects), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
