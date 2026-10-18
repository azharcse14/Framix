// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Framix';

  @override
  String get timelineEmpty =>
      'এখনো কোনো ট্র্যাক নেই। শুরু করতে ভিডিও বা অডিও ট্র্যাক যোগ করুন।';

  @override
  String get addVideoTrack => 'ভিডিও ট্র্যাক যোগ করুন';

  @override
  String get addAudioTrack => 'অডিও ট্র্যাক যোগ করুন';

  @override
  String get undo => 'আনডু';

  @override
  String get redo => 'রিডু';

  @override
  String videoTrackName(int number) {
    return 'ভিডিও ট্র্যাক $number';
  }

  @override
  String audioTrackName(int number) {
    return 'অডিও ট্র্যাক $number';
  }

  @override
  String clipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি ক্লিপ',
      zero: 'কোনো ক্লিপ নেই',
    );
    return '$_temp0';
  }

  @override
  String get aspectRatio => 'অনুপাত';

  @override
  String aspectRatioLabel(int width, int height) {
    return '$width:$height';
  }

  @override
  String get muteTrack => 'ট্র্যাক মিউট';

  @override
  String get hideTrack => 'ট্র্যাক লুকান';

  @override
  String get lockTrack => 'ট্র্যাক লক';

  @override
  String get importFromGallery => 'গ্যালারি থেকে আনুন';

  @override
  String get importFromFiles => 'ফাইল থেকে আনুন';

  @override
  String get importing => 'মিডিয়া আনা হচ্ছে';
}
