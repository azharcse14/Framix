import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';

/// Lets a test put the cubit in a state the host engine cannot reach (it has no encoder).
class SeededExport extends ExportCubit {
  SeededExport(super.engine);

  void seed(ExportState s) => emit(s);
}

void main() {
  late FramixEngine engine;
  late SeededExport cubit;

  setUp(() {
    engine = FramixEngine.create();
    cubit = SeededExport(engine);
  });
  tearDown(() async {
    await cubit.close();
    engine.dispose();
  });

  test('start while an export runs is ignored', () async {
    cubit.seed(const ExportRunning(5, 10));
    // On this empty project the engine would refuse it; nothing may reach the state.
    cubit.start('/tmp/second.mp4');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(cubit.state, const ExportRunning(5, 10));
  });

  test(
    'start clears the last result, so the same failure is reported again',
    () async {
      cubit.seed(const ExportNoSpace(100, 10));
      final states = <ExportState>[];
      final sub = cubit.stream.listen(states.add);
      cubit.start('/tmp/again.mp4');
      await Future<void>.delayed(Duration.zero);
      expect(states.first, const ExportIdle());
      await sub.cancel();
    },
  );
}
