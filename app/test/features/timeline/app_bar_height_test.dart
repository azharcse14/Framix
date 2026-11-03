import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/framix_engine.dart';
import 'package:framix/core/media/media_importer.dart';
import 'package:framix/core/ui/framix_theme.dart';
import 'package:framix/features/export/view/export_buttons.dart';
import 'package:framix/features/export/bloc/export_cubit.dart';
import 'package:framix/features/preview/bloc/preview_cubit.dart';
import 'package:framix/features/timeline/bloc/playhead_cubit.dart';
import 'package:framix/features/timeline/bloc/thumbnail_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_cubit.dart';
import 'package:framix/features/timeline/bloc/timeline_zoom_cubit.dart';
import 'package:framix/features/timeline/view/timeline_page.dart';
import 'package:framix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../export/export_cubit_start_test.dart' show SeededExport;
import 'import_test.dart' show FakeImporter;

/// UX-033 review: the actions fit without taking timeline height (no second app bar row),
/// and the export buttons keep their state when the window crosses a size boundary.
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<SeededExport> pumpPage(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final export = SeededExport(engine);
    addTearDown(export.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        locale: const Locale('en'),
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
    return export;
  }

  testWidgets('a 360 dp phone keeps a one-row app bar', (tester) async {
    await pumpPage(tester, const Size(360, 740));
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  testWidgets('the export buttons keep their state across 600 dp', (
    tester,
  ) async {
    await pumpPage(tester, const Size(360, 740));
    final before = tester.state(find.byType(ExportButtons));
    tester.view.physicalSize = const Size(800, 740);
    await tester.pump();
    expect(tester.state(find.byType(ExportButtons)), same(before));
  });
}
