import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/ui/timecode.dart';

// L10N-018: timecodes and ruler labels use the locale's digits, as every other number does.
void main() {
  test('bn timecode uses Bengali digits', () {
    expect(timecode(5 * 30 + 15, 30, 'bn'), '০০:০৫.৫০');
  });

  test('en timecode stays Latin', () {
    expect(timecode(5 * 30 + 15, 30, 'en'), '00:05.50');
  });

  test('a timecode without a time base uses the locale digits too', () {
    expect(timecode(0, 0, 'bn'), '০০:০০.০০');
  });

  test('bn ruler label uses Bengali digits', () {
    expect(rulerLabel(65.5, 'bn'), '১:০৫.৫');
    expect(rulerLabel(5, 'bn'), '০:০৫');
  });

  test('en ruler label stays Latin', () {
    expect(rulerLabel(65.5, 'en'), '1:05.5');
    expect(rulerLabel(5, 'en'), '0:05');
  });
}
