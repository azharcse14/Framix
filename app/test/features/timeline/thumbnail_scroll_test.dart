import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('scrolling a long clip asks for the newly shown times', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(120000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ThumbnailTile));

    // Without a platform every ask that goes out fails; count them.
    var asks = 0;
    final counting = engine.events
        .where((e) => e.hasCommandFailed())
        .listen((_) => asks++);
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await settle();
    final before = asks;
    // Scroll far right on the lanes (not the ruler), past what was built before.
    await tester.drag(find.byType(ClipBox), const Offset(-3000, 0));
    await settle();
    expect(asks, greaterThan(before));
    await counting.cancel();
  });
}
