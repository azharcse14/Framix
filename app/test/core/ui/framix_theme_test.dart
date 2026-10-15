import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Accent is for the one primary action and fails 4.5:1 as text on dark
  // surfaces (docs/design-system.md); secondary outlined buttons use text/outline.
  testWidgets('outlined buttons use text color and the outline token', (
    tester,
  ) async {
    const c = FramixColors.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        home: OutlinedButton(onPressed: () {}, child: const Text('x')),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.textStyle?.color, c.text);
    // DS-010: control boundaries use the 3:1 outline token, not the divider border.
    expect((material.shape! as OutlinedBorder).side.color, c.outline);
  });
}
