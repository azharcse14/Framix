import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/messages.dart';
import 'package:material_ui/material_ui.dart';

/// UX-038: a one-time notice (opened from backup, work recovered, export result) is never
/// dropped behind the failed-autosave message, and the autosave guard ends when it closes.
void main() {
  Future<BuildContext> pumpScaffold(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  Future<void> seconds(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('a notice outranks a generic message waiting behind autosave', (
    tester,
  ) async {
    final context = await pumpScaffold(tester);
    showAutosaveFailed(context, 'autosave');
    await tester.pump();
    showMessage(context, 'generic');
    await tester.pump();
    showMessage(context, 'notice', important: true);
    await tester.pump();
    await seconds(tester, 12);
    expect(find.text('autosave'), findsNothing);
    expect(find.text('notice'), findsOneWidget);
    expect(find.text('generic'), findsNothing);
  });

  testWidgets('a generic message does not push out a waiting notice', (
    tester,
  ) async {
    final context = await pumpScaffold(tester);
    showAutosaveFailed(context, 'autosave');
    await tester.pump();
    showMessage(context, 'notice', important: true);
    await tester.pump();
    showMessage(context, 'generic');
    await tester.pump();
    await seconds(tester, 12);
    expect(find.text('notice'), findsOneWidget);
    expect(find.text('generic'), findsNothing);
  });

  testWidgets('after the autosave message closes, the newest message replaces '
      'a showing one', (tester) async {
    final context = await pumpScaffold(tester);
    showAutosaveFailed(context, 'autosave');
    await tester.pump();
    await seconds(tester, 12);
    expect(find.text('autosave'), findsNothing);
    showMessage(context, 'first');
    await tester.pump();
    await seconds(tester, 1);
    showMessage(context, 'second');
    await tester.pump();
    await seconds(tester, 1);
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
