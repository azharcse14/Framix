import 'package:material_ui/material_ui.dart';

/// Design tokens (docs/design-system.md). Widgets read colors from here, never hex.
@immutable
class FramixColors extends ThemeExtension<FramixColors> {
  const FramixColors({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.outline,
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
    outline: Color(0xFF6C6C75),
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

  /// Boundary of interactive controls (outlined button, chip, canvas edge); 3:1 on
  /// background, surface and elevated. [border] is for decorative dividers only.
  final Color outline;
  final Color textMuted;
  final Color text;
  final Color accentFill;
  final Color accentText;
  final Color onAccent;
  final Color error;
  final Color onError;

  /// The tokens of the current theme; [framixDarkTheme] always installs them.
  static FramixColors of(BuildContext context) =>
      Theme.of(context).extension<FramixColors>() ?? dark;

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
      outline: c.outline,
      outlineVariant: c.border,
      surfaceContainerHighest: c.elevated,
    ),
    scaffoldBackgroundColor: c.background,
    // Accent belongs to the one primary action; secondary actions stay neutral.
    // M3 chips edge unselected chips with outlineVariant (the divider border); a chip is a
    // control, so use the 3:1 outline. Selected stays transparent, disabled keeps M3's side.
    chipTheme: ChipThemeData(
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.selected)) {
          return const BorderSide(color: Colors.transparent);
        }
        return BorderSide(color: c.outline);
      }),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      // Outline comes from ColorScheme.outline (outline token), keeping the M3 disabled side.
      style: OutlinedButton.styleFrom(foregroundColor: c.text),
    ),
    extensions: const [c],
  );
}
