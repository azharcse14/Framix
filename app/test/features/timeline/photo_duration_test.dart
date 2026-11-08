import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// P1-028: a selected photo's length can be given to every photo at once.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  MediaItem item(String uri, MediaKind kind) => MediaItem(
    uri: uri,
    kind: kind,
    durationValue: Int64(2000),
    durationTimescale: 1000,
    width: 1080,
    height: 1920,
    codec: 'avc1',
  );

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('a photo\'s length goes to every photo ($locale)', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          mediaImporter: FakeImporter([
            item(
              'content://media/external/images/1',
              MediaKind.MEDIA_KIND_IMAGE,
            ),
            item(
              'content://media/external/video/2',
              MediaKind.MEDIA_KIND_VIDEO,
            ),
            item(
              'content://media/external/images/3',
              MediaKind.MEDIA_KIND_IMAGE,
            ),
          ]),
          locale: locale,
        ),
      );
      await tester.tap(find.byTooltip(l10n.importFromGallery));
      await pumpUntil(tester, find.text(l10n.clipCount(3)));
      TimelineCubit cubit() =>
          tester.element(find.byType(TimelinePage)).read<TimelineCubit>();
      List<Clip> clips() => cubit().state.tracks[0].clips;
      final tps = cubit().state.ticksPerSecond.toInt();

      // A video has no photo length to share.
      await tester.tap(find.byType(ClipBox).at(1));
      await tester.pump();
      expect(find.byTooltip(l10n.applyDurationToAllPhotos), findsNothing);
      await tester.tap(find.byType(ClipBox).at(1));
      await tester.pump();

      cubit().trimClip(clips()[0], 0, tps);
      for (var i = 0; i < 100 && clips()[0].duration.toInt() != tps; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.tap(find.byType(ClipBox).first);
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.applyDurationToAllPhotos));
      for (var i = 0; i < 100 && clips()[2].duration.toInt() != tps; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        clips().map((c) => (c.start.toInt() ~/ tps, c.duration.toInt() ~/ tps)),
        // The trim left a 2 s gap after the first photo; gaps are kept.
        [(0, 1), (3, 2), (5, 1)],
      );
      expect(tester.takeException(), isNull);
    });
  }
}
