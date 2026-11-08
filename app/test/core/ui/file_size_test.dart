import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/file_size.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// P1-110: one size format for Home and Export, 1000-based like the iOS and Android storage screens.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final bn = lookupAppLocalizations(const Locale('bn'));

  test('1000 steps, one decimal under 10', () {
    String size(int bytes) => fileSize(en, 'en', bytes);
    expect(size(0), '0 B');
    expect(size(999), '999 B');
    expect(size(1000), '1 KB');
    expect(size(2048), '2 KB');
    expect(size(1500000), '1.5 MB');
    expect(size(12345678), '12 MB');
    expect(size(2500000001), '2.5 GB');
  });

  test('bn uses its own digits', () {
    expect(fileSize(bn, 'bn', 1500000), '১.৫ MB');
    expect(fileSize(bn, 'bn', 5), '৫ বাইট');
  });
}
