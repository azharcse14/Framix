import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';

/// Wall-clock wait for an engine reply. Generous on purpose: a reply that writes the library
/// (atomic save: two fsyncs, which on macOS are F_FULLFSYNC and flush the whole disk) took
/// 0.8-2.5 s while other builds loaded the machine, against ~5 ms idle (P1-108). A count of
/// pumps is not a budget: under load each 20 ms delay takes longer.
const replyBudget = Duration(seconds: 10);

/// Pumps until [done], giving real time between pumps: engine events arrive through a
/// native port, outside the fake clock. [what] is built only on failure: a finder like
/// `.at(1)` throws in toString while it finds too little.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  bool Function() done,
  String Function() what,
) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < replyBudget) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (done()) return;
  }
  throw TestFailure(what());
}

/// Pumps until [finder] finds something.
Future<void> pumpUntil(WidgetTester tester, Finder finder) => pumpUntilTrue(
  tester,
  () => finder.evaluate().isNotEmpty,
  () => 'never found: $finder',
);

/// Pumps until [finder] finds nothing.
Future<void> pumpUntilGone(WidgetTester tester, Finder finder) => pumpUntilTrue(
  tester,
  () => finder.evaluate().isEmpty,
  () => 'still found: $finder',
);

/// Stops [engine] and pumps until its EngineStopped: the engine autosaves on shutdown and
/// closes [FramixEngine.events] only after that write, so its library dir can go then. For
/// a test's own `addTearDown`, which runs before the binding's: its events still arrive
/// through the fake clock, so a bare `events.drain()` there never completes.
Future<void> stopEngine(WidgetTester tester, FramixEngine engine) async {
  var stopped = false;
  engine.events.listen(null, onDone: () => stopped = true);
  engine.dispose();
  await pumpUntilTrue(tester, () => stopped, () => 'engine never stopped');
}
