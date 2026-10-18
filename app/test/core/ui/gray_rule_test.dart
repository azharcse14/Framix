import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/framix_theme.dart';

void main() {
  // docs/design-system.md: grays are near-neutral, red = green and blue at most +12 (a slight
  // cool bias), so they never tint the user's colors.
  test('every gray token follows the near-neutral rule', () {
    const c = FramixColors.dark;
    // Add every new gray token here (and the light theme's grays when it exists).
    final grays = {
      'background': c.background,
      'surface': c.surface,
      'elevated': c.elevated,
      'border': c.border,
      'outline': c.outline,
      'textMuted': c.textMuted,
      'text': c.text,
    };
    int channel(double v) => (v * 255).round();
    grays.forEach((name, color) {
      final (r, g, b) = (channel(color.r), channel(color.g), channel(color.b));
      expect(r, g, reason: '$name: red = green');
      expect(b - r, inInclusiveRange(0, 12), reason: '$name: blue bias');
    });
  });
}
