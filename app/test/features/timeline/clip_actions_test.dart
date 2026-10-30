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
import 'timeline_page_test.dart' show pumpUntil;

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
}
