import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// Multi-select (P1-024): "Select more" picks several clips; Delete, Duplicate and a long-press
/// drag act on all of them as one edit.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  MediaItem video(int i) => MediaItem(
    uri: 'content://media/external/video/$i',
    kind: MediaKind.MEDIA_KIND_VIDEO,
    durationValue: Int64(2000),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  /// Three 2 s clips back to back on one track.
  Future<AppLocalizations> threeClips(
    WidgetTester tester,
    Locale locale,
  ) async {
    final l10n = lookupAppLocalizations(locale);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video(1), video(2), video(3)]),
        locale: locale,
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(3)));
    return l10n;
  }

  Finder clip(int i) => find.byType(ClipBox).at(i);

  /// Selects clips [indexes] with "Select more" on.
  Future<void> selectMore(
    WidgetTester tester,
    AppLocalizations l10n,
    List<int> indexes,
  ) async {
    await tester.tap(clip(indexes.first));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.selectMore));
    await tester.pump();
    for (final i in indexes.skip(1)) {
      await tester.tap(clip(i));
      await tester.pump();
    }
  }

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('delete two selected clips at once, undo brings both back '
        '(${locale.languageCode})', (tester) async {
      final l10n = await threeClips(tester, locale);
      await selectMore(tester, l10n, [0, 2]);
      expect(find.text(l10n.selectedClipCount(2)), findsOneWidget);
      // Trim handles belong to a single clip.
      expect(find.bySemanticsLabel(l10n.trimStart), findsNothing);

      await tester.tap(find.byTooltip(l10n.deleteClip));
      await pumpUntil(tester, find.text(l10n.clipCount(1)));

      await tester.tap(find.byTooltip(l10n.undo));
      await pumpUntil(tester, find.text(l10n.clipCount(3)));
    });
  }

  testWidgets('tapping a selected clip again in select-more mode drops it', (
    tester,
  ) async {
    final l10n = await threeClips(tester, const Locale('en'));
    await selectMore(tester, l10n, [0, 1, 2]);
    expect(find.text(l10n.selectedClipCount(3)), findsOneWidget);
    await tester.tap(clip(1));
    await tester.pump();
    expect(find.text(l10n.selectedClipCount(2)), findsOneWidget);
  });

  testWidgets('duplicate copies the selected clips as a block after them', (
    tester,
  ) async {
    final l10n = await threeClips(tester, const Locale('en'));
    await selectMore(tester, l10n, [1, 2]);
    await tester.tap(find.byTooltip(l10n.duplicateClip));
    await pumpUntil(tester, find.text(l10n.clipCount(5)));
  });

  testWidgets(
    'long-press dragging one selected clip moves the whole selection',
    (tester) async {
      final l10n = await threeClips(tester, const Locale('en'));
      await selectMore(tester, l10n, [1, 2]);
      final first = tester.getRect(clip(0));
      final second = tester.getRect(clip(1));
      final third = tester.getRect(clip(2));

      final gesture = await tester.startGesture(third.center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await pumpUntil(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is ClipBox &&
              (tester.getRect(clip(2)).left - (third.left + 50)).abs() < 1,
        ),
      );
      expect(tester.getRect(clip(1)).left, closeTo(second.left + 50, 1));
      expect(tester.getRect(clip(0)).left, closeTo(first.left, 1));
    },
  );

  // P1-102: a multi-clip move only shifts time, so the lifted clip keeps to its lane.
  testWidgets(
    'a lifted clip of a multi-selection follows the finger sideways only',
    (tester) async {
      final l10n = await threeClips(tester, const Locale('en'));
      await selectMore(tester, l10n, [1, 2]);
      final third = tester.getRect(clip(2));

      final gesture = await tester.startGesture(third.center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(50, 40));
      await tester.pump();
      for (final box in find.byType(ClipBox).evaluate()) {
        expect(
          tester.getRect(find.byWidget(box.widget)).top,
          closeTo(third.top, 1),
        );
      }
      await gesture.up();
      await tester.pump();
    },
  );

  // P1-103: ids of clips the timeline lost (here, by undo) are dropped, so a tap on the one
  // selected clip clears the selection.
  testWidgets('a clip undone away leaves the selection', (tester) async {
    final l10n = await threeClips(tester, const Locale('en'));
    await selectMore(tester, l10n, [1, 2]);
    await tester.tap(find.byTooltip(l10n.duplicateClip));
    await pumpUntil(tester, find.text(l10n.clipCount(5)));
    // Select the first copy alone (its start is on screen), then undo it away.
    await tester.tapAt(tester.getRect(clip(3)).centerLeft + const Offset(8, 0));
    await tester.pump();
    await tester.tap(clip(1));
    await tester.pump();
    await tester.tap(clip(2));
    await tester.pump();
    expect(find.text(l10n.selectedClipCount(2)), findsNothing);
    await tester.tap(find.byTooltip(l10n.undo));
    await pumpUntil(tester, find.text(l10n.clipCount(3)));

    // Select more is still on: this adds clip 0; off again, a tap on it clears it.
    await tester.tap(clip(0));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.selectMore));
    await tester.pump();
    await tester.tap(clip(0));
    await tester.pump();
    expect(find.byTooltip(l10n.splitClip), findsNothing);
  });
}
