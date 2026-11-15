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
import 'package:framix/features/timeline/view/aspect_ratio_bar.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/app_delegates.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../timeline/import_test.dart' show FakeImporter;
import '../../pump_until.dart';

/// UX-035: where the engine refuses CreatePreview (the test host registers no preview), the
/// canvas says the preview is unavailable instead of showing a bare outline.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<void> pumpPage(WidgetTester tester, Locale locale, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
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
              BlocProvider(create: (_) => ExportCubit(engine)),
            ],
            child: const TimelinePage(),
          ),
        ),
      ),
    );
  }

  for (final (locale, size) in [
    (const Locale('en'), const Size(360, 740)),
    (const Locale('bn'), const Size(360, 740)),
    (const Locale('bn'), const Size(640, 360)),
  ]) {
    testWidgets('a refused preview says so in the canvas ($locale, $size)', (
      tester,
    ) async {
      await pumpPage(tester, locale, size);
      final message = lookupAppLocalizations(locale).previewUnavailable;
      await pumpUntil(
        tester,
        find.descendant(
          of: find.byType(CanvasOutline),
          matching: find.text(message),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
