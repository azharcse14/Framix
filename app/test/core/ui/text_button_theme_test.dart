import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Accent belongs to the one primary action (docs/design-system.md); TextButtons such as
  // dialog Cancel/Save and the Result Done are secondary, so they use the text token.
  // Only the dark theme exists today; a light theme gets its own case here.
  testWidgets('TextButton foreground is the text token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        home: Scaffold(
          body: TextButton(onPressed: () {}, child: const Text('x')),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('x'));
    expect(paragraph.text.style?.color, FramixColors.dark.text);
  });
}
