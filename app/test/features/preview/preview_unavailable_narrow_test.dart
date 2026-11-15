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

/// UX-035 re-review: a canvas too narrow for the "preview unavailable" text (9:16 on a phone)
/// shows only the icon, and a screen reader hears the message once (label, no tooltip).
void main() {
  late FramixEngine engine;

  setUp(() => engine = FramixEngine.create());
  tearDown(() => engine.dispose());

  Future<void> pumpPage(
    WidgetTester tester,
    Locale locale,
    Size size,
    double textScale,
  ) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timeline = TimelineCubit(engine);
    addTearDown(timeline.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: framixDarkTheme(),
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: RepositoryProvider<MediaImporter>.value(
          value: FakeImporter(const []),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<TimelineCubit>.value(value: timeline),
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
    timeline.setAspectRatio(9, 16);
  }

  testWidgets('a narrow canvas shows one icon, read once', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester, const Locale('en'), const Size(360, 740), 1);
    final message = lookupAppLocalizations(const Locale('en'))
        .previewUnavailable;
    Finder inCanvas(Finder f) =>
        find.descendant(of: find.byType(CanvasOutline), matching: f);
    final icon = inCanvas(find.byType(Icon));
    await pumpUntil(tester, icon);
    expect(icon, findsOneWidget);
    expect(inCanvas(find.text(message)), findsNothing);
    final node = tester.getSemantics(icon);
    expect(node.label, message);
    expect(node.tooltip, isEmpty);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
