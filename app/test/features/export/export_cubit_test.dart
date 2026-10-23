import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';

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
        ExportCubit.fromEvent(Event(exportFinished: ExportFinished(ok: true))),
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
      final state = await cubit.stream
          .firstWhere((s) => s is ExportFailed)
          .timeout(const Duration(seconds: 5));
      expect((state as ExportFailed).reason, isNotEmpty);
    });

    test('cancel with nothing running leaves the state alone', () async {
      cubit.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 200));
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
      final state = await cubit.stream
          .firstWhere((s) => s is ExportFailed)
          .timeout(const Duration(seconds: 5));
      expect(state, isA<ExportFailed>());
    });
  });
}
