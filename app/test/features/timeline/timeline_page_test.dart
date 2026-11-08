import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('adding a track shows it, undo removes it', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('en')),
    );
    expect(find.text(l10n.timelineEmpty), findsOneWidget);

    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.text(l10n.videoTrackName(1)));
    expect(find.text(l10n.clipCount(0)), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.undo));
    await pumpUntil(tester, find.text(l10n.timelineEmpty));
    expect(find.text(l10n.videoTrackName(1)), findsNothing);
  });

  testWidgets('Bangla locale renders Bangla text', (tester) async {
    final bn = lookupAppLocalizations(const Locale('bn'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('bn')),
    );
    expect(find.text(bn.timelineEmpty), findsOneWidget);
    expect(find.text(bn.addAudioTrack), findsOneWidget);

    await tester.tap(find.text(bn.addAudioTrack));
    await pumpUntil(tester, find.text(bn.audioTrackName(1)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracks are numbered per kind by the engine', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('en')),
    );
    await tester.tap(find.text(l10n.addAudioTrack));
    await pumpUntil(tester, find.text(l10n.audioTrackName(1)));
    await tester.tap(find.text(l10n.addVideoTrack));
    await pumpUntil(tester, find.byIcon(Icons.videocam).at(1));
    expect(find.text(l10n.videoTrackName(1)), findsOneWidget);
    expect(find.text(l10n.videoTrackName(2)), findsNothing);
  });
}
