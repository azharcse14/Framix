import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'timeline_page_test.dart' show pumpUntil;

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Finder toggled(String tooltip) => find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == tooltip && (w.isSelected ?? false),
  );

  testWidgets('mute and lock toggle from the engine; audio has no hide', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('en')),
    );
    await tester.tap(find.text(l10n.addAudioTrack));
    await pumpUntil(tester, find.text(l10n.audioTrackName(1)));
    expect(find.byTooltip(l10n.hideTrack), findsNothing);

    await tester.tap(find.byTooltip(l10n.muteTrack));
    await pumpUntil(tester, toggled(l10n.muteTrack));
    await tester.tap(find.byTooltip(l10n.lockTrack));
    await pumpUntil(tester, toggled(l10n.lockTrack));
    expect(toggled(l10n.muteTrack), findsOneWidget, reason: 'mute kept');

    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.byTooltip(l10n.hideTrack));
  });
}
