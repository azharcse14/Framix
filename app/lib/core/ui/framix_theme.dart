import 'package:material_ui/material_ui.dart';

/// Design tokens (docs/design-system.md). Widgets read colors from here, never hex.
@immutable
class FramixColors extends ThemeExtension<FramixColors> {
  const FramixColors({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.textMuted,
    required this.text,
    required this.accentFill,
    required this.accentText,
    required this.onAccent,
    required this.error,
    required this.onError,
  });

  /// Dark tokens; the Editor is always dark.
  static const dark = FramixColors(
    background: Color(0xFF0E0E11),
    surface: Color(0xFF17171B),
    elevated: Color(0xFF222228),
    border: Color(0xFF2E2E36),
    textMuted: Color(0xFF9A9AA5),
    text: Color(0xFFF4F4F6),
    accentFill: Color(0xFF6E4CF5),
    accentText: Color(0xFFA271FF),
    onAccent: Color(0xFFFFFFFF),
    // Provisional: the plan only says "red". 5.7:1 on elevated; finalize in DS-003.
    error: Color(0xFFFF6B6B),
    onError: Color(0xFF0E0E11),
  );

  final Color background;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color textMuted;
  final Color text;
  final Color accentFill;
  final Color accentText;
  final Color onAccent;
  final Color error;
  final Color onError;

  @override
  FramixColors copyWith() => this;

  @override
  FramixColors lerp(FramixColors? other, double t) =>
      t < 0.5 ? this : other ?? this;
}

/// Spacing tokens.
abstract final class FramixSpace {
  static const double s = 8;
  static const double m = 16;
}

/// The dark theme: ColorScheme built by hand from the tokens (no fromSeed).
ThemeData framixDarkTheme() {
  const c = FramixColors.dark;
  return ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: c.accentFill,
      onPrimary: c.onAccent,
      secondary: c.accentText,
      onSecondary: c.background,
      error: c.error,
      onError: c.onError,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      outline: c.border,
      surfaceContainerHighest: c.elevated,
    ),
    scaffoldBackgroundColor: c.background,
    // Accent belongs to the one primary action; secondary actions stay neutral.
    outlinedButtonTheme: OutlinedButtonThemeData(
      // Outline comes from ColorScheme.outline (border), keeping the M3 disabled side.
      style: OutlinedButton.styleFrom(foregroundColor: c.text),
    ),
    extensions: const [c],
  );
}
