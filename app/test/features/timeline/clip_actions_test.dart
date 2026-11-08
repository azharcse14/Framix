import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// Clip UI (P1-045): tap a clip to select it, then split at the playhead, delete, duplicate,
/// or merge it with the next clip. The engine does the edits.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  MediaItem video(String uri) => MediaItem(
    uri: uri,
    kind: MediaKind.MEDIA_KIND_VIDEO,
    durationValue: Int64(2000),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  /// The app with one 2 s clip on a video track.
  Future<void> oneClip(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          video('content://media/external/video/1'),
        ]),
        locale: locale,
      ),
    );
    final l10n = lookupAppLocalizations(locale);
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
  }

  BuildContext page(WidgetTester tester) =>
      tester.element(find.byType(TimelinePage));

  /// Seeks to [seconds] and waits until the engine reports it.
  Future<void> seekTo(WidgetTester tester, double seconds) async {
    final tps = page(tester).read<TimelineCubit>().state.ticksPerSecond.toInt();
    final ticks = (seconds * tps).round();
    page(tester).read<PlayheadCubit>().seek(ticks);
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (page(tester).read<PlayheadCubit>().state == ticks) return;
    }
    throw TestFailure('the playhead never reached $seconds s');
  }

  bool selected(WidgetTester tester, int index) =>
      tester.widget<ClipBox>(find.byType(ClipBox).at(index)).selected;

  testWidgets(
    'tapping a clip selects it and shows its actions; tapping again clears',
    (tester) async {
      await oneClip(tester);
      expect(find.byTooltip(l10n.splitClip), findsNothing);

      await tester.tap(find.byType(ClipBox));
      await tester.pump();
      expect(selected(tester, 0), isTrue);
      for (final action in [
        l10n.splitClip,
        l10n.deleteClip,
        l10n.duplicateClip,
        l10n.mergeClip,
      ]) {
        expect(find.byTooltip(action), findsOneWidget, reason: action);
      }

      await tester.tap(find.byType(ClipBox));
      await tester.pump();
      expect(selected(tester, 0), isFalse);
      expect(find.byTooltip(l10n.splitClip), findsNothing);
    },
  );

  testWidgets('split at the playhead, then merge the halves back', (
    tester,
  ) async {
    await oneClip(tester);
    await seekTo(tester, 0.5);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.splitClip));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    expect(selected(tester, 0), isTrue, reason: 'the left part stays selected');

    await tester.tap(find.byTooltip(l10n.mergeClip));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
  });

  testWidgets('merge is off without a clip right after', (tester) async {
    await oneClip(tester);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    final merge = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(l10n.mergeClip),
        matching: find.byType(IconButton),
      ),
    );
    expect(merge.onPressed, isNull);
  });

  testWidgets(
    'duplicate adds a copy; delete removes the clip and the selection',
    (tester) async {
      await oneClip(tester);
      await tester.tap(find.byType(ClipBox));
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.duplicateClip));
      await pumpUntil(tester, find.text(l10n.clipCount(2)));

      await tester.tap(find.byTooltip(l10n.deleteClip));
      await pumpUntil(tester, find.text(l10n.clipCount(1)));
      expect(
        find.byTooltip(l10n.deleteClip),
        findsNothing,
        reason: 'nothing selected',
      );
    },
  );

  testWidgets('Bangla: the actions have Bangla labels', (tester) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    await oneClip(tester, locale: const Locale('bn'));
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    expect(find.byTooltip(bn.splitClip), findsOneWidget);
    expect(find.byTooltip(bn.mergeClip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the trim handles moves the clip edges on release', (
    tester,
  ) async {
    await oneClip(tester);
    double width() => tester.getSize(find.byType(ClipBox)).width;
    final full = width();
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    expect(find.bySemanticsLabel(l10n.trimStart), findsOneWidget);

    // The default zoom is 100 px per second: 50 px is half a second.
    await tester.drag(
      find.bySemanticsLabel(l10n.trimEnd),
      const Offset(-50, 0),
    );
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (w.width - (full - 50)).abs() < 1,
      ),
    );

    await tester.drag(
      find.bySemanticsLabel(l10n.trimStart),
      const Offset(50, 0),
    );
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (w.width - (full - 100)).abs() < 1,
      ),
    );
    expect(width(), closeTo(full - 100, 1));
  });

  testWidgets('no trim handles without a selection', (tester) async {
    await oneClip(tester);
    expect(find.bySemanticsLabel(l10n.trimStart), findsNothing);
    expect(find.bySemanticsLabel(l10n.trimEnd), findsNothing);
  });

  // P1-045 review.

  Rect clipRect(WidgetTester tester, int index) =>
      tester.getRect(find.byType(ClipBox).at(index));

  testWidgets('split at 0.5 s leaves a 0.5 s and a 1.5 s clip', (tester) async {
    await oneClip(tester);
    await seekTo(tester, 0.5);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.splitClip));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    expect(clipRect(tester, 0).width, closeTo(50, 1));
    expect(clipRect(tester, 1).width, closeTo(150, 1));
  });

  testWidgets('trimming the start moves the left edge, not the right', (
    tester,
  ) async {
    await oneClip(tester);
    final before = clipRect(tester, 0);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.drag(
      find.bySemanticsLabel(l10n.trimStart),
      const Offset(50, 0),
    );
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (w) => w is ClipBox && (w.width - (before.width - 50)).abs() < 1,
      ),
    );
    expect(clipRect(tester, 0).left, closeTo(before.left + 50, 1));
    expect(clipRect(tester, 0).right, closeTo(before.right, 1));
  });

  testWidgets('selecting does not move the clips', (tester) async {
    await oneClip(tester);
    final before = clipRect(tester, 0);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    expect(clipRect(tester, 0), before);
  });

  testWidgets('a short clip still has a 48 dp tap target', (tester) async {
    await oneClip(tester);
    await seekTo(tester, 0.2);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.splitClip));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    // Clear the selection, then tap 40 dp right of the 20 dp clip's left edge.
    await tester.tap(find.byTooltip(l10n.deleteClip));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
    await tester.tap(find.byTooltip(l10n.undo));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    final short = clipRect(tester, 0);
    expect(short.width, closeTo(20, 1));
    await tester.tapAt(short.centerLeft + const Offset(40, 0));
    await tester.pump();
    expect(selected(tester, 0), isTrue);
  });

  testWidgets('the handles sit outside the clip, inside the timeline', (
    tester,
  ) async {
    await oneClip(tester);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    final clip = clipRect(tester, 0);
    final start = tester.getRect(find.bySemanticsLabel(l10n.trimStart));
    final end = tester.getRect(find.bySemanticsLabel(l10n.trimEnd));
    expect(start.width, 48);
    expect(end.width, 48);
    expect(end.left, closeTo(clip.right, 1));
    // The first clip starts at 0: its start handle is clamped into the lane.
    expect(start.left, greaterThanOrEqualTo(clip.left));
    // Tapping the clip away from the handles clears the selection.
    await tester.tapAt(clip.center + const Offset(40, 0));
    await tester.pump();
    expect(selected(tester, 0), isFalse);
  });

  testWidgets('replace puts a newly picked video under the clip', (
    tester,
  ) async {
    await oneClip(tester);
    final before = page(tester).read<TimelineCubit>().state.tracks[0].clips[0];
    await tester.tap(find.byType(ClipBox));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.replaceClip));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final now = page(tester).read<TimelineCubit>().state.tracks[0].clips[0];
      if (now.mediaId != before.mediaId) {
        expect(now.id, before.id, reason: 'same clip');
        return;
      }
    }
    throw TestFailure('the clip never got the new media');
  });

  // P1-074: a dragged trim edge snaps to a near clip edge (12 dp, decided by the engine).
  testWidgets('a trim edge dropped near the next clip snaps to it', (
    tester,
  ) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          video('content://media/external/video/1'),
          video('content://media/external/video/2'),
        ]),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));

    // 100 px per second: move the second clip's start to 2.5 s.
    await tester.tap(find.byType(ClipBox).at(1));
    await tester.pump();
    await tester.drag(
      find.bySemanticsLabel(l10n.trimStart),
      const Offset(50, 0),
    );
    await pumpUntil(
      tester,
      find.byWidgetPredicate((w) => w is ClipBox && (w.width - 150).abs() < 1),
    );

    // The first clip's end dropped at 2.45 s lands on 2.5 s.
    await tester.tap(find.byType(ClipBox).at(0));
    await tester.pump();
    await tester.drag(find.bySemanticsLabel(l10n.trimEnd), const Offset(45, 0));
    await pumpUntil(
      tester,
      find.byWidgetPredicate((w) => w is ClipBox && (w.width - 250).abs() < 1),
    );
  });

  // P1-075: merge follows the engine's rule, not just "a clip comes next".
  testWidgets('merge is off when the next clip shows other media', (
    tester,
  ) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          video('content://media/external/video/1'),
          video('content://media/external/video/2'),
        ]),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    await tester.tap(find.byType(ClipBox).at(0));
    await tester.pump();
    final merge = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(l10n.mergeClip),
        matching: find.byType(IconButton),
      ),
    );
    expect(merge.onPressed, isNull);
  });
}
