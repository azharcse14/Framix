import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final (hi, lo) = a.computeLuminance() > b.computeLuminance()
      ? (a.computeLuminance(), b.computeLuminance())
      : (b.computeLuminance(), a.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const c = FramixColors.dark;

  test('control outlines reach 3:1 on every surface (design-system.md)', () {
    for (final bg in [c.background, c.surface, c.elevated]) {
      expect(
        _contrast(c.outline, bg),
        greaterThanOrEqualTo(3.0),
        reason: '$bg',
      );
    }
  });

  test('ColorScheme uses outline for controls and border for dividers', () {
    final scheme = framixDarkTheme().colorScheme;
    expect(scheme.outline, c.outline);
    expect(scheme.outlineVariant, c.border);
  });
}
