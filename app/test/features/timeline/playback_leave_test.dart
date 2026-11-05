import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/features/timeline/view/timeline_view.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import 'import_test.dart' show FakeImporter;
import 'timeline_page_test.dart' show pumpUntil;

/// P1-061 review: leaving the editor stops playback, so the engine doesn't play on unseen.
void main() {
  testWidgets('going back from the editor pauses', (tester) async {
    final engine = FramixEngine.create();
    addTearDown(engine.dispose);
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.pumpWidget(
      FramixApp(
        engine: engine,
        locale: const Locale('en'),
        mediaImporter: FakeImporter([
          MediaItem(
            uri: 'content://media/external/video/1',
            kind: MediaKind.MEDIA_KIND_VIDEO,
            durationValue: Int64(60000),
            durationTimescale: 1000,
            width: 1080,
            height: 1920,
            codec: 'avc1',
          ),
        ]),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TimelinePage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.importFromGallery));
    await pumpUntil(tester, find.byType(ClipBox));
    await tester.tap(find.byTooltip(l10n.play));
    await pumpUntil(tester, find.byTooltip(l10n.pause));

    final playback = tester
        .element(find.byType(TimelinePage))
        .read<PlaybackCubit>();
    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 100 && playback.state; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(playback.state, isFalse);
  });
}
