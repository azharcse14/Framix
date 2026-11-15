import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const c = FramixColors.dark;
  final tokens = {
    'background': c.background,
    'surface': c.surface,
    'elevated': c.elevated,
    'border': c.border,
    'outline': c.outline,
    'textMuted': c.textMuted,
    'text': c.text,
    'accentFill': c.accentFill,
    'accentText': c.accentText,
    'onAccent': c.onAccent,
  };

  // DS-003: the dark tokens are defined once, in docs/design-system.md; the code must match.
  test('dark tokens match the design-system.md color table', () {
    final rows = RegExp(
      r'^\| (\w+) \| #([0-9A-Fa-f]{6}) \|',
      multiLine: true,
    ).allMatches(File('../docs/design-system.md').readAsStringSync());
    final doc = {
      for (final m in rows) m[1]!: Color(int.parse('FF${m[2]}', radix: 16)),
    };
    expect(doc.keys.toSet(), tokens.keys.toSet());
    doc.forEach((name, hex) => expect(tokens[name], hex, reason: name));
  });

  // design-system.md: text 4.5:1 on background, surface and elevated.
  test('text tokens reach 4.5:1 on every surface', () {
    final texts = {
      'text': c.text,
      'textMuted': c.textMuted,
      'accentText': c.accentText,
      'error': c.error,
    };
    texts.forEach((name, fg) {
      for (final bg in [c.background, c.surface, c.elevated]) {
        expect(
          _contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name on $bg',
        );
      }
    });
  });

  test('on-colors reach 4.5:1 on their fills', () {
    expect(_contrast(c.onAccent, c.accentFill), greaterThanOrEqualTo(4.5));
    expect(_contrast(c.onError, c.error), greaterThanOrEqualTo(4.5));
  });

  test('ColorScheme is built from the tokens', () {
    final s = framixDarkTheme().colorScheme;
    expect(s.primary, c.accentFill);
    expect(s.onPrimary, c.onAccent);
    expect(s.secondary, c.accentText);
    expect(s.surface, c.surface);
    expect(s.onSurface, c.text);
    expect(s.onSurfaceVariant, c.textMuted);
    expect(s.surfaceContainerHighest, c.elevated);
    expect(s.error, c.error);
    expect(s.onError, c.onError);
    expect(framixDarkTheme().extension<FramixColors>(), c);
  });

  // fromSeed tints surfaces with the accent and breaks the near-neutral gray rule.
  test('no ColorScheme.fromSeed in app code', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r'fromSeed\s*\(').hasMatch(f.readAsStringSync()))
        .map((f) => f.path);
    expect(offenders, isEmpty);
  });

  test('copyWith replaces only the given tokens', () {
    const red = Color(0xFFFF0000);
    final copy = c.copyWith(accentFill: red);
    expect(copy.accentFill, red);
    expect(copy.accentText, c.accentText);
  });

  test('lerp blends every token', () {
    final other = c.copyWith(accentFill: const Color(0xFF000000));
    final mid = c.lerp(other, 0.5);
    expect(mid.accentFill, Color.lerp(c.accentFill, other.accentFill, 0.5));
    expect(mid.text, c.text);
    expect(c.lerp(null, 0.5), c);
  });
}
