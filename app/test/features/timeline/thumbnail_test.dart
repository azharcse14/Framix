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
import 'timeline_page_test.dart' show pumpUntil;

MediaItem _video(int ms) => MediaItem(
  uri: 'content://media/external/video/1',
  kind: MediaKind.MEDIA_KIND_VIDEO,
  durationValue: Int64(ms),
  durationTimescale: 1000,
  width: 1080,
  height: 1920,
  codec: 'avc1',
);

void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  test('a time already asked for is not sent again', () async {
    final cubit = ThumbnailCubit(engine);
    final imported = engine.events.firstWhere((e) => e.hasTimelineChanged());
    engine.send(Command(importMedia: ImportMedia(items: [_video(4000)])));
    final media = (await imported)
        .timelineChanged
        .tracks
        .first
        .clips
        .first
        .mediaId
        .toInt();

    // The host engine has no platform, so each request that goes out fails.
    var replies = 0;
    final counting = engine.events
        .where((e) => e.hasCommandFailed())
        .listen((_) => replies++);
    cubit
      ..request(media, [0], 96)
      ..request(media, [0], 96);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(replies, 1);
    await counting.cancel();
    await cubit.close();
  });

  testWidgets('clips show thumbnail slots; zooming in shows more', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        mediaImporter: FakeImporter([_video(4000)]),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ThumbnailTile));
    final before = find.byType(ThumbnailTile).evaluate().length;
    expect(before, greaterThan(0));

    await tester.tap(find.byTooltip(l10n.zoomIn));
    await tester.pump();
    expect(find.byType(ThumbnailTile).evaluate().length, greaterThan(before));
  });
}
