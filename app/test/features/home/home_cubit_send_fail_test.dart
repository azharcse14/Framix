import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/bloc/home_cubit.dart';

/// Fails the next send once [failNext] is set, like a refused engine_send.
class _FlakyEngine implements FramixEngine {
  final sent = <Command>[];
  final _events = StreamController<Event>.broadcast();
  bool failNext = false;

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    if (failNext) {
      failNext = false;
      throw StateError('engine_send failed');
    }
    sent.add(command..id = Int64(sent.length + 1));
    return sent.length;
  }

  Future<void> emit(Event event) async {
    _events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// P1-091 review: a send that throws must not leave Home ignoring every later tap.
void main() {
  test('after a failed send, the next tap works', () async {
    final engine = _FlakyEngine();
    final cubit = HomeCubit(engine, () async => '/data/projects');
    await Future<void>.delayed(Duration.zero);

    engine.failNext = true;
    await expectLater(cubit.newProject(), throwsStateError);

    final again = cubit.newProject();
    expect(engine.sent.where((c) => c.hasNewProject()), hasLength(1));
    await engine.emit(
      Event(timelineChanged: TimelineChanged(project: Int64(2))),
    );
    expect(await again, isTrue);

    await cubit.close();
  });

  test('closing twice while waiting does not throw', () async {
    final engine = _FlakyEngine();
    final cubit = HomeCubit(engine, () async => '/data/projects');
    await Future<void>.delayed(Duration.zero);
    final waiting = cubit.newProject();
    await cubit.close();
    await cubit.close();
    expect(await waiting, isFalse);
  });
}
