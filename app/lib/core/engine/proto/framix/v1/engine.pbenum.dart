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

/// What a picked file is.
class MediaKind extends $pb.ProtobufEnum {
  static const MediaKind MEDIA_KIND_UNSPECIFIED =
      MediaKind._(0, _omitEnumNames ? '' : 'MEDIA_KIND_UNSPECIFIED');
  static const MediaKind MEDIA_KIND_VIDEO =
      MediaKind._(1, _omitEnumNames ? '' : 'MEDIA_KIND_VIDEO');
  static const MediaKind MEDIA_KIND_IMAGE =
      MediaKind._(2, _omitEnumNames ? '' : 'MEDIA_KIND_IMAGE');

  static const $core.List<MediaKind> values = <MediaKind>[
    MEDIA_KIND_UNSPECIFIED,
    MEDIA_KIND_VIDEO,
    MEDIA_KIND_IMAGE,
  ];

  static final $core.List<MediaKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static MediaKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MediaKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
