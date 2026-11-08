import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// P1-081: a trim right after a frame step uses the engine's playhead, not the UI's stale copy.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  testWidgets('step back then trim at once trims to the stepped frame', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(2000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.text(l10n.clipCount(1)));
    BuildContext page() => tester.element(find.byType(TimelinePage));
    final tps = page().read<TimelineCubit>().state.ticksPerSecond.toInt();
    final frame = tps ~/ 30;
    Clip clip() => page().read<TimelineCubit>().state.tracks[0].clips[0];

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    page().read<PlayheadCubit>().seek(tps);
    await until(() => page().read<PlayheadCubit>().state == tps);
    await tester.tap(find.byType(ClipBox));
    await tester.pump();

    // No wait between the taps: the UI still shows the old playhead.
    await tester.tap(find.byTooltip(l10n.previousFrame));
    await tester.tap(find.byTooltip(l10n.trimStartToPlayhead));
    await until(() => clip().start.toInt() != 0);
    await until(() => page().read<PlayheadCubit>().state == tps - frame);
    expect(clip().start.toInt(), tps - frame);
    expect(tester.takeException(), isNull);
  });
}
