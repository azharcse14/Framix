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
      expect(runnerResources(pbxproj), contains('InfoPlist.xcstrings'));
      final regions = RegExp(r'knownRegions = \(([^)]*)\)')
          .firstMatch(pbxproj)!
          .group(1)!;
      for (final locale in _locales) {
        expect(regions, matches(RegExp('\\b$locale,')), reason: locale);
      }
    },
  );

  test('runnerResources only counts the Runner Resources phase files', () {
    final dropped = pbxproj.replaceFirst(
      RegExp(r'\n\t+[0-9A-F]{24} /\* InfoPlist\.xcstrings in Resources \*/,'),
      '',
    );
    expect(dropped, isNot(pbxproj));
    expect(dropped, contains('InfoPlist.xcstrings in Resources'));
    expect(runnerResources(dropped), isNot(contains('InfoPlist.xcstrings')));
  });
}

/// File paths in the Runner target's Resources build phase: the target's
/// buildPhases -> its PBXResourcesBuildPhase files -> each PBXBuildFile fileRef.
List<String> runnerResources(String pbxproj) {
  // Top-level objects sit at two tabs; nested dicts are deeper, so `};$` at
  // the first line end is the object's end for everything this walk reads.
  final objects = {
    for (final m in RegExp(
      r'^\t\t([0-9A-F]{24}) (?:/\*.*?\*/ )?= \{(.*?)\};$',
      multiLine: true,
      dotAll: true,
    ).allMatches(pbxproj))
      m.group(1)!: m.group(2)!,
  };
  List<String> ids(String body, String list) => RegExp(r'[0-9A-F]{24}')
      .allMatches(RegExp('$list = \\(([^)]*)\\)').firstMatch(body)!.group(1)!)
      .map((m) => m.group(0)!)
      .toList();
  String? field(String? body, String key) => body == null
      ? null
      : RegExp('$key = ([^;]+);').firstMatch(body)?.group(1);

  final runner = objects.values.singleWhere(
    (b) => b.contains('isa = PBXNativeTarget;') && b.contains('name = Runner;'),
  );
  final resources = ids(runner, 'buildPhases')
      .map((id) => objects[id]!)
      .singleWhere((b) => b.contains('isa = PBXResourcesBuildPhase;'));
  return [
    for (final id in ids(resources, 'files'))
      ?field(objects[field(objects[id], 'fileRef')?.split(' ').first], 'path'),
  ];
}
