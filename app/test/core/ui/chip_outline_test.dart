import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // DS-010 review: M3 chips draw the unselected edge with outlineVariant (the divider
  // border); a chip is a control, so its edge must use the 3:1 outline token.
  testWidgets('unselected chips are edged with the outline token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        home: Scaffold(
          body: ChoiceChip(
            label: const Text('x'),
            selected: false,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    // RawChip paints its edge on an Ink ShapeDecoration.
    final ink = tester.widget<Ink>(
      find.descendant(of: find.byType(ChoiceChip), matching: find.byType(Ink)),
    );
    final shape = (ink.decoration! as ShapeDecoration).shape as OutlinedBorder;
    expect(shape.side.color, FramixColors.dark.outline);
  });
}
