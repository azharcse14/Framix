import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:material_ui/material_ui.dart'
    show BackButton, Scrollable, ScrollableState;

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// DS-008: Bangla text in Home, buttons, chips, segmented buttons and toolbars is never cut at
/// the top or bottom. A style's `height` sets the line box (M3 styles all set one), but glyphs
/// paint where the font draws them, so Bangla matras and vowel signs can paint outside a line box
/// squeezed below them, and a clip around it cuts them. The 1 em FlutterTest font of widget tests
/// draws boxes that hide that, so the test renders with Anek Bangla, the design system's Bangla
/// font (test/fonts, see its README), paints each text to find its real ink rows, and checks
/// them against every clip in effect around it.
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

  Future<void> pumpEditor(
    WidgetTester tester,
    double textScale, {
    Size size = const Size(360, 740),
  }) async {
    tester.view
      ..physicalSize = size
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
    // Guards the fixture: with no style height a line takes the font's own ascent and descent,
    // exactly 14 in the 1 em test font and about 1.87 em (26) in Anek Bangla.
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
      // The ratio chips overflow their row, so the check walks through a clipping scroller.
      final chips = find.ancestor(
        of: find.text(bn.aspectRatioLabel(21, 9)),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(chips.first).position.maxScrollExtent,
        greaterThan(0),
      );
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

    for (final size in const [Size(852, 393), Size(640, 360)]) {
      testWidgets(
        'landscape ${size.width.toInt()}x${size.height.toInt()} editor '
        'with a selected clip: no Bangla text cut at text scale $scale',
        (tester) async {
          await pumpEditor(tester, scale, size: size);
          await tester.tap(find.byTooltip(bn.importFromGallery));
          await pumpUntil(tester, find.byType(ClipBox));
          await tester.ensureVisible(find.byType(ClipBox));
          // A 4 s clip runs past a landscape screen's right edge; tap its visible start.
          final clip = tester.getRect(find.byType(ClipBox));
          await tester.tapAt(Offset(clip.left + 16, clip.center.dy));
          await pumpUntil(tester, find.byTooltip(bn.splitClip));
          expect(tester.takeException(), isNull);
          await expectNoCutText(tester);
        },
      );
    }

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
/// - has ink ([_inkRows], measured from the painted glyphs) above or below a clip that is in
///   effect around it ([RenderObject.describeApproximatePaintClip]: clip widgets, physical
///   shapes, and a flex, stack or scroll view while it overflows).
/// A text whose line box lies above or below a scroll view around it is scrolled out of view,
/// not cut: the walk stops there.
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
    // A paragraph wider than its box clips itself to its line box (overflow clip or
    // ellipsis), which the walk up from its parent never sees.
    if (p.didExceedMaxLines ||
        p.size.height < p.textSize.height ||
        p.size.width < p.textSize.width) {
      cut.add('"$text": ${p.textSize} in ${p.size}');
      continue;
    }
    final toGlobal = p.getTransformTo(null);
    final rect = MatrixUtils.transformRect(toGlobal, Offset.zero & p.size);
    final rows = await _inkRows(tester, p);
    if (rows == null) continue;
    final ink = MatrixUtils.transformRect(
      toGlobal,
      Rect.fromLTRB(0, rows.$1, p.size.width, rows.$2),
    );
    RenderObject child = p;
    for (var a = p.parent; a != null; child = a, a = a.parent) {
      if (a is! RenderBox) continue;
      final box = _globalRect(a);
      if (a is RenderAbstractViewport && _outside(rect, box)) break;
      if (_outside(rect, box)) {
        cut.add('"$text" ($rect) outside ${a.runtimeType} ($box)');
        break;
      }
      final clip = a.describeApproximatePaintClip(child);
      if (clip == null) continue;
      final clipRect = MatrixUtils.transformRect(a.getTransformTo(null), clip);
      if (_outside(ink, clipRect)) {
        cut.add('"$text" ink ($ink) cut by ${a.runtimeType} ($clipRect)');
        break;
      }
    }
  }
  expect(cut, isEmpty);
}

/// Half a pixel for rounding in the layout.
bool _outside(Rect inner, Rect outer) =>
    inner.top < outer.top - 0.5 || inner.bottom > outer.bottom + 0.5;

/// The first and last pixel rows [p]'s glyphs paint, in its own coordinates (they may lie above
/// 0 or below its height); null when it paints nothing. Lays the text out as [p] does and paints
/// it, with a line's height of room on every side, into an image.
Future<(double, double)?> _inkRows(
  WidgetTester tester,
  RenderParagraph p,
) async {
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textAlign: p.textAlign,
    textScaler: p.textScaler,
    maxLines: p.maxLines,
    ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.softWrap ? p.size.width : double.infinity);
  final margin = painter.preferredLineHeight.ceil();
  final width = painter.width.ceil() + 2 * margin;
  final height = painter.height.ceil() + 2 * margin;
  final recorder = ui.PictureRecorder();
  painter.paint(
    ui.Canvas(recorder),
    Offset(margin.toDouble(), margin.toDouble()),
  );
  painter.dispose();
  final picture = recorder.endRecording();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    return data!;
  });
  picture.dispose();
  int? first, last;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      // RGBA bytes; any alpha is ink.
      if (bytes!.getUint8((y * width + x) * 4 + 3) != 0) {
        first ??= y;
        last = y;
        break;
      }
    }
  }
  if (first == null) return null;
  return ((first - margin).toDouble(), (last! + 1 - margin).toDouble());
}

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
