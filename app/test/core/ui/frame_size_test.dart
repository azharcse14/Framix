import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/file_size.dart';
import 'package:framix/l10n/generated/app_localizations.dart';

// L10N-015: a resolution is one number per side, never digit-grouped, in the locale's digits.
void main() {
  test('bn frame size uses Bengali digits without grouping', () {
    final text = frameSize(
      lookupAppLocalizations(const Locale('bn')),
      1920,
      1080,
    );
    expect(text, contains('১৯২০'));
    expect(text, contains('১০৮০'));
    expect(text, isNot(contains('১,৯২০')));
  });

  test('en frame size uses Latin digits without grouping', () {
    final text = frameSize(
      lookupAppLocalizations(const Locale('en')),
      1920,
      1080,
    );
    expect(text, contains('1920'));
    expect(text, contains('1080'));
    expect(text, isNot(contains(',')));
  });
}
