import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// P1-106: with a loop set, Clear loop leads the clip actions row unless the selected clip is
/// the looped one (its own Loop toggle clears it).
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

  Finder clip(int i) => find.byType(ClipBox).at(i);

  /// Three clips, the first looped, nothing selected.
  Future<void> loopFirstOfThree(WidgetTester tester) async {
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([video(1), video(2), video(3)]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(3)));
    await tester.tap(clip(0));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.loopClip));
    await pumpUntil(tester, find.byKey(TimelineView.loopKey));
    await tester.tap(clip(0));
    await tester.pump();
    expect(find.byTooltip(l10n.loopClip), findsNothing, reason: 'deselected');
  }

  testWidgets('two clips selected: Clear loop is offered', (tester) async {
    await loopFirstOfThree(tester);
    await tester.tap(clip(1));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.selectMore));
    await tester.pump();
    await tester.tap(clip(2));
    await tester.pump();
    expect(find.text(l10n.selectedClipCount(2)), findsOneWidget);

    expect(find.byTooltip(l10n.clearLoop), findsOneWidget);
  });

  testWidgets('another clip selected: Clear loop is offered', (tester) async {
    await loopFirstOfThree(tester);
    await tester.tap(clip(1));
    await tester.pump();
    expect(find.byTooltip(l10n.loopClip), findsOneWidget);

    expect(find.byTooltip(l10n.clearLoop), findsOneWidget);
  });

  testWidgets('the looped clip selected: only its Loop toggle clears it', (
    tester,
  ) async {
    await loopFirstOfThree(tester);
    await tester.tap(clip(0));
    await tester.pump();
    expect(find.byTooltip(l10n.loopClip), findsOneWidget);

    expect(find.byTooltip(l10n.clearLoop), findsNothing);
  });
}
