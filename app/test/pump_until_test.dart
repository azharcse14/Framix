import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'pump_until.dart';

/// pumpUntilTrue's budget (SYS-052).
void main() {
  const budget = Duration(milliseconds: 200);

  testWidgets('a starved test process still gets its polls', (tester) async {
    var polls = 0;
    await pumpUntilTrue(
      tester,
      () {
        // Stands in for a test process the OS barely runs (check.sh next to other builds):
        // wall time passes while the test gets nothing done, here 3 polls' worth of budget.
        sleep(const Duration(milliseconds: 60));
        return ++polls == 8;
      },
      () => 'gave up after $polls polls',
      budget: budget,
    );
  });

  testWidgets('a reply that never comes still fails', (tester) async {
    await expectLater(
      pumpUntilTrue(tester, () => false, () => 'never', budget: budget),
      throwsA(isA<TestFailure>()),
    );
  });
}
