import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// L10N-003: plurals and variable text are ARB ICU messages, never Dart string building.

Map<String, String> _messages(String locale) {
  final arb = jsonDecode(
    File('lib/l10n/app_$locale.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in arb.entries)
      if (!key.startsWith('@')) key: value as String,
  };
}

/// Placeholder names used in [message]: `{name}` and the `{name, plural|select, ...}` heads
/// (a `{` right after a branch key such as `other{` opens branch text, not a placeholder).
Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'(?<![\w=])\{(\w+)(?:\}|,)').allMatches(message))
    m[1]!,
};

void main() {
  final en = _messages('en');
  final bn = _messages('bn');

  test('every count message is an ICU plural in en and bn', () {
    final notPlural = [
      for (final (locale, messages) in [('en', en), ('bn', bn)])
        for (final MapEntry(:key, :value) in messages.entries)
          if (_placeholders(value).contains('count') &&
              !value.startsWith('{count, plural,'))
            '$locale: $key',
    ];
    expect(notPlural, isEmpty, reason: 'use {count, plural, ...}');
  });

  test('bn uses the same placeholders as en for every message', () {
    final mismatched = [
      for (final MapEntry(:key, :value) in en.entries)
        if (bn[key] case final b?
            when !setEquals(_placeholders(value), _placeholders(b)))
          key,
    ];
    expect(mismatched, isEmpty);
  });

  test('app/lib builds no text around localized strings', () {
    // A localized string glued to other text: `l10n.x + ...`, `... + l10n.x`, or `'${l10n.x} ...'`.
    final building = RegExp(
      r'(l10n|AppLocalizations\.of\(\w+\))\.\w+(\([^()]*\))?\s*\+'
      r'|\+\s*(l10n|AppLocalizations)\b'
      r'|\$\{\s*(l10n|AppLocalizations)\b',
    );
    final found = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('/l10n/generated/'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (building.hasMatch(line)) '${f.path}:${i + 1}: $line',
    ];
    expect(found, isEmpty, reason: 'put the whole sentence in an ARB message');
  });
}
