import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Widget tests never load real fonts, so a missing MaterialIcons font only
  // shows on device as "?" boxes. Guard the pubspec flag that bundles it.
  test('pubspec bundles the MaterialIcons font', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^\s+uses-material-design:\s*true\s*$', multiLine: true)
          .hasMatch(pubspec),
      isTrue,
    );
  });
}
