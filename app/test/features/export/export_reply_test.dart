import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';

/// ExportCubit takes only the reply to its own ExportProject (ENG-056).
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  test('send numbers commands and the reply carries the number', () async {
    final reply = engine.events.firstWhere((e) => e.hasCommandFailed());
    final id = engine.send(Command(removeClip: RemoveClip(clipId: Int64(999))));
    expect((await reply).commandFailed.commandId.toInt(), id);
    expect(
      engine.send(Command(removeClip: RemoveClip(clipId: Int64(998)))),
      id + 1,
    );
  });

  test("another command's failure is not taken as the export's", () async {
    final cubit = ExportCubit(engine);
    addTearDown(cubit.close);
    // Sent first, so its failure arrives while the export waits for its own reply.
    engine.send(Command(removeClip: RemoveClip(clipId: Int64(999))));
    cubit.start('/tmp/a.mp4');
    final failed = await cubit.stream.firstWhere((s) => s is ExportFailed);
    // This host engine cannot export: that is the export's own reason.
    expect((failed as ExportFailed).reason, contains('export'));
  });
}
