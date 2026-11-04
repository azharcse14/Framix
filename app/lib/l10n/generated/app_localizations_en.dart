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

  @override
  String get importing => 'Importing media';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get exportPresets => 'Platform presets';

  @override
  String get presetShortVideo => 'TikTok · Reels · Shorts';

  @override
  String get presetYouTube => 'YouTube';

  @override
  String get presetInstagramFeed => 'Instagram feed';

  @override
  String get previousFrame => 'Previous frame';

  @override
  String get nextFrame => 'Next frame';

  @override
  String get timelineRuler => 'Timeline';

  @override
  String get canvasPlaceClip => 'Move and resize the clip on the canvas';

  @override
  String get export => 'Export';

  @override
  String get exporting => 'Exporting video';

  @override
  String get cancelExport => 'Cancel export';

  @override
  String get exportFailed => 'Export failed. Try again.';

  @override
  String get saveToGallery => 'Save to gallery';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saveDenied =>
      'Saving to the gallery needs permission. Or use Share to save to Files.';

  @override
  String get saveFailed => 'Couldn\'t save the video. Try again.';

  @override
  String get share => 'Share';

  @override
  String get shareFailed => 'Couldn\'t open sharing. Try again.';

  @override
  String get somethingWentWrong => 'Something went wrong. Try again.';

  @override
  String exportNoSpace(int neededMb, int freeMb) {
    final intl.NumberFormat neededMbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String neededMbString = neededMbNumberFormat.format(neededMb);
    final intl.NumberFormat freeMbNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String freeMbString = freeMbNumberFormat.format(freeMb);

    return 'Not enough storage: the export needs about $neededMbString MB and $freeMbString MB is free.';
  }

  @override
  String get clip => 'Clip';

  @override
  String get splitClip => 'Split at playhead';

  @override
  String get deleteClip => 'Delete clip';

  @override
  String get duplicateClip => 'Duplicate clip';

  @override
  String get applyDurationToAllPhotos => 'Use this length for all photos';

  @override
  String get mergeClip => 'Merge with next clip';

  @override
  String get trimStart => 'Trim start';

  @override
  String get trimEnd => 'Trim end';

  @override
  String get trimStartToPlayhead => 'Trim start to playhead';

  @override
  String get trimEndToPlayhead => 'Trim end to playhead';

  @override
  String get replaceClip => 'Replace clip';

  @override
  String get commandFailed => 'That didn\'t work. Try again.';

  @override
  String get addColorClip => 'Add blank clip';

  @override
  String get exportSettings => 'Export settings';

  @override
  String get exportResolution => 'Resolution';

  @override
  String get exportResolution720p => '720p';

  @override
  String get exportResolution1080p => '1080p';

  @override
  String get exportResolution2k => '2K';

  @override
  String get exportResolution4k => '4K';

  @override
  String get exportFrameRate => 'Frame rate';

  @override
  String framesPerSecond(int fps) {
    return '$fps fps';
  }

  @override
  String get autoBitrate => 'Automatic bitrate';

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

    return 'About $mbString MB (estimate)';
  }

  @override
  String get newProject => 'New project';

  @override
  String get projectsEmpty => 'No projects yet. Start a new one.';

  @override
  String get projectsUnavailable => 'Your projects can\'t be opened right now.';

  @override
  String get retry => 'Try again';

  @override
  String projectEdited(String when) {
    return 'Edited $when';
  }

  @override
  String recentProjects(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recent · $count projects',
      one: 'Recent · 1 project',
    );
    return '$_temp0';
  }

  @override
  String get editedJustNow => 'Edited just now';

  @override
  String editedMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edited $count min ago',
      one: 'Edited 1 min ago',
    );
    return '$_temp0';
  }

  @override
  String editedHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edited $count hours ago',
      one: 'Edited 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get editedYesterday => 'Edited yesterday';

  @override
  String get projectsEmptyTitle => 'Your first video starts here';
}
