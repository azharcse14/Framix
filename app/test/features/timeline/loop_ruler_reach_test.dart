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

/// P1-099 review: a loop left past the timeline's end (its clip deleted) is still in reach of
/// the timeline's scroll, so the band can be seen.
void main() {
  late FramixEngine engine;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  MediaItem video(int i) => MediaItem(
    uri: 'content://media/external/video/$i',
    kind: MediaKind.MEDIA_KIND_VIDEO,
    durationValue: Int64(6000),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  testWidgets('scrolling to the end reaches a loop past the last clip', (
    tester,
  ) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video(1), video(2)]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(2)));
    TimelineChanged state() =>
        tester.element(find.byType(TimelinePage)).read<TimelineCubit>().state;

    await tester.ensureVisible(find.byType(ClipBox).at(1));
    await tester.tap(find.byType(ClipBox).at(1));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(tester, find.byKey(TimelineView.loopKey));
    await tester.tap(find.byTooltip(l10n.deleteClip));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
    expect(state().loopEnd, greaterThan(state().duration));

    final scrollable = find
        .ancestor(
          of: find.byKey(TimelineView.loopKey),
          matching: find.byType(Scrollable),
        )
        .evaluate()
        .map((e) => e.widget as Scrollable)
        .firstWhere((s) => s.axisDirection == AxisDirection.right);
    final scroll = find.byWidget(scrollable);
    final position = tester.state<ScrollableState>(scroll).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    final band = tester.getRect(find.byKey(TimelineView.loopKey));
    final view = tester.getRect(scroll);
    expect(
      band.right,
      lessThanOrEqualTo(view.right),
      reason: 'the end of the loop is in reach',
    );
  });
}
