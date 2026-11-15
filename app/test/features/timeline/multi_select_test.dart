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

  MediaItem video(int i, {int ms = 2000}) => MediaItem(
    uri: 'content://media/external/video/$i',
    kind: MediaKind.MEDIA_KIND_VIDEO,
    durationValue: Int64(ms),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  /// Three clips of [ms] (2 s by default) back to back on one track.
  Future<AppLocalizations> threeClips(
    WidgetTester tester,
    Locale locale, {
    int ms = 2000,
  }) async {
    final l10n = lookupAppLocalizations(locale);
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          for (final i in [1, 2, 3]) video(i, ms: ms),
        ]),
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

  // P1-104: the same holds for a clip narrower than a touch target, dragged by the 48 dp
  // target laid over it.
  testWidgets(
    'a lifted narrow clip of a multi-selection follows the finger sideways only',
    (tester) async {
      // 0.3 s clips: 30 px wide at the initial zoom, under the 48 dp target.
      final l10n = await threeClips(tester, const Locale('en'), ms: 300);
      final third = tester.getRect(clip(2));
      expect(third.width, lessThan(48));
      // Clips 0 and 2, each tapped through its 48 dp target; clip 2 off its centre, which
      // clip 0's end trim handle covers while clip 0 is selected alone.
      await tester.tap(clip(0), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.selectMore));
      await tester.pump();
      await tester.tapAt(third.centerRight - const Offset(4, 0));
      await tester.pump();
      expect(find.text(l10n.selectedClipCount(2)), findsOneWidget);

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
      // Cancel, not drop: a drop would send a move that overlaps clip 1 and is refused after
      // the test body ends.
      await gesture.cancel();
      await tester.pump();
    },
  );

  // P1-113: the end trim handle of a selected narrow clip lies over the next narrow clip's
  // touch target; a tap there still selects that clip, and the handles move to it.
  testWidgets('a tap on a narrow clip under the trim handle selects it', (
    tester,
  ) async {
    await threeClips(tester, const Locale('en'), ms: 300);
    bool selected(int i) => tester.widget<ClipBox>(clip(i)).selected;
    await tester.tap(clip(0), warnIfMissed: false);
    await tester.pump();
    expect(selected(0), isTrue);

    await tester.tap(clip(1), warnIfMissed: false);
    await tester.pump();
    expect(selected(1), isTrue);
    expect(selected(0), isFalse);
  });

  // P1-113 review: the handle passes taps through, but a hold on it still trims, rather than
  // lifting the clip it lies over (here clip 0, which ends where clip 1 starts).
  testWidgets('holding then dragging a trim handle trims the clip', (
    tester,
  ) async {
    final l10n = await threeClips(tester, const Locale('en'));
    await tester.tap(clip(1));
    await tester.pump();
    final before = tester.getRect(clip(1));

    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel(l10n.trimStart)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await gesture.up();
    await pumpUntilTrue(
      tester,
      () => (tester.getRect(clip(1)).width - (before.width - 50)).abs() < 1,
      () => 'clip 1 is ${tester.getRect(clip(1))}, was $before',
    );
  });

  // P1-113 review: a held handle that the finger moves no more than the touch slop trims
  // nothing. A real trim follows, and the engine answers in order, so its result shows whether
  // the jitter trimmed too.
  testWidgets('a held trim handle moved within the slop trims nothing', (
    tester,
  ) async {
    final l10n = await threeClips(tester, const Locale('en'));
    await tester.tap(clip(1));
    await tester.pump();
    final before = tester.getRect(clip(1));
    final handle = find.bySemanticsLabel(l10n.trimStart);

    final jitter = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await jitter.moveBy(const Offset(2, 0));
    await tester.pump();
    await jitter.up();
    await tester.pump();

    await tester.drag(handle, const Offset(50, 0));
    await pumpUntilTrue(
      tester,
      () => tester.getRect(clip(1)).width < before.width - 1,
      () => 'clip 1 never trimmed: ${tester.getRect(clip(1))}',
    );
    expect(tester.getRect(clip(1)).width, closeTo(before.width - 50, 1));
  });

  // P1-113: a tap on a trim handle acts on what lies under it: here it selects the clip that
  // ends where the selected one starts.
  testWidgets('a tap on a trim handle selects the clip under it', (
    tester,
  ) async {
    final l10n = await threeClips(tester, const Locale('en'));
    bool selected(int i) => tester.widget<ClipBox>(clip(i)).selected;
    await tester.tap(clip(1));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(l10n.trimStart));
    await tester.pump();
    expect(selected(0), isTrue);
    expect(selected(1), isFalse);
  });

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
