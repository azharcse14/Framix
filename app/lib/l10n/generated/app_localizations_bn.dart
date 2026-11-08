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
  String get exportPresets => 'প্ল্যাটফর্ম প্রিসেট';

  @override
  String get presetShortVideo => 'TikTok · Reels · Shorts';

  @override
  String get presetYouTube => 'YouTube';

  @override
  String get presetInstagramFeed => 'Instagram ফিড';

  @override
  String get previousFrame => 'আগের ফ্রেম';

  @override
  String get nextFrame => 'পরের ফ্রেম';

  @override
  String get play => 'চালান';

  @override
  String get pause => 'বিরতি দিন';

  @override
  String get loopClip => 'ক্লিপ বারবার চালান';

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

  @override
  String get somethingWentWrong => 'কিছু ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String exportNoSpace(int neededMb, int freeMb) {
    final intl.NumberFormat neededMbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededMbString = neededMbNumberFormat.format(neededMb);
    final intl.NumberFormat freeMbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String freeMbString = freeMbNumberFormat.format(freeMb);

    return 'জায়গা কম: এক্সপোর্টে প্রায় $neededMbString MB লাগবে, খালি আছে $freeMbString MB।';
  }

  @override
  String get clip => 'ক্লিপ';

  @override
  String get splitClip => 'প্লেহেডে ভাগ করুন';

  @override
  String get deleteClip => 'ক্লিপ মুছুন';

  @override
  String get duplicateClip => 'ক্লিপের কপি করুন';

  @override
  String get applyDurationToAllPhotos => 'সব ছবিতে এই সময়কাল দিন';

  @override
  String get mergeClip => 'পরের ক্লিপের সাথে জোড়া দিন';

  @override
  String get trimStart => 'শুরু ছাঁটুন';

  @override
  String get trimEnd => 'শেষ ছাঁটুন';

  @override
  String get trimStartToPlayhead => 'প্লেহেড পর্যন্ত শুরু ছাঁটুন';

  @override
  String get trimEndToPlayhead => 'প্লেহেড পর্যন্ত শেষ ছাঁটুন';

  @override
  String get replaceClip => 'ক্লিপ বদলান';

  @override
  String get commandFailed => 'কাজটি হয়নি। আবার চেষ্টা করুন।';

  @override
  String get addColorClip => 'ফাঁকা ক্লিপ যোগ করুন';

  @override
  String get exportSettings => 'এক্সপোর্ট সেটিংস';

  @override
  String get exportResolution => 'রেজোলিউশন';

  @override
  String get exportResolution720p => '720p';

  @override
  String get exportResolution1080p => '1080p';

  @override
  String get exportResolution2k => '2K';

  @override
  String get exportResolution4k => '4K';

  @override
  String get exportFrameRate => 'ফ্রেম রেট';

  @override
  String framesPerSecond(int fps) {
    return '$fps fps';
  }

  @override
  String get autoBitrate => 'স্বয়ংক্রিয় বিটরেট';

  @override
  String bitrateKbps(int kbps) {
    final intl.NumberFormat kbpsNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String kbpsString = kbpsNumberFormat.format(kbps);

    return '$kbpsString kbps';
  }

  @override
  String exportFrameSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String exportEstimate(int mb) {
    final intl.NumberFormat mbNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mbString = mbNumberFormat.format(mb);

    return 'প্রায় $mbString MB (আনুমানিক)';
  }

  @override
  String get newProject => 'নতুন প্রজেক্ট';

  @override
  String get projectsEmpty => 'এখনো কোনো প্রজেক্ট নেই। নতুন একটি শুরু করুন।';

  @override
  String get projectsUnavailable =>
      'এই মুহূর্তে আপনার প্রজেক্ট খোলা যাচ্ছে না।';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get openingProject => 'প্রজেক্ট খোলা হচ্ছে';

  @override
  String projectEdited(String when) {
    return 'সম্পাদনা $when';
  }

  @override
  String recentProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'সাম্প্রতিক · $countটি প্রজেক্ট',
    );
    return '$_temp0';
  }

  @override
  String get editedJustNow => 'এইমাত্র সম্পাদিত';

  @override
  String editedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count মিনিট আগে সম্পাদিত',
    );
    return '$_temp0';
  }

  @override
  String editedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ঘণ্টা আগে সম্পাদিত',
    );
    return '$_temp0';
  }

  @override
  String get editedYesterday => 'গতকাল সম্পাদিত';

  @override
  String get projectsEmptyTitle => 'আপনার প্রথম ভিডিও এখান থেকে শুরু';

  @override
  String get projectStorage => 'স্টোরেজ';

  @override
  String get storageProjectFiles => 'প্রজেক্ট';

  @override
  String get storageCache => 'ক্যাশ';

  @override
  String get storageCacheNote =>
      'থাম্বনেইল আর প্রিভিউ কপি। দরকার হলে আবার তৈরি হবে।';

  @override
  String get clearCache => 'ক্যাশ মুছুন';

  @override
  String fileSize(String size, String unit) {
    String _temp0 = intl.Intl.selectLogic(unit, {
      'kb': 'KB',
      'mb': 'MB',
      'gb': 'GB',
      'other': 'বাইট',
    });
    return '$size $_temp0';
  }
}
