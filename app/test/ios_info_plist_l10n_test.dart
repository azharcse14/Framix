import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// L10N-014: iOS shows the *UsageDescription permission text from Info.plist, which
// the ARB files cannot reach. Runner/InfoPlist.xcstrings localizes each one in every
// app locale, and the Runner target bundles it.

const _locales = ['en', 'bn'];

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final usage = {
    for (final m in RegExp(
      r'<key>(\w+UsageDescription)</key>\s*<string>([^<]*)</string>',
    ).allMatches(plist))
      m.group(1)!: m.group(2)!,
  };
  final catalog = File('ios/Runner/InfoPlist.xcstrings');
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
      .readAsStringSync();

  test('Info.plist has permission text to localize', () {
    expect(usage, isNotEmpty);
  });

  test('every *UsageDescription key has a value in every app locale', () {
    final strings =
        (jsonDecode(catalog.readAsStringSync())
                as Map<String, dynamic>)['strings']
            as Map<String, dynamic>;
    final missing = <String>[];
    for (final key in usage.keys) {
      final locs =
          (strings[key] as Map<String, dynamic>?)?['localizations']
              as Map<String, dynamic>? ??
          const {};
      for (final locale in _locales) {
        final unit = (locs[locale] as Map<String, dynamic>?)?['stringUnit'];
        final value = (unit as Map<String, dynamic>?)?['value'] as String?;
        if (value == null || value.trim().isEmpty) missing.add('$key: $locale');
      }
      final en =
          ((locs['en'] as Map<String, dynamic>?)?['stringUnit']
                  as Map<String, dynamic>?)?['value']
              as String?;
      if (en != null && en != usage[key]) {
        missing.add('$key: en differs from Info.plist');
      }
    }
    expect(missing, isEmpty);
  });

  test(
    'the Runner target bundles InfoPlist.xcstrings and knows every locale',
    () {
      expect(pbxproj, contains('InfoPlist.xcstrings in Resources'));
      final regions = RegExp(r'knownRegions = \(([^)]*)\)')
          .firstMatch(pbxproj)!
          .group(1)!;
      for (final locale in _locales) {
        expect(regions, matches(RegExp('\\b$locale,')), reason: locale);
      }
    },
  );
}
