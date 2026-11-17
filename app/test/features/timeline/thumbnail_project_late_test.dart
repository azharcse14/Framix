import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import '../../pump_until.dart';

MediaItem _video() => MediaItem(
  uri: 'content://media/external/video/1',
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(4000),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

/// P1-062 review: the thumbnail cubit is made lazily, after the first TimelineChanged, and
/// tiles of a new project with the same layout must still ask again.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<TimelineChanged> importOne() async {
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(Command(importMedia: ImportMedia(items: [_video()])));
    return (await imported).timelineChanged;
  }

  test(
    'a cubit made after the import still starts over on a new project',
    () async {
      final t = await importOne();
      final media = t.tracks.first.clips.first.mediaId.toInt();
      final cubit = ThumbnailCubit(engine, project: t.project.toInt());
      final failed = <int>[];
      final counting = engine.events
          .where((e) => e.hasCommandFailed())
          .listen((e) => failed.add(e.commandFailed.commandId.toInt()));
      cubit.request(media, [0], 96);
      failed.remove(await waitForEarlierReplies(engine));
      expect(failed, hasLength(1));

      final fresh = engine.events.firstWhere((e) => e.hasTimelineChanged());
      engine.send(Command(newProject: NewProject()));
      await fresh;
      final again = (await importOne()).tracks.first.clips.first.mediaId
          .toInt();
      cubit.request(again, [0], 96);
      failed.remove(await waitForEarlierReplies(engine));
      expect(failed, hasLength(2));
      await counting.cancel();
      await cubit.close();
    },
  );

  testWidgets('tiles of a reopened project with the same layout ask again', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(engine: engine, mediaImporter: FakeImporter([_video()])),
    );
    // The host engine has no platform: every thumbnail ask that goes out fails.
    final asks = <int>[];
    final counting = engine.events
        .where((e) => e.hasCommandFailed())
        .listen((e) => asks.add(e.commandFailed.commandId.toInt()));

    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ThumbnailTile));
    // Every first-round failure is in before the count is taken, also on a starved machine
    // (SYS-067).
    asks.remove(await pumpUntilEarlierReplies(tester, engine));
    final first = asks.length;
    expect(first, greaterThan(0));

    // Reopen the same project: same media ids and slots, but the engine dropped its
    // thumbnails, so the tiles must ask again.
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('framix-reopen'),
    );
    final path = '${dir!.path}/p.framix';
    engine.send(Command(saveProject: SaveProject(path: path)));
    asks.remove(await pumpUntilEarlierReplies(tester, engine));
    engine.send(Command(openProject: OpenProject(path: path)));
    // Wait for the new ask with a deadline: a loaded machine answers late.
    await pumpUntilTrue(
      tester,
      () => asks.length > first,
      () => 'never asked again',
    );
    await tester.runAsync(() => dir.delete(recursive: true));
    expect(
      asks.length,
      greaterThan(first),
      reason: 'the same slots ask the new project',
    );
    // Off the fake clock: the engine stream's cancel completes on the real event loop.
    await tester.runAsync(counting.cancel);
  });
}
