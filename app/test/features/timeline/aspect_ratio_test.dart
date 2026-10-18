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

  Finder selectedChip(String label) => find.byWidgetPredicate(
    (w) => w is ChoiceChip && w.selected && (w.label as Text).data == label,
  );

  testWidgets('the engine default 9:16 is selected; picking 16:9 selects it', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, locale: const Locale('en')),
    );
    await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(9, 16)));

    await tester.tap(find.text(l10n.aspectRatioLabel(16, 9)));
    await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(16, 9)));
    expect(selectedChip(l10n.aspectRatioLabel(9, 16)), findsNothing);

    await tester.tap(find.byTooltip(l10n.undo));
    await pumpUntil(tester, selectedChip(l10n.aspectRatioLabel(9, 16)));
  });
}
