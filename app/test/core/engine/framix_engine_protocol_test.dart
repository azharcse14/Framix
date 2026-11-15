import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/engine_bindings.g.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

FramixEngine _mismatched() =>
    FramixEngine.create(protocolVersion: ENGINE_PROTOCOL_VERSION + 1);

void main() {
  test('a protocol version the engine does not speak is a typed error', () {
    expect(
      _mismatched,
      throwsA(
        isA<EngineProtocolMismatch>().having(
          (e) => e.version,
          'version',
          ENGINE_PROTOCOL_VERSION + 1,
        ),
      ),
    );
  });

  test('debug builds fail fast on a mismatch', () {
    expect(
      () => startEngine(failFast: true, create: _mismatched),
      throwsA(isA<EngineProtocolMismatch>()),
    );
  });

  test('release builds report a mismatch and start without an engine', () {
    final reported = <Object>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (details) => reported.add(details.exception);
    addTearDown(() => FlutterError.onError = onError);

    expect(startEngine(failFast: false, create: _mismatched), isNull);
    expect(reported, [isA<EngineProtocolMismatch>()]);
  });

  test('a matching version starts the engine', () {
    final engine = startEngine(failFast: false);
    addTearDown(() => engine?.dispose());
    expect(engine, isNotNull);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('without an engine the app says something went wrong '
        '(${locale.languageCode})', (tester) async {
      await tester.pumpWidget(EngineFailedApp(locale: locale));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      expect(find.text(l10n.somethingWentWrong), findsOneWidget);
    });
  }
}
