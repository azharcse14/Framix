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
import 'timeline_page_test.dart' show pumpUntil;

/// Color (blank) clips (P1-048): one tap adds a black clip; the engine owns it like a photo.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('the color clip button adds a black clip ($locale)', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        FramixApp(
          engine: engine,
          mediaImporter: FakeImporter(const []),
          locale: locale,
        ),
      );
      await tester.tap(find.byTooltip(l10n.addColorClip));
      await pumpUntil(tester, find.text(l10n.clipCount(1)));
      final clip = tester
          .element(find.byType(TimelinePage))
          .read<TimelineCubit>()
          .state
          .tracks[0]
          .clips[0];
      expect(clip.mediaKind, MediaKind.MEDIA_KIND_COLOR);
      expect(clip.color, 0x000000ff);
      // No thumbnails: the clip shows its own color.
      expect(find.byType(ThumbnailTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
