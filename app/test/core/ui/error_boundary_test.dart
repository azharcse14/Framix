import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/error_boundary.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Throws while building, like a widget with a bug.
class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) => throw StateError('bug');
}

Widget _app(Locale locale, Widget child) => MaterialApp(
  theme: framixDarkTheme(),
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Column(
      children: [
        const Text('still here'),
        Expanded(child: child),
      ],
    ),
  ),
);

/// Installs the boundary; call the result at the end of the test body, since testWidgets
/// checks that the handlers are restored before tearDown runs.
void Function() _withBoundary() {
  final builder = ErrorWidget.builder;
  final onError = FlutterError.onError;
  final platformOnError = PlatformDispatcher.instance.onError;
  installErrorBoundary();
  return () {
    ErrorWidget.builder = builder;
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = platformOnError;
  };
}

void main() {
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('a widget that fails to build shows a message ($locale)', (
      tester,
    ) async {
      final restore = _withBoundary();
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(_app(locale, const _Broken()));
      expect(tester.takeException(), isStateError, reason: 'still reported');
      expect(find.text(l10n.somethingWentWrong), findsOneWidget);
      expect(find.text('still here'), findsOneWidget, reason: 'the rest works');
      restore();
    });
  }

  testWidgets('outside localizations the message has no text', (tester) async {
    final restore = _withBoundary();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) => const _Broken()),
      ),
    );
    expect(tester.takeException(), isStateError);
    expect(find.byType(ErrorPanel), findsOneWidget);
    expect(find.byType(Text), findsNothing);
    restore();
  });

  test('an uncaught async error is reported and does not crash the app', () {
    final restore = _withBoundary();
    final reported = <FlutterErrorDetails>[];
    FlutterError.onError = reported.add;
    final handled = PlatformDispatcher.instance.onError!(
      StateError('async bug'),
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(reported.single.exception, isStateError);
    restore();
  });
}
