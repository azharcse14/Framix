import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';

/// Wall-clock wait for an engine reply. Generous on purpose: a reply that writes the library
/// (atomic save: two fsyncs, which on macOS are F_FULLFSYNC and flush the whole disk) took
/// 0.8-2.5 s while other builds loaded the machine, against ~5 ms idle (P1-108). A count of
/// pumps alone is not a budget: a slow disk keeps each 20 ms delay at 20 ms.
const replyBudget = Duration(seconds: 10);

/// Real time between two pumps.
const _poll = Duration(milliseconds: 20);

/// Pumps until [done], giving real time between pumps: engine events arrive through a
/// native port, outside the fake clock. [what] is built only on failure: a finder like
/// `.at(1)` throws in toString while it finds too little.
///
/// Gives up once both [budget] and [budget]'s worth of polls are used. Wall time alone runs
/// out while the OS barely runs the test process (check.sh next to other builds, SYS-052):
/// the first test of a file JIT-compiles Home and the editor, ~2.5 s under moderate load,
/// and a stalled machine stretched that past 10 s. Polls only advance while the test runs.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  bool Function() done,
  String Function() what, {
  Duration budget = replyBudget,
}) async {
  final clock = Stopwatch()..start();
  final polls = budget.inMicroseconds ~/ _poll.inMicroseconds;
  for (var i = 0; clock.elapsed < budget || i < polls; i++) {
    await tester.runAsync(() => Future<void>.delayed(_poll));
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
