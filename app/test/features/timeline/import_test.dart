import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'timeline_page_test.dart' show pumpUntil;

/// Returns canned picks; counts calls.
class FakeImporter implements MediaImporter {
  FakeImporter(this.gallery);

  final List<MediaItem> gallery;
  int calls = 0;

  @override
  Future<List<MediaItem>> pickFromGallery() async {
    calls++;
    return gallery;
  }

  @override
  Future<List<MediaItem>> pickFromFiles() async => const [];
}

MediaItem _video(String uri) => MediaItem(
  uri: uri,
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(2000),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('gallery picks become clips on a video track', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final importer = FakeImporter([
      _video('content://media/external/video/1'),
      _video('content://media/external/video/2'),
    ]);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: importer,
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    expect(find.text(l10n.videoTrackName(1)), findsOneWidget);
    expect(importer.calls, 1);
  });

  testWidgets('a cancelled pick adds nothing', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final importer = FakeImporter(const []);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: importer,
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(importer.calls, 1);
    expect(find.text(l10n.timelineEmpty), findsOneWidget);
  });
}
