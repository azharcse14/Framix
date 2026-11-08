import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Framix'**
  String get appTitle;

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tracks yet. Add a video or audio track to start.'**
  String get timelineEmpty;

  /// No description provided for @addVideoTrack.
  ///
  /// In en, this message translates to:
  /// **'Add video track'**
  String get addVideoTrack;

  /// No description provided for @addAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Add audio track'**
  String get addAudioTrack;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @videoTrackName.
  ///
  /// In en, this message translates to:
  /// **'Video track {number}'**
  String videoTrackName(int number);

  /// No description provided for @audioTrackName.
  ///
  /// In en, this message translates to:
  /// **'Audio track {number}'**
  String audioTrackName(int number);

  /// No description provided for @clipCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No clips} =1{1 clip} other{{count} clips}}'**
  String clipCount(int count);

  /// No description provided for @aspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get aspectRatio;

  /// No description provided for @aspectRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'{width}:{height}'**
  String aspectRatioLabel(int width, int height);

  /// No description provided for @muteTrack.
  ///
  /// In en, this message translates to:
  /// **'Mute track'**
  String get muteTrack;

  /// No description provided for @hideTrack.
  ///
  /// In en, this message translates to:
  /// **'Hide track'**
  String get hideTrack;

  /// No description provided for @lockTrack.
  ///
  /// In en, this message translates to:
  /// **'Lock track'**
  String get lockTrack;

  /// No description provided for @importFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Import from gallery'**
  String get importFromGallery;

  /// No description provided for @importFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Import from files'**
  String get importFromFiles;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing media'**
  String get importing;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @exportPresets.
  ///
  /// In en, this message translates to:
  /// **'Platform presets'**
  String get exportPresets;

  /// No description provided for @presetShortVideo.
  ///
  /// In en, this message translates to:
  /// **'TikTok · Reels · Shorts'**
  String get presetShortVideo;

  /// No description provided for @presetYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get presetYouTube;

  /// No description provided for @presetInstagramFeed.
  ///
  /// In en, this message translates to:
  /// **'Instagram feed'**
  String get presetInstagramFeed;

  /// No description provided for @previousFrame.
  ///
  /// In en, this message translates to:
  /// **'Previous frame'**
  String get previousFrame;

  /// No description provided for @nextFrame.
  ///
  /// In en, this message translates to:
  /// **'Next frame'**
  String get nextFrame;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @loopClip.
  ///
  /// In en, this message translates to:
  /// **'Loop clip'**
  String get loopClip;

  /// No description provided for @timelineRuler.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineRuler;

  /// No description provided for @canvasPlaceClip.
  ///
  /// In en, this message translates to:
  /// **'Move and resize the clip on the canvas'**
  String get canvasPlaceClip;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting video'**
  String get exporting;

  /// No description provided for @cancelExport.
  ///
  /// In en, this message translates to:
  /// **'Cancel export'**
  String get cancelExport;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Try again.'**
  String get exportFailed;

  /// No description provided for @saveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get saveToGallery;

  /// No description provided for @savedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get savedToGallery;

  /// No description provided for @saveDenied.
  ///
  /// In en, this message translates to:
  /// **'Saving to the gallery needs permission. Or use Share to save to Files.'**
  String get saveDenied;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the video. Try again.'**
  String get saveFailed;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open sharing. Try again.'**
  String get shareFailed;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWentWrong;

  /// No description provided for @exportNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage: the export needs about {neededMb} MB and {freeMb} MB is free.'**
  String exportNoSpace(int neededMb, int freeMb);

  /// No description provided for @clip.
  ///
  /// In en, this message translates to:
  /// **'Clip'**
  String get clip;

  /// No description provided for @splitClip.
  ///
  /// In en, this message translates to:
  /// **'Split at playhead'**
  String get splitClip;

  /// No description provided for @deleteClip.
  ///
  /// In en, this message translates to:
  /// **'Delete clip'**
  String get deleteClip;

  /// No description provided for @duplicateClip.
  ///
  /// In en, this message translates to:
  /// **'Duplicate clip'**
  String get duplicateClip;

  /// No description provided for @applyDurationToAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'Use this length for all photos'**
  String get applyDurationToAllPhotos;

  /// No description provided for @mergeClip.
  ///
  /// In en, this message translates to:
  /// **'Merge with next clip'**
  String get mergeClip;

  /// No description provided for @trimStart.
  ///
  /// In en, this message translates to:
  /// **'Trim start'**
  String get trimStart;

  /// No description provided for @trimEnd.
  ///
  /// In en, this message translates to:
  /// **'Trim end'**
  String get trimEnd;

  /// No description provided for @trimStartToPlayhead.
  ///
  /// In en, this message translates to:
  /// **'Trim start to playhead'**
  String get trimStartToPlayhead;

  /// No description provided for @trimEndToPlayhead.
  ///
  /// In en, this message translates to:
  /// **'Trim end to playhead'**
  String get trimEndToPlayhead;

  /// No description provided for @replaceClip.
  ///
  /// In en, this message translates to:
  /// **'Replace clip'**
  String get replaceClip;

  /// No description provided for @commandFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again.'**
  String get commandFailed;

  /// No description provided for @addColorClip.
  ///
  /// In en, this message translates to:
  /// **'Add blank clip'**
  String get addColorClip;

  /// No description provided for @exportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export settings'**
  String get exportSettings;

  /// No description provided for @exportResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get exportResolution;

  /// No description provided for @exportResolution720p.
  ///
  /// In en, this message translates to:
  /// **'720p'**
  String get exportResolution720p;

  /// No description provided for @exportResolution1080p.
  ///
  /// In en, this message translates to:
  /// **'1080p'**
  String get exportResolution1080p;

  /// No description provided for @exportResolution2k.
  ///
  /// In en, this message translates to:
  /// **'2K'**
  String get exportResolution2k;

  /// No description provided for @exportResolution4k.
  ///
  /// In en, this message translates to:
  /// **'4K'**
  String get exportResolution4k;

  /// No description provided for @exportFrameRate.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get exportFrameRate;

  /// No description provided for @framesPerSecond.
  ///
  /// In en, this message translates to:
  /// **'{fps} fps'**
  String framesPerSecond(int fps);

  /// No description provided for @autoBitrate.
  ///
  /// In en, this message translates to:
  /// **'Automatic bitrate'**
  String get autoBitrate;

  /// No description provided for @bitrateKbps.
  ///
  /// In en, this message translates to:
  /// **'{kbps} kbps'**
  String bitrateKbps(int kbps);

  /// No description provided for @exportFrameSize.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String exportFrameSize(int width, int height);

  /// No description provided for @exportEstimate.
  ///
  /// In en, this message translates to:
  /// **'About {mb} MB (estimate)'**
  String exportEstimate(int mb);

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @projectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Start a new one.'**
  String get projectsEmpty;

  /// No description provided for @projectsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your projects can\'t be opened right now.'**
  String get projectsUnavailable;

  /// Button: run a step that failed again (Home when the projects folder could not be opened).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Screen reader label of the spinner on Home while a project is saved and loaded for the editor.
  ///
  /// In en, this message translates to:
  /// **'Opening project'**
  String get openingProject;

  /// No description provided for @projectEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited {when}'**
  String projectEdited(String when);

  /// No description provided for @recentProjects.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recent · 1 project} other{Recent · {count} projects}}'**
  String recentProjects(int count);

  /// No description provided for @editedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Edited just now'**
  String get editedJustNow;

  /// No description provided for @editedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Edited 1 min ago} other{Edited {count} min ago}}'**
  String editedMinutesAgo(int count);

  /// No description provided for @editedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Edited 1 hour ago} other{Edited {count} hours ago}}'**
  String editedHoursAgo(int count);

  /// No description provided for @editedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Edited yesterday'**
  String get editedYesterday;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first video starts here'**
  String get projectsEmptyTitle;

  /// No description provided for @projectStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get projectStorage;

  /// No description provided for @storageProjectFiles.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get storageProjectFiles;

  /// No description provided for @storageCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get storageCache;

  /// No description provided for @storageCacheNote.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails and preview copies. They are made again when needed.'**
  String get storageCacheNote;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'{size} {unit, select, kb{KB} mb{MB} gb{GB} other{B}}'**
  String fileSize(String size, String unit);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
