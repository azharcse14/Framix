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

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
