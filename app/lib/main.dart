import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import 'core/engine/framix_engine.dart';
import 'core/engine/spike_export.dart';
import 'core/media/channel_media_importer.dart';
import 'core/media/media_importer.dart';
import 'core/ui/framix_theme.dart';
import 'features/preview/bloc/preview_cubit.dart';
import 'features/timeline/bloc/playhead_cubit.dart';
import 'features/timeline/bloc/thumbnail_cubit.dart';
import 'features/timeline/bloc/timeline_cubit.dart';
import 'features/timeline/bloc/timeline_zoom_cubit.dart';
import 'features/timeline/view/timeline_page.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  GetIt.I.registerSingleton<FramixEngine>(
    FramixEngine.create(),
    dispose: (engine) => engine.dispose(),
  );
  startSpikeExport(GetIt.I<FramixEngine>());
  runApp(FramixApp(engine: GetIt.I<FramixEngine>()));
}

/// Root widget.
class FramixApp extends StatelessWidget {
  const FramixApp({
    super.key,
    required this.engine,
    this.mediaImporter = const ChannelMediaImporter(),
    this.locale,
  });

  final FramixEngine engine;

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
      home: RepositoryProvider.value(
        value: mediaImporter,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => TimelineCubit(engine)),
            BlocProvider(create: (_) => PreviewCubit(engine)),
            // Not lazy: it must see every playhead event from the start.
            BlocProvider(create: (_) => PlayheadCubit(engine), lazy: false),
            BlocProvider(create: (_) => TimelineZoomCubit()),
            BlocProvider(create: (_) => ThumbnailCubit(engine)),
          ],
          child: const TimelinePage(),
        ),
      ),
    );
  }
}
