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
import 'timeline_page_test.dart' show pumpUntil;

/// Moving clips (P1-047): long-press a clip, drag, release; the engine moves it (MoveClip).
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<void> oneClip(WidgetTester tester) async {
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
  }

  Rect clip(WidgetTester tester) => tester.getRect(find.byType(ClipBox));

  Future<void> longPressDrag(WidgetTester tester, Offset by) async {
    final gesture = await tester.startGesture(clip(tester).center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(by);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('long-press and drag moves the clip along its track', (
    tester,
  ) async {
    await oneClip(tester);
    final before = clip(tester);
    await longPressDrag(tester, const Offset(50, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is ClipBox && (clip(tester).left - (before.left + 50)).abs() < 1,
      ),
    );
    expect(clip(tester).width, closeTo(before.width, 1));
  });

  testWidgets('dragging down a lane moves the clip to the next video track', (
    tester,
  ) async {
    await oneClip(tester);
    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.text(l10n.videoTrackName(2)));
    final lane = tester.getSize(find.byType(ClipBox)).height;
    expect(lane, greaterThan(0));
    final before = clip(tester);
    // One lane is the clip's height plus the lane padding; a lane's height moves one track.
    final laneHeight =
        tester.getTopLeft(find.text(l10n.videoTrackName(2))).dy -
        tester.getTopLeft(find.text(l10n.videoTrackName(1))).dy;
    await longPressDrag(tester, Offset(0, laneHeight));
    await pumpUntil(tester, find.text(l10n.clipCount(0)));
    expect(clip(tester).top, closeTo(before.top + laneHeight, 1));
    expect(clip(tester).left, closeTo(before.left, 1));
  });

  testWidgets('a plain drag does not move the clip', (tester) async {
    await oneClip(tester);
    final before = clip(tester);
    await tester.dragFrom(before.center, const Offset(0, 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(clip(tester).left, closeTo(before.left, 1));
    expect(find.text(l10n.clipCount(1)), findsOneWidget);
  });

  testWidgets('the clip follows the finger while it is dragged', (
    tester,
  ) async {
    await oneClip(tester);
    final before = clip(tester);
    final gesture = await tester.startGesture(before.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(clip(tester).left, closeTo(before.left + 30, 1));
    await gesture.up();
    await tester.pump();
  });

  testWidgets('a clip narrower than 48 dp can be moved too (P1-047 review)', (
    tester,
  ) async {
    await oneClip(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip(l10n.zoomOut));
      await tester.pump();
    }
    final before = clip(tester);
    expect(before.width, lessThan(48));
    await longPressDrag(tester, const Offset(20, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is ClipBox && (clip(tester).left - (before.left + 20)).abs() < 1,
      ),
    );
  });

  // P1-076: the engine snaps a dropped clip to a near edge and clamps a start before 0.
  testWidgets('a clip dropped before 0 lands at 0', (tester) async {
    await oneClip(tester);
    final before = clip(tester);
    await longPressDrag(tester, const Offset(100, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is ClipBox && (clip(tester).left - (before.left + 100)).abs() < 1,
      ),
    );
    await longPressDrag(tester, const Offset(-150, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (clip(tester).left - before.left).abs() < 1,
      ),
    );
  });

  testWidgets('a clip dropped near another clip snaps to its edge', (
    tester,
  ) async {
    MediaItem video(int n) => MediaItem(
      uri: 'content://media/external/video/$n',
      kind: MediaKind.MEDIA_KIND_VIDEO,
      durationValue: Int64(2000),
      durationTimescale: 1000,
      width: 1080,
      height: 1920,
      codec: 'avc1',
    );
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video(1), video(2)]),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    Rect at(int i) => tester.getRect(find.byType(ClipBox).at(i));
    final origin = at(0).left;
    Future<void> drag(int i, Offset by) async {
      final gesture = await tester.startGesture(at(i).center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(by);
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    // 100 px per second: the second clip goes to [4 s, 6 s).
    await drag(1, const Offset(200, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (at(1).left - (origin + 400)).abs() < 1,
      ),
    );
    // The first clip dropped at 1.95 s ends 0.05 s before 4 s, so it lands at 2 s.
    await drag(0, const Offset(195, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (at(0).left - (origin + 200)).abs() < 1,
      ),
    );
  });
}
