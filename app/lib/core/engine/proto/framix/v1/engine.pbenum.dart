// This is a generated file - do not edit.
//
// Generated from framix/v1/engine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ExportResolution extends $pb.ProtobufEnum {
  static const ExportResolution EXPORT_RESOLUTION_UNSPECIFIED =
      ExportResolution._(
          0, _omitEnumNames ? '' : 'EXPORT_RESOLUTION_UNSPECIFIED');
  static const ExportResolution EXPORT_RESOLUTION_720P =
      ExportResolution._(1, _omitEnumNames ? '' : 'EXPORT_RESOLUTION_720P');
  static const ExportResolution EXPORT_RESOLUTION_1080P =
      ExportResolution._(2, _omitEnumNames ? '' : 'EXPORT_RESOLUTION_1080P');
  static const ExportResolution EXPORT_RESOLUTION_2K =
      ExportResolution._(3, _omitEnumNames ? '' : 'EXPORT_RESOLUTION_2K');
  static const ExportResolution EXPORT_RESOLUTION_4K =
      ExportResolution._(4, _omitEnumNames ? '' : 'EXPORT_RESOLUTION_4K');

  static const $core.List<ExportResolution> values = <ExportResolution>[
    EXPORT_RESOLUTION_UNSPECIFIED,
    EXPORT_RESOLUTION_720P,
    EXPORT_RESOLUTION_1080P,
    EXPORT_RESOLUTION_2K,
    EXPORT_RESOLUTION_4K,
  ];

  static final $core.List<ExportResolution?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ExportResolution? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportResolution._(super.value, super.name);
}

class ExportFps extends $pb.ProtobufEnum {
  static const ExportFps EXPORT_FPS_UNSPECIFIED =
      ExportFps._(0, _omitEnumNames ? '' : 'EXPORT_FPS_UNSPECIFIED');
  static const ExportFps EXPORT_FPS_24 =
      ExportFps._(1, _omitEnumNames ? '' : 'EXPORT_FPS_24');
  static const ExportFps EXPORT_FPS_30 =
      ExportFps._(2, _omitEnumNames ? '' : 'EXPORT_FPS_30');
  static const ExportFps EXPORT_FPS_60 =
      ExportFps._(3, _omitEnumNames ? '' : 'EXPORT_FPS_60');

  static const $core.List<ExportFps> values = <ExportFps>[
    EXPORT_FPS_UNSPECIFIED,
    EXPORT_FPS_24,
    EXPORT_FPS_30,
    EXPORT_FPS_60,
  ];

  static final $core.List<ExportFps?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ExportFps? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportFps._(super.value, super.name);
}

/// A platform's canvas and export settings.
class ExportPreset extends $pb.ProtobufEnum {
  static const ExportPreset EXPORT_PRESET_UNSPECIFIED =
      ExportPreset._(0, _omitEnumNames ? '' : 'EXPORT_PRESET_UNSPECIFIED');

  /// TikTok, Reels, Shorts: 9:16.
  static const ExportPreset EXPORT_PRESET_SHORT_VIDEO =
      ExportPreset._(1, _omitEnumNames ? '' : 'EXPORT_PRESET_SHORT_VIDEO');

  /// 16:9.
  static const ExportPreset EXPORT_PRESET_YOUTUBE =
      ExportPreset._(2, _omitEnumNames ? '' : 'EXPORT_PRESET_YOUTUBE');

  /// 4:5.
  static const ExportPreset EXPORT_PRESET_INSTAGRAM_FEED =
      ExportPreset._(3, _omitEnumNames ? '' : 'EXPORT_PRESET_INSTAGRAM_FEED');

  static const $core.List<ExportPreset> values = <ExportPreset>[
    EXPORT_PRESET_UNSPECIFIED,
    EXPORT_PRESET_SHORT_VIDEO,
    EXPORT_PRESET_YOUTUBE,
    EXPORT_PRESET_INSTAGRAM_FEED,
  ];

  static final $core.List<ExportPreset?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ExportPreset? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExportPreset._(super.value, super.name);
}

/// What a track carries.
class TrackKind extends $pb.ProtobufEnum {
  static const TrackKind TRACK_KIND_UNSPECIFIED =
      TrackKind._(0, _omitEnumNames ? '' : 'TRACK_KIND_UNSPECIFIED');
  static const TrackKind TRACK_KIND_VIDEO =
      TrackKind._(1, _omitEnumNames ? '' : 'TRACK_KIND_VIDEO');
  static const TrackKind TRACK_KIND_AUDIO =
      TrackKind._(2, _omitEnumNames ? '' : 'TRACK_KIND_AUDIO');

  static const $core.List<TrackKind> values = <TrackKind>[
    TRACK_KIND_UNSPECIFIED,
    TRACK_KIND_VIDEO,
    TRACK_KIND_AUDIO,
  ];

  static final $core.List<TrackKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TrackKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TrackKind._(super.value, super.name);
}

/// How ListProjects orders projects. Ties go newest saved first.
class ProjectSort extends $pb.ProtobufEnum {
  /// Newest saved first.
  static const ProjectSort PROJECT_SORT_UNSPECIFIED =
      ProjectSort._(0, _omitEnumNames ? '' : 'PROJECT_SORT_UNSPECIFIED');

  /// By name, A to Z ignoring case; unnamed projects last.
  static const ProjectSort PROJECT_SORT_NAME =
      ProjectSort._(1, _omitEnumNames ? '' : 'PROJECT_SORT_NAME');

  /// Largest first (ProjectSummary.bytes).
  static const ProjectSort PROJECT_SORT_SIZE =
      ProjectSort._(2, _omitEnumNames ? '' : 'PROJECT_SORT_SIZE');

  static const $core.List<ProjectSort> values = <ProjectSort>[
    PROJECT_SORT_UNSPECIFIED,
    PROJECT_SORT_NAME,
    PROJECT_SORT_SIZE,
  ];

  static final $core.List<ProjectSort?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ProjectSort? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProjectSort._(super.value, super.name);
}

/// Which end of a clip.
class ClipEdge extends $pb.ProtobufEnum {
  static const ClipEdge CLIP_EDGE_UNSPECIFIED =
      ClipEdge._(0, _omitEnumNames ? '' : 'CLIP_EDGE_UNSPECIFIED');
  static const ClipEdge CLIP_EDGE_START =
      ClipEdge._(1, _omitEnumNames ? '' : 'CLIP_EDGE_START');
  static const ClipEdge CLIP_EDGE_END =
      ClipEdge._(2, _omitEnumNames ? '' : 'CLIP_EDGE_END');

  static const $core.List<ClipEdge> values = <ClipEdge>[
    CLIP_EDGE_UNSPECIFIED,
    CLIP_EDGE_START,
    CLIP_EDGE_END,
  ];

  static final $core.List<ClipEdge?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ClipEdge? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ClipEdge._(super.value, super.name);
}

/// What a picked file is.
class MediaKind extends $pb.ProtobufEnum {
  static const MediaKind MEDIA_KIND_UNSPECIFIED =
      MediaKind._(0, _omitEnumNames ? '' : 'MEDIA_KIND_UNSPECIFIED');
  static const MediaKind MEDIA_KIND_VIDEO =
      MediaKind._(1, _omitEnumNames ? '' : 'MEDIA_KIND_VIDEO');
  static const MediaKind MEDIA_KIND_IMAGE =
      MediaKind._(2, _omitEnumNames ? '' : 'MEDIA_KIND_IMAGE');

  /// A solid color with no file (a blank clip); only `color` is read.
  static const MediaKind MEDIA_KIND_COLOR =
      MediaKind._(3, _omitEnumNames ? '' : 'MEDIA_KIND_COLOR');

  static const $core.List<MediaKind> values = <MediaKind>[
    MEDIA_KIND_UNSPECIFIED,
    MEDIA_KIND_VIDEO,
    MEDIA_KIND_IMAGE,
    MEDIA_KIND_COLOR,
  ];

  static final $core.List<MediaKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static MediaKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MediaKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
