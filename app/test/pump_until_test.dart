import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';

import 'pump_until.dart';

/// An engine that answers each command in order, late: 4 polls of real waiting, while the
/// test process stalls 100 ms before each (480 ms of wall time per reply).
class _StarvedEngine implements FramixEngine {
  final _events = StreamController<Event>.broadcast();
  var _lastId = 0;
  var _answered = Future<void>.value();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    final id = ++_lastId;
    _answered = _answered.then((_) async {
      for (var i = 0; i < 4; i++) {
        sleep(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      _events.add(Event(commandFailed: CommandFailed(commandId: Int64(id))));
    });
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// pumpUntilTrue's, waitUntilTrue's and waitFor's budget (SYS-052, SYS-054, SYS-056), and
/// waitForEarlierReplies' bound (SYS-060).
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

  test('waitUntilTrue: a starved test process still gets its polls', () async {
    var polls = 0;
    await waitUntilTrue(
      () {
        // As above, for a plain test without a WidgetTester (SYS-054).
        sleep(const Duration(milliseconds: 60));
        return ++polls == 8;
      },
      () => 'gave up after $polls polls',
      budget: budget,
    );
  });

  test('waitUntilTrue: a reply that never comes still fails', () async {
    await expectLater(
      waitUntilTrue(() => false, () => 'never', budget: budget),
      throwsA(isA<TestFailure>()),
    );
  });

  test('waitFor: a starved test process still gets its reply', () async {
    // A reply that takes 4 polls of real waiting, while the test process stalls 100 ms
    // before each: 480 ms of wall time against a 200 ms budget (SYS-056).
    Future<int> reply() async {
      for (var i = 0; i < 4; i++) {
        sleep(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return 7;
    }

    expect(await waitFor(reply(), 'no reply', budget: budget), 7);
  });

  test('waitFor: a reply that never comes still fails', () async {
    await expectLater(
      waitFor(Completer<int>().future, 'never', budget: budget),
      throwsA(isA<TestFailure>()),
    );
  });

  test('waitFor: a failed reply rethrows its error', () async {
    await expectLater(
      waitFor(
        Future<int>.error(StateError('refused')),
        'never',
        budget: budget,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('waitForEarlierReplies: a starved engine has answered every earlier '
      'command, also one sent at the end of this turn', () async {
    // A fixed 300 ms wait saw none of these replies (SYS-060).
    final engine = _StarvedEngine();
    final answered = <int>[];
    final listening = engine.events.listen(
      (e) => answered.add(e.commandFailed.commandId.toInt()),
    );
    final first = engine.send(Command());
    late final int batched;
    // Like ThumbnailCubit, which sends its asks in a microtask.
    scheduleMicrotask(() => batched = engine.send(Command()));

    final sentinel = await waitForEarlierReplies(engine);
    expect(answered, [first, batched, sentinel]);
    await listening.cancel();
  });
}
