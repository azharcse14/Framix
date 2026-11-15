import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/error_boundary.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

// L10N-001: app_en.arb (template) and app_bn.arb stay in step, and the app loads the
// material_ui/cupertino_ui localizations for every supported locale.

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  final en = _arb('en');
  final bn = _arb('bn');

  test('en and bn ARB files have the same message keys', () {
    expect(
      _messageKeys(en).difference(_messageKeys(bn)),
      isEmpty,
      reason: 'missing in app_bn.arb',
    );
    expect(
      _messageKeys(bn).difference(_messageKeys(en)),
      isEmpty,
      reason: 'missing in app_en.arb',
    );
  });

  test('every placeholder of an en message is used in its bn message', () {
    final missing = <String>[];
    for (final key in _messageKeys(en)) {
      final meta = en['@$key'] as Map<String, dynamic>?;
      final placeholders =
          (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
      final message = bn[key] as String? ?? '';
      for (final name in placeholders) {
        if (!RegExp('\\{$name\\s*[,}]').hasMatch(message)) {
          missing.add('$key: {$name}');
        }
      }
    }
    expect(missing, isEmpty);
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('app loads Material, Cupertino and Widgets localizations '
        'for $locale', (tester) async {
      await tester.pumpWidget(EngineFailedApp(locale: locale));
      final context = tester.element(find.byType(ErrorPanel));
      for (final delegate in GlobalMaterialLocalizations.delegates) {
        expect(
          Localizations.of<Object>(context, delegate.type),
          isNotNull,
          reason: '${delegate.type} for $locale',
        );
      }
      expect(Localizations.localeOf(context), locale);
    });
  }

  testWidgets('bn Material strings differ from en', (tester) async {
    Future<String> okLabel(Locale locale) async {
      await tester.pumpWidget(EngineFailedApp(locale: locale));
      return MaterialLocalizations.of(tester.element(find.byType(ErrorPanel)))
          .okButtonLabel;
    }

    expect(
      await okLabel(const Locale('bn')),
      isNot(await okLabel(const Locale('en'))),
    );
  });

  // L10N-016: tests use the app's one delegate list, not the generated
  // AppLocalizations.localizationsDelegates (package:flutter Material/Cupertino
  // delegates) or a hand-copied list.
  test('tests use the app delegate list', () {
    const banned = [
      'AppLocalizations.localizationsDelegates',
      'AppLocalizations.delegate,',
    ];
    final offenders = [
      for (final file in Directory('test').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('l10n_test.dart') &&
            banned.any(file.readAsStringSync().contains))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
