import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart'
    show MediaItem, MediaKind;
import 'package:framix/features/home/view/home_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart' show BackButton;

import 'import_test.dart' show FakeImporter;
// The 10 s budget: the Home case makes many engine round trips (see home_open_test).
import '../home/home_open_test.dart' show pumpUntil;

/// DS-008: Bangla text in Home, buttons, chips, segmented buttons and toolbars is never cut at
/// the top or bottom. A style's `height` sets the line box (M3 styles all set one), but glyphs
/// keep the font's own ascent and descent, so Bangla matras and vowel signs paint outside a line
/// box squeezed below them, and a clip around it cuts them. The 1 em FlutterTest font of widget
/// tests hides that, so the test renders with Anek Bangla, the design system's Bangla font
/// (test/fonts, see its README), and checks each text's ink band (the font's own ascent and
/// descent around its baselines) against every clip around it.
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

  Future<void> pumpHome(
    WidgetTester tester,
    double textScale,
    Directory dir,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 740)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('bn'),
        home: HomePage(projectsDir: () async => dir.path),
      ),
    );
  }

  test('the Bangla fixture font gives a Bangla line its real height', () async {
    // Guards the fixture: with no style height a line takes the font's own ascent and descent
    // (what [_inkBand] reads): exactly 14 in the 1 em test font, about 1.87 em (26) in Anek Bangla.
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
    testWidgets('empty Home: no Bangla text cut at text scale $scale', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('framix-home');
      addTearDown(() => dir.deleteSync(recursive: true));
      await pumpHome(tester, scale, dir);
      await pumpUntil(tester, find.text(bn.projectsEmpty));
      expect(tester.takeException(), isNull);
      await expectNoCutText(tester);
    });

    testWidgets(
      'Home with a project: no Bangla text cut at text scale $scale',
      (tester) async {
        final dir = Directory.systemTemp.createTempSync('framix-home');
        addTearDown(() => dir.deleteSync(recursive: true));
        await pumpHome(tester, scale, dir);
        await pumpUntil(tester, find.text(bn.projectsEmpty));
        await tester.tap(find.text(bn.newProject));
        await pumpUntil(tester, find.text(bn.timelineEmpty));
        await tester.tap(find.text(bn.addVideoTrack));
        await pumpUntil(tester, find.text(bn.videoTrackName(1)));
        await tester.tap(find.byType(BackButton));
        await pumpUntil(tester, find.textContaining(bn.clipCount(0)));
        expect(tester.takeException(), isNull);
        await expectNoCutText(tester);
      },
    );

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

/// Fails for each text that:
/// - drops lines (`didExceedMaxLines`; on purpose this also flags a single-line ellipsis, since
///   a cut-off word is a cut too);
/// - has lines taller than its own box;
/// - has a line box above or below any box around it (overflowing a button, chip or bar);
/// - has ink ([_inkBand]) above or below a clip around it.
/// The walk up stops at a vertical scroll view: text scrolled out of view is not a cut.
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
    final toGlobal = p.getTransformTo(null);
    final rect = MatrixUtils.transformRect(toGlobal, Offset.zero & p.size);
    final (inkTop, inkBottom) = _inkBand(p);
    final ink = MatrixUtils.transformRect(
      toGlobal,
      Rect.fromLTRB(0, inkTop, p.size.width, inkBottom),
    );
    for (RenderObject? a = p.parent; a != null; a = a.parent) {
      if (a is RenderViewportBase && a.axis == Axis.vertical) break;
      if (a is! RenderBox) continue;
      final box = _globalRect(a);
      if (_outside(rect, box)) {
        cut.add('"$text" ($rect) outside ${a.runtimeType} ($box)');
        break;
      }
      if (_clips(a) && _outside(ink, box)) {
        cut.add('"$text" ink ($ink) cut by ${a.runtimeType} ($box)');
        break;
      }
    }
  }
  expect(cut, isEmpty);
}

/// Half a pixel for rounding in the layout.
bool _outside(Rect inner, Rect outer) =>
    inner.top < outer.top - 0.5 || inner.bottom > outer.bottom + 0.5;

/// Where [p]'s glyphs paint, top and bottom in its own coordinates: the font's own ascent above
/// the first baseline and its own descent below the last, whatever line height the style sets.
/// ponytail: reads the root span's font only; a text mixing fonts or sizes needs per-span bands.
(double, double) _inkBand(RenderParagraph p) {
  TextPainter layout(InlineSpan text) => TextPainter(
    text: text,
    textDirection: p.textDirection,
    textAlign: p.textAlign,
    textScaler: p.textScaler,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.softWrap ? p.size.width : double.infinity);
  final lines = layout(p.text);
  final s = p.text.style ?? const TextStyle();
  // The same font with no height: its line is exactly the font's ascent and descent.
  final natural = layout(
    TextSpan(
      text: 'ক',
      style: TextStyle(
        fontFamily: s.fontFamily,
        fontFamilyFallback: s.fontFamilyFallback,
        fontSize: s.fontSize,
        fontWeight: s.fontWeight,
        locale: s.locale,
      ),
    ),
  );
  final metrics = lines.computeLineMetrics();
  final font = natural.computeLineMetrics().first;
  lines.dispose();
  natural.dispose();
  return (
    metrics.first.baseline - font.ascent,
    metrics.last.baseline + font.descent,
  );
}

/// Whether [box] cuts what its children paint outside it.
bool _clips(RenderBox box) => switch (box) {
  RenderClipRect(:final clipBehavior) ||
  RenderClipRRect(:final clipBehavior) ||
  RenderClipOval(:final clipBehavior) ||
  RenderClipPath(:final clipBehavior) ||
  RenderPhysicalModel(:final clipBehavior) ||
  RenderPhysicalShape(:final clipBehavior) ||
  RenderStack(:final clipBehavior) ||
  RenderFlex(:final clipBehavior) ||
  RenderViewportBase(:final clipBehavior) => clipBehavior != Clip.none,
  _ => false,
};

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
