import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// Loop button edges (P1-027 review): the loop is the selected clip's own range, and the
/// actions row with it still fits a phone, so selecting never moves the lanes.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

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

  Future<void> twoClips(WidgetTester tester) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video(1), video(2)]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
  }

  TimelineChanged state(WidgetTester tester) =>
      tester.element(find.byType(TimelinePage)).read<TimelineCubit>().state;

  IconButton loopButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(
      of: find.byTooltip(l10n.loopClip),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets('the Loop button loops the second clip\'s own range', (
    tester,
  ) async {
    await twoClips(tester);
    await tester.tap(find.byType(ClipBox).at(1));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(
      tester,
      find.byWidgetPredicate((_) => state(tester).loopEnd != 0),
    );
    final clip = state(tester).tracks.first.clips[1];
    expect(clip.start, isNot(Int64.ZERO));
    expect(state(tester).loopStart, clip.start);
    expect(state(tester).loopEnd, clip.start + clip.duration);

    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(
      tester,
      find.byWidgetPredicate((_) => state(tester).loopEnd == 0),
    );
    await tester.pump();
    expect(loopButton(tester).isSelected, isFalse);
  });

  testWidgets(
    'on a 360 dp phone selecting a video clip does not move the lanes',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await twoClips(tester);
      final before = tester.getTopLeft(find.byType(ClipBox).first);
      await tester.tap(find.byType(ClipBox).first);
      await tester.pump();
      expect(find.byTooltip(l10n.loopClip), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ClipBox).first), before);
    },
  );
}
