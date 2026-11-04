import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// DS-008: Bangla text in buttons, chips, segmented buttons and toolbars is never cut at the
/// top or bottom. Widget tests draw every glyph in the 1 em FlutterTest font, which would hide a
/// Bangla line (about 1.4 em) in a box sized for Latin; so the test renders with Anek Bangla, the
/// design system's Bangla font (test/fonts, OFL), and checks every laid-out text line against its
/// own box and every box around it.
void main() {
  setUpAll(() async {
    // Typography's default family; the app sets no family of its own, so all text uses it.
    await (FontLoader('Roboto')..addFont(
          File('test/fonts/AnekBangla.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });

  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  final bn = lookupAppLocalizations(const Locale('bn'));

  Future<void> pumpEditor(WidgetTester tester, double textScale) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(4000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        locale: const Locale('bn'),
      ),
    );
    await pumpUntil(tester, find.text(bn.timelineEmpty));
  }

  test('the Bangla fixture font gives a Bangla line its real height', () async {
    // Guards the fixture: in the 1 em test font this line is exactly 14 tall.
    final painter = TextPainter(
      text: const TextSpan(
        text: 'ক্লিপ যোগ করুন',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    expect(painter.height, greaterThan(14 * 1.2));
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('empty editor: no Bangla text cut at text scale $scale', (
      tester,
    ) async {
      await pumpEditor(tester, scale);
      expect(tester.takeException(), isNull);
      await expectNoCutText(tester);
    });

    testWidgets('editor with a clip: no Bangla text cut at text scale $scale', (
      tester,
    ) async {
      await pumpEditor(tester, scale);
      await tester.tap(find.byTooltip(bn.importFromGallery));
      await pumpUntil(tester, find.byType(ClipBox));
      expect(tester.takeException(), isNull);
      await expectNoCutText(tester);
    });

    testWidgets('export sheet: no Bangla text cut at text scale $scale', (
      tester,
    ) async {
      await pumpEditor(tester, scale);
      await tester.tap(find.byTooltip(bn.exportSettings));
      await pumpUntil(tester, find.text(bn.autoBitrate));
      expect(tester.takeException(), isNull);
      await expectNoCutText(tester);
    });
  }
}

/// Fails for each text whose lines are taller than its own box, that drops lines, or that
/// sticks out above or below any box around it (a button, chip or bar clips or overflows it).
/// Vertical scroll views end the walk: scrolling text out of view is not a cut.
Future<void> expectNoCutText(WidgetTester tester) async {
  // Let entrance animations (a snack bar sliding in is clipped on purpose) finish.
  await tester.pump(const Duration(seconds: 1));
  final cut = <String>[];
  final paragraphs = tester.allRenderObjects
      .whereType<RenderParagraph>()
      .toSet();
  expect(paragraphs, isNotEmpty);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    if (p.didExceedMaxLines || p.size.height < p.textSize.height) {
      cut.add('"$text": ${p.textSize.height} tall in ${p.size.height}');
      continue;
    }
    final rect = _globalRect(p);
    for (RenderObject? a = p.parent; a != null; a = a.parent) {
      if (a is RenderViewportBase && a.axis == Axis.vertical) break;
      if (a is! RenderBox) continue;
      final box = _globalRect(a);
      // Half a pixel for rounding in the layout.
      if (rect.top < box.top - 0.5 || rect.bottom > box.bottom + 0.5) {
        cut.add('"$text" ($rect) outside ${a.runtimeType} ($box)');
        break;
      }
    }
  }
  expect(cut, isEmpty);
}

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
