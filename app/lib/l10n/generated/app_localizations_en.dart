// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Framix';

  @override
  String get timelineEmpty =>
      'No tracks yet. Add a video or audio track to start.';

  @override
  String get addVideoTrack => 'Add video track';

  @override
  String get addAudioTrack => 'Add audio track';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String videoTrackName(int number) {
    return 'Video track $number';
  }

  @override
  String audioTrackName(int number) {
    return 'Audio track $number';
  }

  @override
  String clipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
      zero: 'No clips',
    );
    return '$_temp0';
  }

  @override
  String get aspectRatio => 'Aspect ratio';

  @override
  String aspectRatioLabel(int width, int height) {
    return '$width:$height';
  }

  @override
  String get muteTrack => 'Mute track';

  @override
  String get hideTrack => 'Hide track';

  @override
  String get lockTrack => 'Lock track';

  @override
  String get importFromGallery => 'Import from gallery';

  @override
  String get importFromFiles => 'Import from files';
}
