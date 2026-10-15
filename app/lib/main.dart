import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import 'core/engine/framix_engine.dart';
import 'core/media/channel_media_importer.dart';
import 'core/media/media_importer.dart';
import 'core/ui/framix_theme.dart';
import 'features/timeline/bloc/timeline_cubit.dart';
import 'features/timeline/view/timeline_page.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  GetIt.I.registerSingleton<FramixEngine>(
    FramixEngine.create(),
    dispose: (engine) => engine.dispose(),
  );
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
      home: BlocProvider(
        create: (_) => TimelineCubit(engine),
        child: const TimelinePage(),
      ),
    );
  }
}
