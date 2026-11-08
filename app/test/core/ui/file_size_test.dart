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

  test('a rounding that reaches 1000 steps up a unit', () {
    String size(int bytes) => fileSize(en, 'en', bytes);
    expect(size(999499), '999 KB');
    expect(size(999500), '1 MB');
    expect(size(999999), '1 MB');
    expect(size(999999999), '1 GB');
    expect(fileSize(en, 'en', 999001, rounding: SizeRounding.up), '1 MB');
  });

  test('up and down round at the shown precision', () {
    String up(int bytes) =>
        fileSize(en, 'en', bytes, rounding: SizeRounding.up);
    String down(int bytes) =>
        fileSize(en, 'en', bytes, rounding: SizeRounding.down);
    expect(up(400600000), '401 MB');
    expect(down(400500000), '400 MB');
    expect(down(400999999), '400 MB');
    expect(up(400000000), '400 MB');
    expect(up(1410000), '1.5 MB');
    expect(down(1490000), '1.4 MB');
    expect(down(999999), '999 KB');
    expect(up(1001), '1.1 KB');
    expect(down(2300000), '2.3 MB');
  });

  test('tenths that round up to 10 drop the decimal', () {
    expect(fileSize(en, 'en', 9950000, rounding: SizeRounding.up), '10 MB');
  });

  test('bn uses its own digits', () {
    expect(fileSize(bn, 'bn', 1500000), '১.৫ MB');
    expect(fileSize(bn, 'bn', 5), '৫ বাইট');
  });
}
