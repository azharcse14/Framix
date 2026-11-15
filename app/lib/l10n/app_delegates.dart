import 'package:material_ui/material_ui.dart';

import 'generated/app_localizations.dart';

/// The app's localization delegates: its strings plus material_ui's Material, Cupertino
/// and Widgets localizations. Use this, not the generated
/// AppLocalizations.localizationsDelegates, which brings package:flutter's delegates.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
