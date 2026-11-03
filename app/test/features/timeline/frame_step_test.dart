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
import 'timeline_page_test.dart' show pumpUntil;

/// P1-025: step the playhead one frame at a time, and trim a clip's edge to it.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('frame steps and trims to the playhead ($locale)', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(locale);
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
          locale: locale,
        ),
      );
      await tester.tap(find.byTooltip(l10n.importFromGallery));
      await pumpUntil(tester, find.text(l10n.clipCount(1)));
      BuildContext page() => tester.element(find.byType(TimelinePage));
      final tps = page().read<TimelineCubit>().state.ticksPerSecond.toInt();
      // The default export rate is 30 fps.
      final frame = tps ~/ 30;
      Clip clip() => page().read<TimelineCubit>().state.tracks[0].clips[0];

      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 100 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(done(), isTrue);
      }

      int playhead() => page().read<PlayheadCubit>().state;

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip(l10n.nextFrame));
        await until(() => playhead() == (i + 1) * frame);
      }
      await tester.tap(find.byTooltip(l10n.previousFrame));
      await until(() => playhead() == 2 * frame);

      await tester.tap(find.byType(ClipBox));
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.trimStartToPlayhead));
      await until(() => clip().start.toInt() == 2 * frame);
      expect(clip().duration.toInt(), 2 * tps - 2 * frame);

      await tester.tap(find.byTooltip(l10n.nextFrame));
      await until(() => playhead() == 3 * frame);
      await tester.tap(find.byTooltip(l10n.trimEndToPlayhead));
      await until(() => clip().duration.toInt() == frame);
      expect(tester.takeException(), isNull);
    });
  }
}
