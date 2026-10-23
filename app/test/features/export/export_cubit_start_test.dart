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
}
