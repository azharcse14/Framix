import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/small_spinner.dart';
import 'package:material_ui/material_ui.dart';

/// DS-012: one small spinner for busy buttons, sized like the icon it stands in for.
void main() {
  Future<CircularProgressIndicator> pump(
    WidgetTester tester,
    Widget spinner, {
    IconThemeData icon = const IconThemeData(size: 36, color: Colors.white),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: IconTheme(data: icon, child: spinner),
        ),
      ),
    );
    expect(tester.getSize(find.byWidget(spinner)), const Size.square(36));
    return tester.widget(find.byType(CircularProgressIndicator));
  }

  testWidgets('sized like the icon, announced, and thin', (tester) async {
    final semantics = tester.ensureSemantics();
    final spinner = await pump(tester, const SmallSpinner(label: 'Busy'));
    expect(spinner.strokeWidth, 2);
    expect(spinner.value, isNull);
    expect(spinner.color, isNull, reason: 'the theme color unless asked');
    expect(find.bySemanticsLabel('Busy'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows progress and can take the icon color', (tester) async {
    final spinner = await pump(
      tester,
      const SmallSpinner(label: 'Busy', value: 0.5, iconColor: true),
    );
    expect(spinner.value, 0.5);
    expect(spinner.color, Colors.white);
  });
}
