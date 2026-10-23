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

@$core.Deprecated('Use exportResolutionDescriptor instead')
const ExportResolution$json = {
  '1': 'ExportResolution',
  '2': [
    {'1': 'EXPORT_RESOLUTION_UNSPECIFIED', '2': 0},
    {'1': 'EXPORT_RESOLUTION_720P', '2': 1},
    {'1': 'EXPORT_RESOLUTION_1080P', '2': 2},
    {'1': 'EXPORT_RESOLUTION_2K', '2': 3},
    {'1': 'EXPORT_RESOLUTION_4K', '2': 4},
  ],
};

/// Descriptor for `ExportResolution`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportResolutionDescriptor = $convert.base64Decode(
    'ChBFeHBvcnRSZXNvbHV0aW9uEiEKHUVYUE9SVF9SRVNPTFVUSU9OX1VOU1BFQ0lGSUVEEAASGg'
    'oWRVhQT1JUX1JFU09MVVRJT05fNzIwUBABEhsKF0VYUE9SVF9SRVNPTFVUSU9OXzEwODBQEAIS'
    'GAoURVhQT1JUX1JFU09MVVRJT05fMksQAxIYChRFWFBPUlRfUkVTT0xVVElPTl80SxAE');

@$core.Deprecated('Use exportFpsDescriptor instead')
const ExportFps$json = {
  '1': 'ExportFps',
  '2': [
    {'1': 'EXPORT_FPS_UNSPECIFIED', '2': 0},
    {'1': 'EXPORT_FPS_24', '2': 1},
    {'1': 'EXPORT_FPS_30', '2': 2},
    {'1': 'EXPORT_FPS_60', '2': 3},
  ],
};

/// Descriptor for `ExportFps`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exportFpsDescriptor = $convert.base64Decode(
    'CglFeHBvcnRGcHMSGgoWRVhQT1JUX0ZQU19VTlNQRUNJRklFRBAAEhEKDUVYUE9SVF9GUFNfMj'
    'QQARIRCg1FWFBPUlRfRlBTXzMwEAISEQoNRVhQT1JUX0ZQU182MBAD');

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

@$core.Deprecated('Use mediaKindDescriptor instead')
const MediaKind$json = {
  '1': 'MediaKind',
  '2': [
    {'1': 'MEDIA_KIND_UNSPECIFIED', '2': 0},
    {'1': 'MEDIA_KIND_VIDEO', '2': 1},
    {'1': 'MEDIA_KIND_IMAGE', '2': 2},
  ],
};

/// Descriptor for `MediaKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List mediaKindDescriptor = $convert.base64Decode(
    'CglNZWRpYUtpbmQSGgoWTUVESUFfS0lORF9VTlNQRUNJRklFRBAAEhQKEE1FRElBX0tJTkRfVk'
    'lERU8QARIUChBNRURJQV9LSU5EX0lNQUdFEAI=');

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
    {
      '1': 'set_aspect_ratio',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SetAspectRatio',
      '9': 0,
      '10': 'setAspectRatio'
    },
    {
      '1': 'remove_clip',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.RemoveClip',
      '9': 0,
      '10': 'removeClip'
    },
    {
      '1': 'split_clip',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SplitClip',
      '9': 0,
      '10': 'splitClip'
    },
    {
      '1': 'merge_clips',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.MergeClips',
      '9': 0,
      '10': 'mergeClips'
    },
    {
      '1': 'trim_clip',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.TrimClip',
      '9': 0,
      '10': 'trimClip'
    },
    {
      '1': 'duplicate_clip',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.DuplicateClip',
      '9': 0,
      '10': 'duplicateClip'
    },
    {
      '1': 'set_track_flags',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SetTrackFlags',
      '9': 0,
      '10': 'setTrackFlags'
    },
    {
      '1': 'move_clip',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.MoveClip',
      '9': 0,
      '10': 'moveClip'
    },
    {
      '1': 'import_media',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ImportMedia',
      '9': 0,
      '10': 'importMedia'
    },
    {
      '1': 'create_preview',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.CreatePreview',
      '9': 0,
      '10': 'createPreview'
    },
    {
      '1': 'seek',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.Seek',
      '9': 0,
      '10': 'seek'
    },
    {
      '1': 'request_thumbnails',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.RequestThumbnails',
      '9': 0,
      '10': 'requestThumbnails'
    },
    {
      '1': 'set_clip_transform',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SetClipTransform',
      '9': 0,
      '10': 'setClipTransform'
    },
    {
      '1': 'replace_clip',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ReplaceClip',
      '9': 0,
      '10': 'replaceClip'
    },
    {
      '1': 'set_export_settings',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.SetExportSettings',
      '9': 0,
      '10': 'setExportSettings'
    },
    {
      '1': 'enable_autosave',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.EnableAutosave',
      '9': 0,
      '10': 'enableAutosave'
    },
    {
      '1': 'export_project',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ExportProject',
      '9': 0,
      '10': 'exportProject'
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
    '9qZWN0GAggASgLMhYuZnJhbWl4LnYxLk9wZW5Qcm9qZWN0SABSC29wZW5Qcm9qZWN0EkUKEHNl'
    'dF9hc3BlY3RfcmF0aW8YCSABKAsyGS5mcmFtaXgudjEuU2V0QXNwZWN0UmF0aW9IAFIOc2V0QX'
    'NwZWN0UmF0aW8SOAoLcmVtb3ZlX2NsaXAYCiABKAsyFS5mcmFtaXgudjEuUmVtb3ZlQ2xpcEgA'
    'UgpyZW1vdmVDbGlwEjUKCnNwbGl0X2NsaXAYCyABKAsyFC5mcmFtaXgudjEuU3BsaXRDbGlwSA'
    'BSCXNwbGl0Q2xpcBI4CgttZXJnZV9jbGlwcxgMIAEoCzIVLmZyYW1peC52MS5NZXJnZUNsaXBz'
    'SABSCm1lcmdlQ2xpcHMSMgoJdHJpbV9jbGlwGA0gASgLMhMuZnJhbWl4LnYxLlRyaW1DbGlwSA'
    'BSCHRyaW1DbGlwEkEKDmR1cGxpY2F0ZV9jbGlwGA4gASgLMhguZnJhbWl4LnYxLkR1cGxpY2F0'
    'ZUNsaXBIAFINZHVwbGljYXRlQ2xpcBJCCg9zZXRfdHJhY2tfZmxhZ3MYDyABKAsyGC5mcmFtaX'
    'gudjEuU2V0VHJhY2tGbGFnc0gAUg1zZXRUcmFja0ZsYWdzEjIKCW1vdmVfY2xpcBgQIAEoCzIT'
    'LmZyYW1peC52MS5Nb3ZlQ2xpcEgAUghtb3ZlQ2xpcBI7CgxpbXBvcnRfbWVkaWEYESABKAsyFi'
    '5mcmFtaXgudjEuSW1wb3J0TWVkaWFIAFILaW1wb3J0TWVkaWESQQoOY3JlYXRlX3ByZXZpZXcY'
    'EiABKAsyGC5mcmFtaXgudjEuQ3JlYXRlUHJldmlld0gAUg1jcmVhdGVQcmV2aWV3EiUKBHNlZW'
    'sYEyABKAsyDy5mcmFtaXgudjEuU2Vla0gAUgRzZWVrEk0KEnJlcXVlc3RfdGh1bWJuYWlscxgU'
    'IAEoCzIcLmZyYW1peC52MS5SZXF1ZXN0VGh1bWJuYWlsc0gAUhFyZXF1ZXN0VGh1bWJuYWlscx'
    'JLChJzZXRfY2xpcF90cmFuc2Zvcm0YFSABKAsyGy5mcmFtaXgudjEuU2V0Q2xpcFRyYW5zZm9y'
    'bUgAUhBzZXRDbGlwVHJhbnNmb3JtEjsKDHJlcGxhY2VfY2xpcBgWIAEoCzIWLmZyYW1peC52MS'
    '5SZXBsYWNlQ2xpcEgAUgtyZXBsYWNlQ2xpcBJOChNzZXRfZXhwb3J0X3NldHRpbmdzGBcgASgL'
    'MhwuZnJhbWl4LnYxLlNldEV4cG9ydFNldHRpbmdzSABSEXNldEV4cG9ydFNldHRpbmdzEkQKD2'
    'VuYWJsZV9hdXRvc2F2ZRgYIAEoCzIZLmZyYW1peC52MS5FbmFibGVBdXRvc2F2ZUgAUg5lbmFi'
    'bGVBdXRvc2F2ZRJBCg5leHBvcnRfcHJvamVjdBgZIAEoCzIYLmZyYW1peC52MS5FeHBvcnRQcm'
    '9qZWN0SABSDWV4cG9ydFByb2plY3RCBgoEa2luZA==');

@$core.Deprecated('Use exportProjectDescriptor instead')
const ExportProject$json = {
  '1': 'ExportProject',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `ExportProject`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportProjectDescriptor =
    $convert.base64Decode('Cg1FeHBvcnRQcm9qZWN0EhIKBHBhdGgYASABKAlSBHBhdGg=');

@$core.Deprecated('Use enableAutosaveDescriptor instead')
const EnableAutosave$json = {
  '1': 'EnableAutosave',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `EnableAutosave`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enableAutosaveDescriptor =
    $convert.base64Decode('Cg5FbmFibGVBdXRvc2F2ZRISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use setExportSettingsDescriptor instead')
const SetExportSettings$json = {
  '1': 'SetExportSettings',
  '2': [
    {
      '1': 'resolution',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.ExportResolution',
      '10': 'resolution'
    },
    {
      '1': 'fps',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.ExportFps',
      '10': 'fps'
    },
    {'1': 'kbps', '3': 3, '4': 1, '5': 13, '10': 'kbps'},
  ],
};

/// Descriptor for `SetExportSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setExportSettingsDescriptor = $convert.base64Decode(
    'ChFTZXRFeHBvcnRTZXR0aW5ncxI7CgpyZXNvbHV0aW9uGAEgASgOMhsuZnJhbWl4LnYxLkV4cG'
    '9ydFJlc29sdXRpb25SCnJlc29sdXRpb24SJgoDZnBzGAIgASgOMhQuZnJhbWl4LnYxLkV4cG9y'
    'dEZwc1IDZnBzEhIKBGticHMYAyABKA1SBGticHM=');

@$core.Deprecated('Use exportInfoDescriptor instead')
const ExportInfo$json = {
  '1': 'ExportInfo',
  '2': [
    {
      '1': 'resolution',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.ExportResolution',
      '10': 'resolution'
    },
    {
      '1': 'fps',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.ExportFps',
      '10': 'fps'
    },
    {'1': 'kbps', '3': 3, '4': 1, '5': 13, '10': 'kbps'},
    {'1': 'width', '3': 4, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 5, '4': 1, '5': 13, '10': 'height'},
    {'1': 'effective_kbps', '3': 6, '4': 1, '5': 13, '10': 'effectiveKbps'},
    {'1': 'estimated_bytes', '3': 7, '4': 1, '5': 4, '10': 'estimatedBytes'},
  ],
};

/// Descriptor for `ExportInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportInfoDescriptor = $convert.base64Decode(
    'CgpFeHBvcnRJbmZvEjsKCnJlc29sdXRpb24YASABKA4yGy5mcmFtaXgudjEuRXhwb3J0UmVzb2'
    'x1dGlvblIKcmVzb2x1dGlvbhImCgNmcHMYAiABKA4yFC5mcmFtaXgudjEuRXhwb3J0RnBzUgNm'
    'cHMSEgoEa2JwcxgDIAEoDVIEa2JwcxIUCgV3aWR0aBgEIAEoDVIFd2lkdGgSFgoGaGVpZ2h0GA'
    'UgASgNUgZoZWlnaHQSJQoOZWZmZWN0aXZlX2ticHMYBiABKA1SDWVmZmVjdGl2ZUticHMSJwoP'
    'ZXN0aW1hdGVkX2J5dGVzGAcgASgEUg5lc3RpbWF0ZWRCeXRlcw==');

@$core.Deprecated('Use replaceClipDescriptor instead')
const ReplaceClip$json = {
  '1': 'ReplaceClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
    {
      '1': 'media',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.MediaItem',
      '10': 'media'
    },
  ],
};

/// Descriptor for `ReplaceClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replaceClipDescriptor = $convert.base64Decode(
    'CgtSZXBsYWNlQ2xpcBIXCgdjbGlwX2lkGAEgASgEUgZjbGlwSWQSKgoFbWVkaWEYAiABKAsyFC'
    '5mcmFtaXgudjEuTWVkaWFJdGVtUgVtZWRpYQ==');

@$core.Deprecated('Use setClipTransformDescriptor instead')
const SetClipTransform$json = {
  '1': 'SetClipTransform',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
    {'1': 'rotation', '3': 2, '4': 1, '5': 13, '10': 'rotation'},
    {'1': 'flip_h', '3': 3, '4': 1, '5': 8, '10': 'flipH'},
    {'1': 'flip_v', '3': 4, '4': 1, '5': 8, '10': 'flipV'},
    {'1': 'crop_left', '3': 5, '4': 1, '5': 13, '10': 'cropLeft'},
    {'1': 'crop_top', '3': 6, '4': 1, '5': 13, '10': 'cropTop'},
    {'1': 'crop_right', '3': 7, '4': 1, '5': 13, '10': 'cropRight'},
    {'1': 'crop_bottom', '3': 8, '4': 1, '5': 13, '10': 'cropBottom'},
    {'1': 'x', '3': 9, '4': 1, '5': 5, '10': 'x'},
    {'1': 'y', '3': 10, '4': 1, '5': 5, '10': 'y'},
    {'1': 'scale', '3': 11, '4': 1, '5': 13, '10': 'scale'},
    {'1': 'gesture', '3': 12, '4': 1, '5': 4, '10': 'gesture'},
  ],
};

/// Descriptor for `SetClipTransform`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setClipTransformDescriptor = $convert.base64Decode(
    'ChBTZXRDbGlwVHJhbnNmb3JtEhcKB2NsaXBfaWQYASABKARSBmNsaXBJZBIaCghyb3RhdGlvbh'
    'gCIAEoDVIIcm90YXRpb24SFQoGZmxpcF9oGAMgASgIUgVmbGlwSBIVCgZmbGlwX3YYBCABKAhS'
    'BWZsaXBWEhsKCWNyb3BfbGVmdBgFIAEoDVIIY3JvcExlZnQSGQoIY3JvcF90b3AYBiABKA1SB2'
    'Nyb3BUb3ASHQoKY3JvcF9yaWdodBgHIAEoDVIJY3JvcFJpZ2h0Eh8KC2Nyb3BfYm90dG9tGAgg'
    'ASgNUgpjcm9wQm90dG9tEgwKAXgYCSABKAVSAXgSDAoBeRgKIAEoBVIBeRIUCgVzY2FsZRgLIA'
    'EoDVIFc2NhbGUSGAoHZ2VzdHVyZRgMIAEoBFIHZ2VzdHVyZQ==');

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

@$core.Deprecated('Use setAspectRatioDescriptor instead')
const SetAspectRatio$json = {
  '1': 'SetAspectRatio',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 13, '10': 'height'},
  ],
};

/// Descriptor for `SetAspectRatio`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setAspectRatioDescriptor = $convert.base64Decode(
    'Cg5TZXRBc3BlY3RSYXRpbxIUCgV3aWR0aBgBIAEoDVIFd2lkdGgSFgoGaGVpZ2h0GAIgASgNUg'
    'ZoZWlnaHQ=');

@$core.Deprecated('Use removeClipDescriptor instead')
const RemoveClip$json = {
  '1': 'RemoveClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
  ],
};

/// Descriptor for `RemoveClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeClipDescriptor = $convert
    .base64Decode('CgpSZW1vdmVDbGlwEhcKB2NsaXBfaWQYASABKARSBmNsaXBJZA==');

@$core.Deprecated('Use splitClipDescriptor instead')
const SplitClip$json = {
  '1': 'SplitClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
  ],
};

/// Descriptor for `SplitClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List splitClipDescriptor = $convert.base64Decode(
    'CglTcGxpdENsaXASFwoHY2xpcF9pZBgBIAEoBFIGY2xpcElkEg4KAmF0GAIgASgDUgJhdA==');

@$core.Deprecated('Use mergeClipsDescriptor instead')
const MergeClips$json = {
  '1': 'MergeClips',
  '2': [
    {'1': 'left_id', '3': 1, '4': 1, '5': 4, '10': 'leftId'},
    {'1': 'right_id', '3': 2, '4': 1, '5': 4, '10': 'rightId'},
  ],
};

/// Descriptor for `MergeClips`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeClipsDescriptor = $convert.base64Decode(
    'CgpNZXJnZUNsaXBzEhcKB2xlZnRfaWQYASABKARSBmxlZnRJZBIZCghyaWdodF9pZBgCIAEoBF'
    'IHcmlnaHRJZA==');

@$core.Deprecated('Use trimClipDescriptor instead')
const TrimClip$json = {
  '1': 'TrimClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
    {'1': 'start', '3': 2, '4': 1, '5': 3, '10': 'start'},
    {'1': 'end', '3': 3, '4': 1, '5': 3, '10': 'end'},
  ],
};

/// Descriptor for `TrimClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trimClipDescriptor = $convert.base64Decode(
    'CghUcmltQ2xpcBIXCgdjbGlwX2lkGAEgASgEUgZjbGlwSWQSFAoFc3RhcnQYAiABKANSBXN0YX'
    'J0EhAKA2VuZBgDIAEoA1IDZW5k');

@$core.Deprecated('Use duplicateClipDescriptor instead')
const DuplicateClip$json = {
  '1': 'DuplicateClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
  ],
};

/// Descriptor for `DuplicateClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List duplicateClipDescriptor = $convert
    .base64Decode('Cg1EdXBsaWNhdGVDbGlwEhcKB2NsaXBfaWQYASABKARSBmNsaXBJZA==');

@$core.Deprecated('Use setTrackFlagsDescriptor instead')
const SetTrackFlags$json = {
  '1': 'SetTrackFlags',
  '2': [
    {'1': 'track_id', '3': 1, '4': 1, '5': 4, '10': 'trackId'},
    {'1': 'muted', '3': 2, '4': 1, '5': 8, '9': 0, '10': 'muted', '17': true},
    {'1': 'hidden', '3': 3, '4': 1, '5': 8, '9': 1, '10': 'hidden', '17': true},
    {'1': 'locked', '3': 4, '4': 1, '5': 8, '9': 2, '10': 'locked', '17': true},
  ],
  '8': [
    {'1': '_muted'},
    {'1': '_hidden'},
    {'1': '_locked'},
  ],
};

/// Descriptor for `SetTrackFlags`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTrackFlagsDescriptor = $convert.base64Decode(
    'Cg1TZXRUcmFja0ZsYWdzEhkKCHRyYWNrX2lkGAEgASgEUgd0cmFja0lkEhkKBW11dGVkGAIgAS'
    'gISABSBW11dGVkiAEBEhsKBmhpZGRlbhgDIAEoCEgBUgZoaWRkZW6IAQESGwoGbG9ja2VkGAQg'
    'ASgISAJSBmxvY2tlZIgBAUIICgZfbXV0ZWRCCQoHX2hpZGRlbkIJCgdfbG9ja2Vk');

@$core.Deprecated('Use moveClipDescriptor instead')
const MoveClip$json = {
  '1': 'MoveClip',
  '2': [
    {'1': 'clip_id', '3': 1, '4': 1, '5': 4, '10': 'clipId'},
    {'1': 'track_id', '3': 2, '4': 1, '5': 4, '10': 'trackId'},
    {'1': 'start', '3': 3, '4': 1, '5': 3, '10': 'start'},
  ],
};

/// Descriptor for `MoveClip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveClipDescriptor = $convert.base64Decode(
    'CghNb3ZlQ2xpcBIXCgdjbGlwX2lkGAEgASgEUgZjbGlwSWQSGQoIdHJhY2tfaWQYAiABKARSB3'
    'RyYWNrSWQSFAoFc3RhcnQYAyABKANSBXN0YXJ0');

@$core.Deprecated('Use importMediaDescriptor instead')
const ImportMedia$json = {
  '1': 'ImportMedia',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.framix.v1.MediaItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `ImportMedia`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importMediaDescriptor = $convert.base64Decode(
    'CgtJbXBvcnRNZWRpYRIqCgVpdGVtcxgBIAMoCzIULmZyYW1peC52MS5NZWRpYUl0ZW1SBWl0ZW'
    '1z');

@$core.Deprecated('Use mediaItemDescriptor instead')
const MediaItem$json = {
  '1': 'MediaItem',
  '2': [
    {'1': 'uri', '3': 1, '4': 1, '5': 9, '10': 'uri'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.MediaKind',
      '10': 'kind'
    },
    {'1': 'duration_value', '3': 3, '4': 1, '5': 3, '10': 'durationValue'},
    {
      '1': 'duration_timescale',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'durationTimescale'
    },
    {'1': 'width', '3': 5, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 13, '10': 'height'},
    {'1': 'rotation', '3': 7, '4': 1, '5': 13, '10': 'rotation'},
    {'1': 'codec', '3': 8, '4': 1, '5': 9, '10': 'codec'},
  ],
};

/// Descriptor for `MediaItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mediaItemDescriptor = $convert.base64Decode(
    'CglNZWRpYUl0ZW0SEAoDdXJpGAEgASgJUgN1cmkSKAoEa2luZBgCIAEoDjIULmZyYW1peC52MS'
    '5NZWRpYUtpbmRSBGtpbmQSJQoOZHVyYXRpb25fdmFsdWUYAyABKANSDWR1cmF0aW9uVmFsdWUS'
    'LQoSZHVyYXRpb25fdGltZXNjYWxlGAQgASgNUhFkdXJhdGlvblRpbWVzY2FsZRIUCgV3aWR0aB'
    'gFIAEoDVIFd2lkdGgSFgoGaGVpZ2h0GAYgASgNUgZoZWlnaHQSGgoIcm90YXRpb24YByABKA1S'
    'CHJvdGF0aW9uEhQKBWNvZGVjGAggASgJUgVjb2RlYw==');

@$core.Deprecated('Use createPreviewDescriptor instead')
const CreatePreview$json = {
  '1': 'CreatePreview',
  '2': [
    {'1': 'width', '3': 1, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 2, '4': 1, '5': 13, '10': 'height'},
  ],
};

/// Descriptor for `CreatePreview`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPreviewDescriptor = $convert.base64Decode(
    'Cg1DcmVhdGVQcmV2aWV3EhQKBXdpZHRoGAEgASgNUgV3aWR0aBIWCgZoZWlnaHQYAiABKA1SBm'
    'hlaWdodA==');

@$core.Deprecated('Use requestThumbnailsDescriptor instead')
const RequestThumbnails$json = {
  '1': 'RequestThumbnails',
  '2': [
    {'1': 'media_id', '3': 1, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'times', '3': 2, '4': 3, '5': 3, '10': 'times'},
    {'1': 'max_side', '3': 3, '4': 1, '5': 13, '10': 'maxSide'},
  ],
};

/// Descriptor for `RequestThumbnails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestThumbnailsDescriptor = $convert.base64Decode(
    'ChFSZXF1ZXN0VGh1bWJuYWlscxIZCghtZWRpYV9pZBgBIAEoBFIHbWVkaWFJZBIUCgV0aW1lcx'
    'gCIAMoA1IFdGltZXMSGQoIbWF4X3NpZGUYAyABKA1SB21heFNpZGU=');

@$core.Deprecated('Use seekDescriptor instead')
const Seek$json = {
  '1': 'Seek',
  '2': [
    {'1': 'time', '3': 1, '4': 1, '5': 3, '10': 'time'},
    {'1': 'snap_within', '3': 2, '4': 1, '5': 3, '10': 'snapWithin'},
  ],
};

/// Descriptor for `Seek`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seekDescriptor = $convert.base64Decode(
    'CgRTZWVrEhIKBHRpbWUYASABKANSBHRpbWUSHwoLc25hcF93aXRoaW4YAiABKANSCnNuYXBXaX'
    'RoaW4=');

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
    {
      '1': 'command_accepted',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.CommandAccepted',
      '9': 0,
      '10': 'commandAccepted'
    },
    {
      '1': 'preview_ready',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.PreviewReady',
      '9': 0,
      '10': 'previewReady'
    },
    {
      '1': 'playhead_changed',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.PlayheadChanged',
      '9': 0,
      '10': 'playheadChanged'
    },
    {
      '1': 'thumbnail_ready',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ThumbnailReady',
      '9': 0,
      '10': 'thumbnailReady'
    },
    {
      '1': 'engine_stopped',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.EngineStopped',
      '9': 0,
      '10': 'engineStopped'
    },
    {
      '1': 'export_finished',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ExportFinished',
      '9': 0,
      '10': 'exportFinished'
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
    'ABKAsyFy5mcmFtaXgudjEuUHJvamVjdFNhdmVkSABSDHByb2plY3RTYXZlZBJHChBjb21tYW5k'
    'X2FjY2VwdGVkGAQgASgLMhouZnJhbWl4LnYxLkNvbW1hbmRBY2NlcHRlZEgAUg9jb21tYW5kQW'
    'NjZXB0ZWQSPgoNcHJldmlld19yZWFkeRgFIAEoCzIXLmZyYW1peC52MS5QcmV2aWV3UmVhZHlI'
    'AFIMcHJldmlld1JlYWR5EkcKEHBsYXloZWFkX2NoYW5nZWQYBiABKAsyGi5mcmFtaXgudjEuUG'
    'xheWhlYWRDaGFuZ2VkSABSD3BsYXloZWFkQ2hhbmdlZBJECg90aHVtYm5haWxfcmVhZHkYByAB'
    'KAsyGS5mcmFtaXgudjEuVGh1bWJuYWlsUmVhZHlIAFIOdGh1bWJuYWlsUmVhZHkSQQoOZW5naW'
    '5lX3N0b3BwZWQYCCABKAsyGC5mcmFtaXgudjEuRW5naW5lU3RvcHBlZEgAUg1lbmdpbmVTdG9w'
    'cGVkEkQKD2V4cG9ydF9maW5pc2hlZBgJIAEoCzIZLmZyYW1peC52MS5FeHBvcnRGaW5pc2hlZE'
    'gAUg5leHBvcnRGaW5pc2hlZEIGCgRraW5k');

@$core.Deprecated('Use exportFinishedDescriptor instead')
const ExportFinished$json = {
  '1': 'ExportFinished',
  '2': [
    {'1': 'ok', '3': 1, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `ExportFinished`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportFinishedDescriptor = $convert.base64Decode(
    'Cg5FeHBvcnRGaW5pc2hlZBIOCgJvaxgBIAEoCFICb2sSFgoGcmVhc29uGAIgASgJUgZyZWFzb2'
    '4=');

@$core.Deprecated('Use engineStoppedDescriptor instead')
const EngineStopped$json = {
  '1': 'EngineStopped',
};

/// Descriptor for `EngineStopped`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List engineStoppedDescriptor =
    $convert.base64Decode('Cg1FbmdpbmVTdG9wcGVk');

@$core.Deprecated('Use thumbnailReadyDescriptor instead')
const ThumbnailReady$json = {
  '1': 'ThumbnailReady',
  '2': [
    {'1': 'media_id', '3': 1, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'time', '3': 2, '4': 1, '5': 3, '10': 'time'},
    {'1': 'max_side', '3': 3, '4': 1, '5': 13, '10': 'maxSide'},
    {'1': 'path', '3': 4, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `ThumbnailReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List thumbnailReadyDescriptor = $convert.base64Decode(
    'Cg5UaHVtYm5haWxSZWFkeRIZCghtZWRpYV9pZBgBIAEoBFIHbWVkaWFJZBISCgR0aW1lGAIgAS'
    'gDUgR0aW1lEhkKCG1heF9zaWRlGAMgASgNUgdtYXhTaWRlEhIKBHBhdGgYBCABKAlSBHBhdGg=');

@$core.Deprecated('Use playheadChangedDescriptor instead')
const PlayheadChanged$json = {
  '1': 'PlayheadChanged',
  '2': [
    {'1': 'time', '3': 1, '4': 1, '5': 3, '10': 'time'},
    {'1': 'snapped', '3': 2, '4': 1, '5': 8, '10': 'snapped'},
    {'1': 'active_clip', '3': 3, '4': 1, '5': 4, '10': 'activeClip'},
  ],
};

/// Descriptor for `PlayheadChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List playheadChangedDescriptor = $convert.base64Decode(
    'Cg9QbGF5aGVhZENoYW5nZWQSEgoEdGltZRgBIAEoA1IEdGltZRIYCgdzbmFwcGVkGAIgASgIUg'
    'dzbmFwcGVkEh8KC2FjdGl2ZV9jbGlwGAMgASgEUgphY3RpdmVDbGlw');

@$core.Deprecated('Use commandAcceptedDescriptor instead')
const CommandAccepted$json = {
  '1': 'CommandAccepted',
};

/// Descriptor for `CommandAccepted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandAcceptedDescriptor =
    $convert.base64Decode('Cg9Db21tYW5kQWNjZXB0ZWQ=');

@$core.Deprecated('Use previewReadyDescriptor instead')
const PreviewReady$json = {
  '1': 'PreviewReady',
  '2': [
    {'1': 'texture_id', '3': 1, '4': 1, '5': 3, '10': 'textureId'},
  ],
};

/// Descriptor for `PreviewReady`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List previewReadyDescriptor = $convert.base64Decode(
    'CgxQcmV2aWV3UmVhZHkSHQoKdGV4dHVyZV9pZBgBIAEoA1IJdGV4dHVyZUlk');

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
    {'1': 'aspect_width', '3': 5, '4': 1, '5': 13, '10': 'aspectWidth'},
    {'1': 'aspect_height', '3': 6, '4': 1, '5': 13, '10': 'aspectHeight'},
    {'1': 'playhead', '3': 7, '4': 1, '5': 3, '10': 'playhead'},
    {'1': 'ticks_per_second', '3': 8, '4': 1, '5': 3, '10': 'ticksPerSecond'},
    {'1': 'thumbnail_step', '3': 9, '4': 1, '5': 3, '10': 'thumbnailStep'},
    {'1': 'active_clip', '3': 10, '4': 1, '5': 4, '10': 'activeClip'},
    {
      '1': 'export',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.framix.v1.ExportInfo',
      '10': 'export'
    },
  ],
};

/// Descriptor for `TimelineChanged`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timelineChangedDescriptor = $convert.base64Decode(
    'Cg9UaW1lbGluZUNoYW5nZWQSKAoGdHJhY2tzGAEgAygLMhAuZnJhbWl4LnYxLlRyYWNrUgZ0cm'
    'Fja3MSGgoIZHVyYXRpb24YAiABKANSCGR1cmF0aW9uEhkKCGNhbl91bmRvGAMgASgIUgdjYW5V'
    'bmRvEhkKCGNhbl9yZWRvGAQgASgIUgdjYW5SZWRvEiEKDGFzcGVjdF93aWR0aBgFIAEoDVILYX'
    'NwZWN0V2lkdGgSIwoNYXNwZWN0X2hlaWdodBgGIAEoDVIMYXNwZWN0SGVpZ2h0EhoKCHBsYXlo'
    'ZWFkGAcgASgDUghwbGF5aGVhZBIoChB0aWNrc19wZXJfc2Vjb25kGAggASgDUg50aWNrc1Blcl'
    'NlY29uZBIlCg50aHVtYm5haWxfc3RlcBgJIAEoA1INdGh1bWJuYWlsU3RlcBIfCgthY3RpdmVf'
    'Y2xpcBgKIAEoBFIKYWN0aXZlQ2xpcBItCgZleHBvcnQYCyABKAsyFS5mcmFtaXgudjEuRXhwb3'
    'J0SW5mb1IGZXhwb3J0');

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
    {'1': 'muted', '3': 5, '4': 1, '5': 8, '10': 'muted'},
    {'1': 'hidden', '3': 6, '4': 1, '5': 8, '10': 'hidden'},
    {'1': 'locked', '3': 7, '4': 1, '5': 8, '10': 'locked'},
  ],
};

/// Descriptor for `Track`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trackDescriptor = $convert.base64Decode(
    'CgVUcmFjaxIOCgJpZBgBIAEoBFICaWQSKAoEa2luZBgCIAEoDjIULmZyYW1peC52MS5UcmFja0'
    'tpbmRSBGtpbmQSJQoFY2xpcHMYAyADKAsyDy5mcmFtaXgudjEuQ2xpcFIFY2xpcHMSFgoGbnVt'
    'YmVyGAQgASgNUgZudW1iZXISFAoFbXV0ZWQYBSABKAhSBW11dGVkEhYKBmhpZGRlbhgGIAEoCF'
    'IGaGlkZGVuEhYKBmxvY2tlZBgHIAEoCFIGbG9ja2Vk');

@$core.Deprecated('Use clipDescriptor instead')
const Clip$json = {
  '1': 'Clip',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'media_id', '3': 2, '4': 1, '5': 4, '10': 'mediaId'},
    {'1': 'source_start', '3': 3, '4': 1, '5': 3, '10': 'sourceStart'},
    {'1': 'start', '3': 4, '4': 1, '5': 3, '10': 'start'},
    {'1': 'duration', '3': 5, '4': 1, '5': 3, '10': 'duration'},
    {
      '1': 'media_kind',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.framix.v1.MediaKind',
      '10': 'mediaKind'
    },
    {'1': 'rotation', '3': 7, '4': 1, '5': 13, '10': 'rotation'},
    {'1': 'flip_h', '3': 8, '4': 1, '5': 8, '10': 'flipH'},
    {'1': 'flip_v', '3': 9, '4': 1, '5': 8, '10': 'flipV'},
    {'1': 'crop_left', '3': 10, '4': 1, '5': 13, '10': 'cropLeft'},
    {'1': 'crop_top', '3': 11, '4': 1, '5': 13, '10': 'cropTop'},
    {'1': 'crop_right', '3': 12, '4': 1, '5': 13, '10': 'cropRight'},
    {'1': 'crop_bottom', '3': 13, '4': 1, '5': 13, '10': 'cropBottom'},
    {'1': 'x', '3': 14, '4': 1, '5': 5, '10': 'x'},
    {'1': 'y', '3': 15, '4': 1, '5': 5, '10': 'y'},
    {'1': 'scale', '3': 16, '4': 1, '5': 13, '10': 'scale'},
  ],
};

/// Descriptor for `Clip`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clipDescriptor = $convert.base64Decode(
    'CgRDbGlwEg4KAmlkGAEgASgEUgJpZBIZCghtZWRpYV9pZBgCIAEoBFIHbWVkaWFJZBIhCgxzb3'
    'VyY2Vfc3RhcnQYAyABKANSC3NvdXJjZVN0YXJ0EhQKBXN0YXJ0GAQgASgDUgVzdGFydBIaCghk'
    'dXJhdGlvbhgFIAEoA1IIZHVyYXRpb24SMwoKbWVkaWFfa2luZBgGIAEoDjIULmZyYW1peC52MS'
    '5NZWRpYUtpbmRSCW1lZGlhS2luZBIaCghyb3RhdGlvbhgHIAEoDVIIcm90YXRpb24SFQoGZmxp'
    'cF9oGAggASgIUgVmbGlwSBIVCgZmbGlwX3YYCSABKAhSBWZsaXBWEhsKCWNyb3BfbGVmdBgKIA'
    'EoDVIIY3JvcExlZnQSGQoIY3JvcF90b3AYCyABKA1SB2Nyb3BUb3ASHQoKY3JvcF9yaWdodBgM'
    'IAEoDVIJY3JvcFJpZ2h0Eh8KC2Nyb3BfYm90dG9tGA0gASgNUgpjcm9wQm90dG9tEgwKAXgYDi'
    'ABKAVSAXgSDAoBeRgPIAEoBVIBeRIUCgVzY2FsZRgQIAEoDVIFc2NhbGU=');

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
