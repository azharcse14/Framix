import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// L10N-003: plurals and variable text are ARB ICU messages, never Dart string building.
// (en/bn key and placeholder parity: test/l10n_test.dart, L10N-001.)

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// `message.placeholder` ints that label or measure something, never a count to pluralize.
const _notCounts = {
  'videoTrackName.number',
  'audioTrackName.number',
  'aspectRatioLabel.width',
  'aspectRatioLabel.height',
  'framesPerSecond.fps',
  'bitrateKbps.kbps',
  'exportFrameSize.width',
  'exportFrameSize.height',
};

void main() {
  test('every int/num placeholder heads an ICU plural in en and bn', () {
    final en = _arb('en');
    final bn = _arb('bn');
    final used = <String>{};
    final notPlural = <String>[];
    for (final MapEntry(:key, :value) in en.entries) {
      if (!key.startsWith('@') || key.startsWith('@@')) continue;
      final message = key.substring(1);
      final placeholders =
          (value as Map<String, dynamic>)['placeholders']
              as Map<String, dynamic>? ??
          const {};
      for (final MapEntry(key: name, value: meta) in placeholders.entries) {
        final type = (meta as Map<String, dynamic>)['type'];
        if (type != 'int' && type != 'num') continue;
        if (_notCounts.contains('$message.$name')) {
          used.add('$message.$name');
          continue;
        }
        for (final (locale, arb) in [('en', en), ('bn', bn)]) {
          final text = arb[message] as String? ?? '';
          if (!RegExp('\\{$name\\s*,\\s*plural\\s*,').hasMatch(text)) {
            notPlural.add('$locale: $message {$name}');
          }
        }
      }
    }
    expect(notPlural, isEmpty, reason: 'use {count, plural, ...}');
    expect(
      _notCounts.difference(used),
      isEmpty,
      reason: 'remove allowlist entries no longer in app_en.arb',
    );
  });

  test('app/lib builds no text around localized strings', () {
    // A localized string glued to other text: `l10n.x + ...`, `l10n.x(n).trim() + ...`,
    // `... + l10n.x`, `s += l10n.x`, or `'${l10n.x} ...'`. Matches across line breaks,
    // since dart format splits after `+`.
    // Blind spots: AppLocalizations held under another local name than `l10n`
    // (e.g. `final t = AppLocalizations.of(context)`), `[...].join()`, StringBuffer,
    // and adjacent-literal or `'$a$b'` glue of values that were read earlier.
    final building = RegExp(
      r'(l10n|AppLocalizations\.of\(\w+\))(\s*\.\s*\w+(\((?:[^()]|\([^()]*\))*\))?)+\s*\+'
      r'|\+=?\s*(l10n|AppLocalizations)\b'
      r'|\$\{\s*(l10n|AppLocalizations)\b',
    );
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') && !f.path.contains('/l10n/generated/'),
        )
        .toList();
    expect(files, isNotEmpty, reason: 'run from app/');
    final found = [
      for (final f in files)
        for (final m in building.allMatches(f.readAsStringSync()))
          '${f.path}: ${m[0]}',
    ];
    expect(found, isEmpty, reason: 'put the whole sentence in an ARB message');
  });
}
