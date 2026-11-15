import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Every FramixColors field, in constructor order. Add new tokens here.
List<Color> _fields(FramixColors c) => [
  c.background,
  c.surface,
  c.elevated,
  c.border,
  c.outline,
  c.textMuted,
  c.text,
  c.accentFill,
  c.accentText,
  c.onAccent,
  c.error,
  c.onError,
];

/// A FramixColors whose fields are distinct from each other and from the dark tokens.
FramixColors _distinct(int base) {
  Color n(int i) => Color(0xFF000000 + base + i);
  return FramixColors(
    background: n(1),
    surface: n(2),
    elevated: n(3),
    border: n(4),
    outline: n(5),
    textMuted: n(6),
    text: n(7),
    accentFill: n(8),
    accentText: n(9),
    onAccent: n(10),
    error: n(11),
    onError: n(12),
  );
}

void main() {
  const c = FramixColors.dark;

  // DS-003 review: catch every way to derive a scheme from a seed, which tints surfaces.
  test('no seeded ColorScheme in app code', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final seeded = RegExp(
      r'fromSeed\s*\(|colorSchemeSeed\s*:|fromImageProvider\b',
    );
    final offenders = files
        .where((f) => seeded.hasMatch(f.readAsStringSync()))
        .map((f) => f.path);
    expect(offenders, isEmpty);
  });

  test('copyWith replaces every field', () {
    final d = _distinct(0x100);
    final copy = c.copyWith(
      background: d.background,
      surface: d.surface,
      elevated: d.elevated,
      border: d.border,
      outline: d.outline,
      textMuted: d.textMuted,
      text: d.text,
      accentFill: d.accentFill,
      accentText: d.accentText,
      onAccent: d.onAccent,
      error: d.error,
      onError: d.onError,
    );
    expect(_fields(copy), _fields(d));
    expect(_fields(c.copyWith()), _fields(c));
  });

  test('lerp blends every field with its own counterpart', () {
    final a = _distinct(0x100000);
    final b = _distinct(0x200000);
    final mid = a.lerp(b, 0.5);
    final (fa, fb) = (_fields(a), _fields(b));
    expect(_fields(mid), [
      for (var i = 0; i < fa.length; i++) Color.lerp(fa[i], fb[i], 0.5),
    ]);
  });
}
