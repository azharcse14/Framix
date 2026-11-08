import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// P1-100: on a 360 dp phone the Clear loop control does not squeeze the playhead timecode.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('a loop keeps the timecode at full size on a 360 dp phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(2000),
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
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
    final timecode = find.textContaining(RegExp(r'^\d\d:\d\d\.\d\d$'));
    final before = tester.getRect(timecode).height;

    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(tester, find.byKey(TimelineView.loopKey));
    // Deselect: the loop stays, and its clear control must still be in reach.
    await tester.tap(find.byType(ClipBox));
    await tester.pump();

    expect(find.byTooltip(l10n.clearLoop), findsOneWidget);
    expect(
      tester.getRect(timecode).height,
      moreOrLessEquals(before, epsilon: 0.01),
      reason: 'the timecode is not scaled down',
    );
  });
}
