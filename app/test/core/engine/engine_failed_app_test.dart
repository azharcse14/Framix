import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('a debug fail-fast shows the mismatch, not a blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(EngineFailedApp(error: EngineProtocolMismatch(7)));
    await tester.pumpAndSettle();
    final shown = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
    expect(shown.message, contains('protocol version 7'));
  });
}
