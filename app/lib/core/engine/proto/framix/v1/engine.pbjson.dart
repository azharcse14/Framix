// This is a generated file - do not edit.
//
// Generated from framix/v1/engine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use trackKindDescriptor instead')
const TrackKind$json = {
  '1': 'TrackKind',
  '2': [
    {'1': 'TRACK_KIND_UNSPECIFIED', '2': 0},
    {'1': 'TRACK_KIND_VIDEO', '2': 1},
    {'1': 'TRACK_KIND_AUDIO', '2': 2},
  ],
};

/// Descriptor for `TrackKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List trackKindDescriptor = $convert.base64Decode(
    'CglUcmFja0tpbmQSGgoWVFJBQ0tfS0lORF9VTlNQRUNJRklFRBAAEhQKEFRSQUNLX0tJTkRfVk'
    'lERU8QARIUChBUUkFDS19LSU5EX0FVRElPEAI=');

@$core.Deprecated('Use commandDescriptor instead')
const Command$json = {
  '1': 'Command',
  '2': [
    {
      '1': 'add_track',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.AddTrack',
      '9': 0,
      '10': 'addTrack'
    },
    {
      '1': 'insert_clip',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.InsertClip',
      '9': 0,
      '10': 'insertClip'
    },
    {
      '1': 'undo',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.Undo',
      '9': 0,
      '10': 'undo'
    },
    {
      '1': 'redo',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.Redo',
      '9': 0,
      '10': 'redo'
    },
    {
      '1': 'get_timeline',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.GetTimeline',
      '9': 0,
      '10': 'getTimeline'
    },
    {
      '1': 'new_project',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.NewProject',
      '9': 0,
      '10': 'newProject'
    },
    {
      '1': 'save_project',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SaveProject',
      '9': 0,
      '10': 'saveProject'
    },
    {
      '1': 'open_project',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.OpenProject',
      '9': 0,
      '10': 'openProject'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `Command`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandDescriptor = $convert.base64Decode(
    'CgdDb21tYW5kEjIKCWFkZF90cmFjaxgBIAEoCzITLmZyYW1peC52MS5BZGRUcmFja0gAUghhZG'
    'RUcmFjaxI4CgtpbnNlcnRfY2xpcBgCIAEoCzIVLmZyYW1peC52MS5JbnNlcnRDbGlwSABSCmlu'
    'c2VydENsaXASJQoEdW5kbxgDIAEoCzIPLmZyYW1peC52MS5VbmRvSABSBHVuZG8SJQoEcmVkbx'
    'gEIAEoCzIPLmZyYW1peC52MS5SZWRvSABSBHJlZG8SOwoMZ2V0X3RpbWVsaW5lGAUgASgLMhYu'
    'ZnJhbWl4LnYxLkdldFRpbWVsaW5lSABSC2dldFRpbWVsaW5lEjgKC25ld19wcm9qZWN0GAYgAS'
    'gLMhUuZnJhbWl4LnYxLk5ld1Byb2plY3RIAFIKbmV3UHJvamVjdBI7CgxzYXZlX3Byb2plY3QY'
    'ByABKAsyFi5mcmFtaXgudjEuU2F2ZVByb2plY3RIAFILc2F2ZVByb2plY3QSOwoMb3Blbl9wcm'
    '9qZWN0GAggASgLMhYuZnJhbWl4LnYxLk9wZW5Qcm9qZWN0SABSC29wZW5Qcm9qZWN0QgYKBGtp'
    'bmQ=');

@$core.Deprecated('Use addTrackDescriptor instead')
const AddTrack$json = {
  '1': 'AddTrack',
  '2': [
    {
      '1': 'kind',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.TrackKind',
      '10': 'kind'
    },
  ],
};

/// Descriptor for `AddTrack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addTrackDescriptor = $convert.base64Decode(
    'CghBZGRUcmFjaxIoCgRraW5kGAEgASgOMhQuZnJhbWl4LnYxLlRyYWNrS2luZFIEa2luZA==');

@$core.Deprecated('Use insertClipDescriptor instead')
const InsertClip$json = {
  '1': 'InsertClip',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 4, '10': 'trackId'},
    {'1': 'media_id', '3': 2, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'source_start', '3': 3, '4': 1, '5': 3, '10': 'sourceStart'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'duration', '3': 5, '4': 1, '5': 3, '10': 'duration'},
  ],
};

/// Descriptor for `InsertClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List insertClipDescriptor = $convert.base64Decode(
    'CgpJbnNlcnRDbGlwEhkKCHRyYWNrX2lkGAEgASgEUgd0cmFja0lkEhkKCG1lZGlhX2lkGAIgAS'
    'gEUgdtZWRpYUlkEiEKDHNvdXJjZV9zdGFydBgDIAEoA1ILc291cmNlU3RhcnQSFAoFc3RhcnQY'
    'BCABKANSBXN0YXJ0EhoKCGR1cmF0aW9uGAUgASgDUghkdXJhdGlvbg==');

@$core.Deprecated('Use undoDescriptor instead')
const Undo$json = {
  '1': 'Undo',
};

/// Descriptor for `Undo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List undoDescriptor = $convert.base64Decode('CgRVbmRv');

@$core.Deprecated('Use redoDescriptor instead')
const Redo$json = {
  '1': 'Redo',
};

/// Descriptor for `Redo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List redoDescriptor = $convert.base64Decode('CgRSZWRv');

@$core.Deprecated('Use getTimelineDescriptor instead')
const GetTimeline$json = {
  '1': 'GetTimeline',
};

/// Descriptor for `GetTimeline`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTimelineDescriptor =
    $convert.base64Decode('CgtHZXRUaW1lbGluZQ==');

@$core.Deprecated('Use newProjectDescriptor instead')
const NewProject$json = {
  '1': 'NewProject',
};

/// Descriptor for `NewProject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List newProjectDescriptor =
    $convert.base64Decode('CgpOZXdQcm9qZWN0');

@$core.Deprecated('Use saveProjectDescriptor instead')
const SaveProject$json = {
  '1': 'SaveProject',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `SaveProject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveProjectDescriptor =
    $convert.base64Decode('CgtTYXZlUHJvamVjdBISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use openProjectDescriptor instead')
const OpenProject$json = {
  '1': 'OpenProject',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `OpenProject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openProjectDescriptor =
    $convert.base64Decode('CgtPcGVuUHJvamVjdBISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {
      '1': 'timeline_changed',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.TimelineChanged',
      '9': 0,
      '10': 'timelineChanged'
    },
    {
      '1': 'command_failed',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.CommandFailed',
      '9': 0,
      '10': 'commandFailed'
    },
    {
      '1': 'project_saved',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ProjectSaved',
      '9': 0,
      '10': 'projectSaved'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBJHChB0aW1lbGluZV9jaGFuZ2VkGAEgASgLMhouZnJhbWl4LnYxLlRpbWVsaW5lQ2'
    'hhbmdlZEgAUg90aW1lbGluZUNoYW5nZWQSQQoOY29tbWFuZF9mYWlsZWQYAiABKAsyGC5mcmFt'
    'aXgudjEuQ29tbWFuZEZhaWxlZEgAUg1jb21tYW5kRmFpbGVkEj4KDXByb2plY3Rfc2F2ZWQYAy'
    'ABKAsyFy5mcmFtaXgudjEuUHJvamVjdFNhdmVkSABSDHByb2plY3RTYXZlZEIGCgRraW5k');

@$core.Deprecated('Use timelineChangedDescriptor instead')
const TimelineChanged$json = {
  '1': 'TimelineChanged',
  '2': [
    {
      '1': 'tracks',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.framix.v1.Track',
      '10': 'tracks'
    },
    {'1': 'duration', '3': 2, '4': 1, '5': 3, '10': 'duration'},
    {'1': 'can_undo', '3': 3, '4': 1, '5': 8, '10': 'canUndo'},
    {'1': 'can_redo', '3': 4, '4': 1, '5': 8, '10': 'canRedo'},
  ],
};

/// Descriptor for `TimelineChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelineChangedDescriptor = $convert.base64Decode(
    'Cg9UaW1lbGluZUNoYW5nZWQSKAoGdHJhY2tzGAEgAygLMhAuZnJhbWl4LnYxLlRyYWNrUgZ0cm'
    'Fja3MSGgoIZHVyYXRpb24YAiABKANSCGR1cmF0aW9uEhkKCGNhbl91bmRvGAMgASgIUgdjYW5V'
    'bmRvEhkKCGNhbl9yZWRvGAQgASgIUgdjYW5SZWRv');

@$core.Deprecated('Use trackDescriptor instead')
const Track$json = {
  '1': 'Track',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.TrackKind',
      '10': 'kind'
    },
    {
      '1': 'clips',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.framix.v1.Clip',
      '10': 'clips'
    },
    {'1': 'number', '3': 4, '4': 1, '5': 13, '10': 'number'},
  ],
};

/// Descriptor for `Track`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trackDescriptor = $convert.base64Decode(
    'CgVUcmFjaxIOCgJpZBgBIAEoBFICaWQSKAoEa2luZBgCIAEoDjIULmZyYW1peC52MS5UcmFja0'
    'tpbmRSBGtpbmQSJQoFY2xpcHMYAyADKAsyDy5mcmFtaXgudjEuQ2xpcFIFY2xpcHMSFgoGbnVt'
    'YmVyGAQgASgNUgZudW1iZXI=');

@$core.Deprecated('Use clipDescriptor instead')
const Clip$json = {
  '1': 'Clip',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'media_id', '3': 2, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'source_start', '3': 3, '4': 1, '5': 3, '10': 'sourceStart'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'duration', '3': 5, '4': 1, '5': 3, '10': 'duration'},
  ],
};

/// Descriptor for `Clip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipDescriptor = $convert.base64Decode(
    'CgRDbGlwEg4KAmlkGAEgASgEUgJpZBIZCghtZWRpYV9pZBgCIAEoBFIHbWVkaWFJZBIhCgxzb3'
    'VyY2Vfc3RhcnQYAyABKANSC3NvdXJjZVN0YXJ0EhQKBXN0YXJ0GAQgASgDUgVzdGFydBIaCghk'
    'dXJhdGlvbhgFIAEoA1IIZHVyYXRpb24=');

@$core.Deprecated('Use projectSavedDescriptor instead')
const ProjectSaved$json = {
  '1': 'ProjectSaved',
};

/// Descriptor for `ProjectSaved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectSavedDescriptor =
    $convert.base64Decode('CgxQcm9qZWN0U2F2ZWQ=');

@$core.Deprecated('Use commandFailedDescriptor instead')
const CommandFailed$json = {
  '1': 'CommandFailed',
  '2': [
    {'1': 'reason', '3': 1, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `CommandFailed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandFailedDescriptor = $convert
    .base64Decode('Cg1Db21tYW5kRmFpbGVkEhYKBnJlYXNvbhgBIAEoCVIGcmVhc29u');
