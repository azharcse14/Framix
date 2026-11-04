import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/home/bloc/home_cubit.dart';

/// Records sent commands; the test plays the engine's events.
class _FakeEngine implements FramixEngine {
  final sent = <Command>[];
  final _events = StreamController<Event>.broadcast();

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) {
    sent.add(command..id = Int64(sent.length + 1));
    return sent.length;
  }

  Future<void> emit(Event event) async {
    _events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  int idOf(bool Function(Command) test) => sent.lastWhere(test).id.toInt();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _timeline(int project) =>
    Event(timelineChanged: TimelineChanged(project: Int64(project)));

Event _failed(int id) => Event(
  commandFailed: CommandFailed(commandId: Int64(id), reason: 'x'),
);

/// P1-091: Home opens the editor only once the engine has switched projects, and one
/// tap at a time.
void main() {
  late _FakeEngine engine;
  late HomeCubit cubit;

  setUp(() async {
    engine = _FakeEngine();
    cubit = HomeCubit(engine, () async => '/data/projects');
    await Future<void>.delayed(Duration.zero);
    await engine.emit(_timeline(1));
  });
  tearDown(() => cubit.close());

  int newProjects() => engine.sent.where((c) => c.hasNewProject()).length;

  test('New project is ready when the engine starts another project', () async {
    final ready = cubit.newProject();
    await engine.emit(_timeline(1)); // an earlier command's reply, same project
    var done = false;
    unawaited(ready.then((_) => done = true));
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    await engine.emit(_timeline(2));
    expect(await ready, isTrue);
  });

  test('a refused New project or Open is not ready', () async {
    final created = cubit.newProject();
    await engine.emit(_failed(engine.idOf((c) => c.hasNewProject())));
    expect(await created, isFalse);

    final opened = cubit.open('abc');
    await engine.emit(_failed(engine.idOf((c) => c.hasOpenProject())));
    expect(await opened, isFalse);
  });

  test('a second tap before the editor closes is ignored', () async {
    final first = cubit.newProject();
    expect(await cubit.newProject(), isFalse);
    expect(await cubit.open('abc'), isFalse);
    expect(newProjects(), 1);

    await engine.emit(_timeline(2));
    expect(await first, isTrue);
    expect(await cubit.newProject(), isFalse, reason: 'the editor is open');

    cubit.refresh(); // the editor closed
    final again = cubit.newProject();
    await engine.emit(_timeline(3));
    expect(await again, isTrue);
    expect(newProjects(), 2);
  });

  test('a refused list still shows Home as unavailable', () async {
    await engine.emit(
      Event(commandAccepted: CommandAccepted(commandId: Int64(1))),
    );
    await engine.emit(_failed(engine.idOf((c) => c.hasListProjects())));
    expect(cubit.state, isA<HomeUnavailable>());
  });
}
