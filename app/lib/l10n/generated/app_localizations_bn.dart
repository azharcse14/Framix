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

  @override
  String get zoomIn => 'জুম ইন';

  @override
  String get zoomOut => 'জুম আউট';

  @override
  String get timelineRuler => 'টাইমলাইন';

  @override
  String get canvasPlaceClip => 'ক্যানভাসে ক্লিপ সরান ও বড়-ছোট করুন';

  @override
  String get export => 'এক্সপোর্ট';

  @override
  String get exporting => 'ভিডিও এক্সপোর্ট হচ্ছে';

  @override
  String get cancelExport => 'এক্সপোর্ট বাতিল';

  @override
  String get exportFailed => 'এক্সপোর্ট হয়নি। আবার চেষ্টা করুন।';

  @override
  String get saveToGallery => 'গ্যালারিতে সেভ করুন';

  @override
  String get savedToGallery => 'গ্যালারিতে সেভ হয়েছে';

  @override
  String get saveDenied =>
      'গ্যালারিতে সেভ করতে অনুমতি লাগবে। অথবা শেয়ার থেকে ফাইলে সেভ করুন।';

  @override
  String get saveFailed => 'ভিডিও সেভ হয়নি। আবার চেষ্টা করুন।';

  @override
  String get share => 'শেয়ার';

  @override
  String get shareFailed => 'শেয়ার খোলা যায়নি। আবার চেষ্টা করুন।';
}
