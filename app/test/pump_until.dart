import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';

/// How long to wait for an engine reply, counted in polls of at least 20 ms real time each.
/// Generous on purpose: a reply that writes the library (atomic save: two fsyncs, which on
/// macOS are F_FULLFSYNC and flush the whole disk) took 0.8-2.5 s while other builds loaded
/// the machine, against ~5 ms idle (P1-108).
const replyBudget = Duration(seconds: 10);

/// Real time between two pumps.
const _poll = Duration(milliseconds: 20);

/// Runs [poll] until [done], at most [budget], and fails with [what] (built only on failure).
///
/// [budget] is spent in polls, not wall time: each [poll] takes at least 20 ms, so the wait is
/// never shorter than [budget], and a poll the OS delays (check.sh next to other builds, a
/// cold JIT of Home and the editor) still costs one poll. A wall-clock budget ran out while
/// the test process barely ran (SYS-052, SYS-054).
Future<void> _pollUntil(
  Future<void> Function() poll,
  bool Function() done,
  String Function() what,
  Duration budget,
) async {
  final polls = budget.inMicroseconds ~/ _poll.inMicroseconds;
  for (var i = 0; i < polls; i++) {
    await poll();
    if (done()) return;
  }
  throw TestFailure(what());
}

/// Pumps until [done], giving real time between pumps: engine events arrive through a
/// native port, outside the fake clock. [what] is built only on failure: a finder like
/// `.at(1)` throws in toString while it finds too little.
Future<void> pumpUntilTrue(
  WidgetTester tester,
  bool Function() done,
  String Function() what, {
  Duration budget = replyBudget,
}) => _pollUntil(
  () async {
    await tester.runAsync(() => Future<void>.delayed(_poll));
    await tester.pump();
  },
  done,
  what,
  budget,
);

/// [pumpUntilTrue] for a plain `test`, which has no WidgetTester: waits in real time.
Future<void> waitUntilTrue(
  bool Function() done,
  String Function() what, {
  Duration budget = replyBudget,
}) => _pollUntil(() => Future<void>.delayed(_poll), done, what, budget);

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
