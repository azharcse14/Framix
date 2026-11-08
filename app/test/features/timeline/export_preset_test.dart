import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// P1-037: a platform preset chip sets the canvas (and the export settings) in one tap.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Finder selectedChip(String label) => find.byWidgetPredicate(
    (w) => w is ChoiceChip && w.selected && (w.label as Text).data == label,
  );

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('platform presets pick their canvas ($locale)', (tester) async {
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(FramixApp(engine: engine, locale: locale));
      await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(9, 16)));

      await tester.tap(find.text(l10n.presetYouTube));
      await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(16, 9)));
      await tester.tap(find.text(l10n.presetInstagramFeed));
      await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(4, 5)));
      await tester.tap(find.text(l10n.presetShortVideo));
      await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(9, 16)));
      expect(tester.takeException(), isNull);
    });
  }
}
