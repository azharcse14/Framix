import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'timeline_page_test.dart' show pumpUntil;

/// SC-006: on a landscape phone the preview gets most of the screen; the timeline and its
/// actions sit beside it.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  /// Pumps the editor at [size] (logical pixels) and waits for the canvas (the preview until
  /// the engine's Texture arrives).
  Future<Rect> pumpEditor(
    WidgetTester tester,
    Size size, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FramixApp(engine: engine, locale: locale));
    await pumpUntil(tester, find.byType(AspectRatio));
    return tester.getRect(find.byType(AspectRatio));
  }

  double area(Rect r) => r.width * r.height;

  testWidgets('the preview is larger in landscape than in portrait', (
    tester,
  ) async {
    final portrait = await pumpEditor(tester, const Size(390, 844));
    final landscape = await pumpEditor(tester, const Size(844, 390));
    expect(area(landscape), greaterThan(area(portrait) * 2));
  });

  testWidgets('in landscape the timeline sits beside the preview', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final preview = await pumpEditor(tester, const Size(844, 390));
    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.byType(TimelineView));
    final timeline = tester.getRect(find.byType(TimelineView));
    expect(timeline.left, greaterThanOrEqualTo(preview.right));
    expect(
      tester.getRect(find.text(l10n.addVideoTrack)).left,
      greaterThanOrEqualTo(preview.right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Bangla landscape editor with tracks does not overflow', (
    tester,
  ) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    await pumpEditor(tester, const Size(844, 390), locale: const Locale('bn'));
    await tester.tap(find.text(bn.addVideoTrack));
    await pumpUntil(tester, find.text(bn.videoTrackName(1)));
    await tester.tap(find.text(bn.addAudioTrack));
    await pumpUntil(tester, find.text(bn.audioTrackName(1)));
    // A RenderFlex overflow would have been reported as an exception.
    expect(tester.takeException(), isNull);
  });
}
