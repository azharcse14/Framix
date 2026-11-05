import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playback_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../export/export_cubit_start_test.dart' show SeededExport;
import 'import_test.dart' show FakeImporter;

/// UX-033: on a 360 dp phone, every action fits once an export is done (import x3, undo,
/// redo, export settings, export, save, share).
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets('every action fits on a 360 dp phone ($locale)', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final export = SeededExport(engine);
      addTearDown(export.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: framixDarkTheme(),
          locale: locale,
          // As FramixApp: bn needs the global Material delegates too.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepositoryProvider<MediaImporter>.value(
            value: FakeImporter(const []),
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => TimelineCubit(engine)),
                BlocProvider(create: (_) => PreviewCubit(engine)),
                BlocProvider(create: (_) => PlayheadCubit(engine)),
                BlocProvider(create: (_) => PlaybackCubit(engine)),
                BlocProvider(create: (_) => TimelineZoomCubit()),
                BlocProvider(create: (_) => ThumbnailCubit(engine)),
                BlocProvider<ExportCubit>.value(value: export),
              ],
              child: const TimelinePage(),
            ),
          ),
        ),
      );
      export.seed(const ExportDone());
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no overflow');
      final l10n = lookupAppLocalizations(locale);
      for (final tip in [
        l10n.importFromGallery,
        l10n.importFromFiles,
        l10n.addColorClip,
        l10n.undo,
        l10n.redo,
        l10n.exportSettings,
        l10n.export,
        l10n.saveToGallery,
        l10n.share,
      ]) {
        final button = find.byTooltip(tip);
        expect(button, findsOneWidget, reason: tip);
        // The IconButton's box is its touch target (the tooltip wraps only the 40 dp icon).
        final r = tester.getRect(
          find.ancestor(of: button, matching: find.byType(IconButton)),
        );
        expect(r.left >= 0 && r.right <= 360, isTrue, reason: '$tip at $r');
        expect(r.width, greaterThanOrEqualTo(48), reason: '$tip is $r');
      }
    });
  }
}
