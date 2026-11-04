import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/crash_reporting.dart';
import 'core/engine/framix_engine.dart';
import 'core/media/channel_media_importer.dart';
import 'core/media/media_importer.dart';
import 'core/ui/command_failure_messages.dart';
import 'core/ui/error_boundary.dart';
import 'core/ui/framix_theme.dart';
import 'features/export/bloc/export_cubit.dart';
import 'features/home/view/home_page.dart';
import 'features/preview/bloc/preview_cubit.dart';
import 'features/timeline/bloc/playhead_cubit.dart';
import 'features/timeline/bloc/thumbnail_cubit.dart';
import 'features/timeline/bloc/timeline_cubit.dart';
import 'features/timeline/bloc/timeline_zoom_cubit.dart';
import 'features/timeline/view/timeline_page.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() => SentryFlutter.init(
  configureCrashReporting,
  appRunner: () {
    // Must run after Sentry's init: it replaces Sentry's PlatformDispatcher.onError and
    // reports through FlutterError.onError, which Sentry wraps. Run earlier, Sentry would
    // chain this handler and report every async error twice.
    installErrorBoundary();
    GetIt.I.registerSingleton<FramixEngine>(
      FramixEngine.create(),
      dispose: (engine) => engine.dispose(),
    );
    runApp(FramixApp(engine: GetIt.I<FramixEngine>(), home: const HomePage()));
  },
);

/// Root widget.
class FramixApp extends StatelessWidget {
  const FramixApp({
    super.key,
    required this.engine,
    this.mediaImporter = const ChannelMediaImporter(),
    this.locale,
    this.home = const TimelinePage(),
  });

  final FramixEngine engine;

  /// The first screen: Home in the app; the editor by default, which most tests drive.
  final Widget home;

  /// Platform media picker (a fake in tests).
  final MediaImporter mediaImporter;

  /// Forces a locale (tests); null follows the device.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: framixDarkTheme(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      // Above the Navigator, so every route (the editor pushed from Home, dialogs) sees them.
      builder: (context, navigator) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: engine),
          RepositoryProvider.value(value: mediaImporter),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => TimelineCubit(engine)),
            BlocProvider(create: (_) => PreviewCubit(engine)),
            // Not lazy: it must see every playhead event from the start.
            BlocProvider(create: (_) => PlayheadCubit(engine), lazy: false),
            BlocProvider(create: (_) => TimelineZoomCubit()),
            BlocProvider(
              create: (ctx) => ThumbnailCubit(
                engine,
                project: ctx.read<TimelineCubit>().state.project.toInt(),
              ),
            ),
            BlocProvider(create: (_) => ExportCubit(engine)),
          ],
          child: CommandFailureMessages(engine: engine, child: navigator!),
        ),
      ),
    );
  }
}
