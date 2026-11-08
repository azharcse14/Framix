import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'home_open_test.dart' show pumpUntil;

/// SHA-256 hex of `media/a.jpg`, how the platform names that media's cache files.
const _hash =
    '7aecb2d1a8f1e1a1bb1a226552bf563f3fc4eab13817d66dd0e3fc4817775b33';

/// Long-pressing a project shows its storage and clears its cache (P1-017).
void main() {
  late FramixEngine engine;
  late Directory root;
  late Directory projects;
  late File thumb;

  setUp(() {
    engine = FramixEngine.create();
    root = Directory.systemTemp.createTempSync('framix-home-storage');
    projects = Directory('${root.path}/projects')..createSync();
    thumb = File('${root.path}/cache/thumbs/$_hash-0-128.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(2048, 7));
  });
  tearDown(() {
    engine.dispose();
    root.deleteSync(recursive: true);
  });

  /// Home with one project holding the photo `media/a.jpg`, back from the editor.
  Future<AppLocalizations> homeWithPhoto(
    WidgetTester tester,
    Locale locale,
  ) async {
    final l10n = lookupAppLocalizations(locale);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: locale,
        home: HomePage(
          projectsDir: () async => projects.path,
          cacheDir: () async => '${root.path}/cache',
        ),
      ),
    );
    await pumpUntil(tester, find.text(l10n.newProject));
    await tester.tap(find.text(l10n.newProject));
    await pumpUntil(tester, find.text(l10n.addVideoTrack));
    await tester.pumpAndSettle();
    engine.send(
      Command(
        importMedia: ImportMedia(
          items: [
            MediaItem(
              uri: 'media/a.jpg',
              kind: MediaKind.MEDIA_KIND_IMAGE,
              width: 10,
              height: 10,
            ),
          ],
        ),
      ),
    );
    await pumpUntil(tester, find.textContaining(l10n.clipCount(1)));
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, find.text(l10n.recentProjects(1)));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('long-press shows the sizes; Clear cache removes the cache', (
    tester,
  ) async {
    final l10n = await homeWithPhoto(tester, const Locale('en'));
    await tester.longPress(find.text(l10n.clipCount(1)));
    await pumpUntil(tester, find.text(l10n.projectStorage));
    expect(find.text(l10n.storageCache), findsOneWidget);
    expect(find.text(l10n.fileSize('2', 'kb')), findsOneWidget);
    expect(find.text(l10n.storageProjectFiles), findsOneWidget);

    await tester.tap(find.text(l10n.clearCache));
    await pumpUntil(tester, find.text(l10n.fileSize('0', 'b')));
    expect(thumb.existsSync(), isFalse);
    // The project itself is kept.
    expect(
      projects.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.framix'),
      ),
      hasLength(1),
    );
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(l10n.clearCache),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull, reason: 'nothing left to clear');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Bangla storage sheet renders without overflow', (
    tester,
  ) async {
    final bn = await homeWithPhoto(tester, const Locale('bn'));
    await tester.longPress(find.text(bn.clipCount(1)));
    await pumpUntil(tester, find.text(bn.projectStorage));
    expect(find.text(bn.clearCache), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
