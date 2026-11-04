import 'package:flutter_test/flutter_test.dart';
import 'package:framix/features/home/view/edited_label.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// P1-090 review: "yesterday" is the previous calendar day, not any time 24-48 hours ago.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 11, 4, 1, 0);
  String at(DateTime edited) => editedLabel(l10n, 'en', now, edited);

  test('25 hours ago on the previous day is yesterday', () {
    expect(at(DateTime(2026, 11, 3, 0, 0)), l10n.editedYesterday);
  });

  test('47 hours ago, two calendar days back, shows the date', () {
    expect(at(DateTime(2026, 11, 2, 2, 0)), l10n.projectEdited('Nov 2, 2026'));
  });
}
