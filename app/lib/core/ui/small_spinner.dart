import 'package:material_ui/material_ui.dart';

/// A thin spinner in an icon's place while a button's work runs (import, export, opening a
/// project). Sized by the surrounding [IconTheme], so it fits wherever the icon did.
class SmallSpinner extends StatelessWidget {
  const SmallSpinner({
    super.key,
    required this.label,
    this.value,
    this.iconColor = false,
  });

  /// What a screen reader announces.
  final String label;

  /// Progress from 0 to 1; null spins without one.
  final double? value;

  /// Use the icon color instead of the theme's primary, e.g. on an accent-filled button
  /// where primary would not show.
  final bool iconColor;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    return SizedBox.square(
      dimension: icon.size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: value,
        color: iconColor ? icon.color : null,
        semanticsLabel: label,
      ),
    );
  }
}
