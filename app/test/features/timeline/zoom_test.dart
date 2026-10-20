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

MediaItem _video(int ms) => MediaItem(
  uri: 'content://media/external/video/1',
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(ms),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<AppLocalizations> importOneClip(
    WidgetTester tester,
    String locale,
  ) async {
    final l10n = lookupAppLocalizations(Locale(locale));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([_video(4000)]),
        locale: Locale(locale),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ClipBox));
    return l10n;
  }

  testWidgets('zoom in widens clips, zoom out narrows them', (tester) async {
    final l10n = await importOneClip(tester, 'en');
    final before = tester.getSize(find.byType(ClipBox)).width;

    await tester.tap(find.byTooltip(l10n.zoomIn));
    await tester.pump();
    expect(
      tester.getSize(find.byType(ClipBox)).width,
      closeTo(before * 1.5, 0.5),
    );

    await tester.tap(find.byTooltip(l10n.zoomOut));
    await tester.pump();
    expect(tester.getSize(find.byType(ClipBox)).width, closeTo(before, 0.5));
  });

  testWidgets('dragging along the ruler moves the playhead', (tester) async {
    await importOneClip(tester, 'en');
    final playhead = find.byKey(TimelineView.playheadKey);
    final start = tester.getTopLeft(playhead).dx;

    final ruler = tester.getTopLeft(find.byKey(TimelineView.rulerKey));
    await tester.dragFrom(ruler + const Offset(2, 4), const Offset(150, 0));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (tester.getTopLeft(playhead).dx > start + 100) break;
    }
    expect(tester.getTopLeft(playhead).dx, greaterThan(start + 100));
  });

  testWidgets('zoom buttons are labelled in Bangla', (tester) async {
    final bn = await importOneClip(tester, 'bn');
    expect(find.byTooltip(bn.zoomIn), findsOneWidget);
    expect(find.byTooltip(bn.zoomOut), findsOneWidget);
  });
}
