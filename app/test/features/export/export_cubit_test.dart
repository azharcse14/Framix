import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';

import '../../pump_until.dart';

/// Events come only from the test; each send gets the next command id (1, 2, ...).
class _Engine implements FramixEngine {
  final _events = StreamController<Event>.broadcast();
  int _id = 0;

  @override
  Stream<Event> get events => _events.stream;

  @override
  int send(Command command, {bool reportsFailure = false}) => ++_id;

  void emit(Event event) => _events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Event _accepted(int id) =>
    Event(commandAccepted: CommandAccepted(commandId: Int64(id)));

Event _refused(int id) => Event(
  commandFailed: CommandFailed(commandId: Int64(id), reason: 'busy'),
);

final _done = Event(exportFinished: ExportFinished(ok: true));

void main() {
  group('fromEvent', () {
    test('progress is running', () {
      expect(
        ExportCubit.fromEvent(
          Event(exportProgress: ExportProgress(frame: 3, frames: 90)),
        ),
        const ExportRunning(3, 90),
      );
    });

    test('finished is done, cancelled or failed', () {
      expect(
        ExportCubit.fromEvent(
          Event(exportFinished: ExportFinished(ok: true)),
          exported: '/x.mp4',
        ),
        isA<ExportDone>(),
      );
      expect(
        ExportCubit.fromEvent(
          Event(exportFinished: ExportFinished(cancelled: true)),
        ),
        isA<ExportCancelled>(),
      );
      expect(
        ExportCubit.fromEvent(
          Event(exportFinished: ExportFinished(reason: 'disk full')),
        ),
        const ExportFailed('disk full'),
      );
    });

    test('other events are not about the export', () {
      expect(
        ExportCubit.fromEvent(Event(timelineChanged: TimelineChanged())),
        isNull,
      );
      expect(
        ExportCubit.fromEvent(Event(commandFailed: CommandFailed(reason: 'x'))),
        isNull,
      );
    });
  });

  group('with the engine', () {
    late FramixEngine engine;
    late ExportCubit cubit;

    setUp(() {
      engine = FramixEngine.create();
      cubit = ExportCubit(engine);
    });
    tearDown(() async {
      await cubit.close();
      engine.dispose();
    });

    test('a refused start is failed', () async {
      // An empty project cannot be exported.
      cubit.start('/tmp/framix-test.mp4');
      final state = await waitFor(
        cubit.stream.firstWhere((s) => s is ExportFailed),
        'never failed',
      );
      expect((state as ExportFailed).reason, isNotEmpty);
    });

    test('cancel with nothing running leaves the state alone', () async {
      cubit.cancel();
      await waitForEarlierReplies(engine);
      expect(cubit.state, isA<ExportIdle>());
    });

    test('a started export that fails to open ends as failed', () async {
      engine.send(
        Command(
          importMedia: ImportMedia(
            items: [
              MediaItem(
                uri: 'content://media/external/images/1',
                kind: MediaKind.MEDIA_KIND_IMAGE,
                width: 1080,
                height: 1920,
              ),
            ],
          ),
        ),
      );
      await engine.events.firstWhere((e) => e.hasTimelineChanged());
      cubit.start('/tmp/framix-test.mp4');
      // No platform encoder in host tests: the export is accepted, then fails to open.
      final state = await waitFor(
        cubit.stream.firstWhere((s) => s is ExportFailed),
        'never failed',
      );
      expect(state, isA<ExportFailed>());
    });
  });

  /// UX-046: ExportDone shows the path of the export the engine accepted last.
  group('two exports in a row', () {
    late _Engine engine;
    late ExportCubit cubit;

    setUp(() {
      engine = _Engine();
      cubit = ExportCubit(engine);
    });
    tearDown(() => cubit.close());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    /// Export 1 to /plat/a.mp4 (command id 1), accepted and finished.
    Future<void> firstDone() async {
      cubit.start('/plat/a.mp4');
      engine
        ..emit(_accepted(1))
        ..emit(_done);
      await settle();
      expect(cubit.state, const ExportDone('/plat/a.mp4'));
    }

    test('the second accepted export is done at the second path', () async {
      await firstDone();
      cubit.start('/plat/b.mp4');
      engine
        ..emit(_accepted(2))
        ..emit(_done);
      await settle();
      expect(cubit.state, const ExportDone('/plat/b.mp4'));
    });

    test('a refused second export never points at its path', () async {
      await firstDone();
      cubit.start('/plat/b.mp4');
      engine.emit(_refused(2));
      await settle();
      expect(cubit.state, const ExportFailed('busy'));

      // A stray finish after the refusal is not about the refused file.
      engine.emit(_done);
      await settle();
      expect(cubit.state, isNot(const ExportDone('/plat/b.mp4')));
    });
  });
}
