import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/ui/file_size.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:framix/main.dart';
import 'package:material_ui/material_ui.dart';

import '../../pump_until.dart';

/// P1-110: the settings sheet shows the engine's size estimate formatted as Home shows sizes.
void main() {
  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('the estimate uses the shared size format ($locale)', (
      tester,
    ) async {
      final engine = FramixEngine.create();
      addTearDown(engine.dispose);
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(FramixApp(engine: engine, locale: locale));
      ExportInfo export() => tester
          .element(find.byType(TimelinePage))
          .read<TimelineCubit>()
          .state
          .export;
      // An empty timeline lasts 0 and estimates 0 bytes; one photo gives it a length.
      engine.send(
        Command(
          importMedia: ImportMedia(
            items: [
              MediaItem(
                uri: 'media/a.jpg',
                kind: MediaKind.MEDIA_KIND_IMAGE,
                width: 10,
                height: 10,
              ),
            ],
          ),
        ),
      );
      await pumpUntilTrue(
        tester,
        () => export().estimatedBytes > 0,
        () => 'no estimate',
      );
      final bytes = export().estimatedBytes.toInt();
      expect(bytes, greaterThan(0));

      await tester.tap(find.byTooltip(l10n.exportSettings));
      await pumpUntil(tester, find.text(l10n.exportResolution4k));
      expect(
        find.text(l10n.exportEstimate(fileSize(l10n, '$locale', bytes))),
        findsOneWidget,
      );
    });
  }
}
