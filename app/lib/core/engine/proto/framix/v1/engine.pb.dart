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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'engine.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'engine.pbenum.dart';

enum Command_Kind {
  addTrack,
  insertClip,
  undo,
  redo,
  getTimeline,
  newProject,
  saveProject,
  openProject,
  setAspectRatio,
  removeClip,
  splitClip,
  mergeClips,
  trimClip,
  duplicateClip,
  setTrackFlags,
  moveClip,
  importMedia,
  createPreview,
  seek,
  requestThumbnails,
  notSet
}

/// Sent by the UI. Exactly one kind is set.
class Command extends $pb.GeneratedMessage {
  factory Command({
    AddTrack? addTrack,
    InsertClip? insertClip,
    Undo? undo,
    Redo? redo,
    GetTimeline? getTimeline,
    NewProject? newProject,
    SaveProject? saveProject,
    OpenProject? openProject,
    SetAspectRatio? setAspectRatio,
    RemoveClip? removeClip,
    SplitClip? splitClip,
    MergeClips? mergeClips,
    TrimClip? trimClip,
    DuplicateClip? duplicateClip,
    SetTrackFlags? setTrackFlags,
    MoveClip? moveClip,
    ImportMedia? importMedia,
    CreatePreview? createPreview,
    Seek? seek,
    RequestThumbnails? requestThumbnails,
  }) {
    final result = Command._();
    if (addTrack != null) result.addTrack = addTrack;
    if (insertClip != null) result.insertClip = insertClip;
    if (undo != null) result.undo = undo;
    if (redo != null) result.redo = redo;
    if (getTimeline != null) result.getTimeline = getTimeline;
    if (newProject != null) result.newProject = newProject;
    if (saveProject != null) result.saveProject = saveProject;
    if (openProject != null) result.openProject = openProject;
    if (setAspectRatio != null) result.setAspectRatio = setAspectRatio;
    if (removeClip != null) result.removeClip = removeClip;
    if (splitClip != null) result.splitClip = splitClip;
    if (mergeClips != null) result.mergeClips = mergeClips;
    if (trimClip != null) result.trimClip = trimClip;
    if (duplicateClip != null) result.duplicateClip = duplicateClip;
    if (setTrackFlags != null) result.setTrackFlags = setTrackFlags;
    if (moveClip != null) result.moveClip = moveClip;
    if (importMedia != null) result.importMedia = importMedia;
    if (createPreview != null) result.createPreview = createPreview;
    if (seek != null) result.seek = seek;
    if (requestThumbnails != null) result.requestThumbnails = requestThumbnails;
    return result;
  }

  Command._();

  factory Command.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromBuffer(data, registry);
  factory Command.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Command_Kind> _Command_KindByTag = {
    1: Command_Kind.addTrack,
    2: Command_Kind.insertClip,
    3: Command_Kind.undo,
    4: Command_Kind.redo,
    5: Command_Kind.getTimeline,
    6: Command_Kind.newProject,
    7: Command_Kind.saveProject,
    8: Command_Kind.openProject,
    9: Command_Kind.setAspectRatio,
    10: Command_Kind.removeClip,
    11: Command_Kind.splitClip,
    12: Command_Kind.mergeClips,
    13: Command_Kind.trimClip,
    14: Command_Kind.duplicateClip,
    15: Command_Kind.setTrackFlags,
    16: Command_Kind.moveClip,
    17: Command_Kind.importMedia,
    18: Command_Kind.createPreview,
    19: Command_Kind.seek,
    20: Command_Kind.requestThumbnails,
    0: Command_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Command',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Command.$_createMessage)
    ..oo(0,
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20])
    ..aOM<AddTrack>(1, _omitFieldNames ? '' : 'addTrack',
        subBuilder: AddTrack.$_createMessage)
    ..aOM<InsertClip>(2, _omitFieldNames ? '' : 'insertClip',
        subBuilder: InsertClip.$_createMessage)
    ..aOM<Undo>(3, _omitFieldNames ? '' : 'undo',
        subBuilder: Undo.$_createMessage)
    ..aOM<Redo>(4, _omitFieldNames ? '' : 'redo',
        subBuilder: Redo.$_createMessage)
    ..aOM<GetTimeline>(5, _omitFieldNames ? '' : 'getTimeline',
        subBuilder: GetTimeline.$_createMessage)
    ..aOM<NewProject>(6, _omitFieldNames ? '' : 'newProject',
        subBuilder: NewProject.$_createMessage)
    ..aOM<SaveProject>(7, _omitFieldNames ? '' : 'saveProject',
        subBuilder: SaveProject.$_createMessage)
    ..aOM<OpenProject>(8, _omitFieldNames ? '' : 'openProject',
        subBuilder: OpenProject.$_createMessage)
    ..aOM<SetAspectRatio>(9, _omitFieldNames ? '' : 'setAspectRatio',
        subBuilder: SetAspectRatio.$_createMessage)
    ..aOM<RemoveClip>(10, _omitFieldNames ? '' : 'removeClip',
        subBuilder: RemoveClip.$_createMessage)
    ..aOM<SplitClip>(11, _omitFieldNames ? '' : 'splitClip',
        subBuilder: SplitClip.$_createMessage)
    ..aOM<MergeClips>(12, _omitFieldNames ? '' : 'mergeClips',
        subBuilder: MergeClips.$_createMessage)
    ..aOM<TrimClip>(13, _omitFieldNames ? '' : 'trimClip',
        subBuilder: TrimClip.$_createMessage)
    ..aOM<DuplicateClip>(14, _omitFieldNames ? '' : 'duplicateClip',
        subBuilder: DuplicateClip.$_createMessage)
    ..aOM<SetTrackFlags>(15, _omitFieldNames ? '' : 'setTrackFlags',
        subBuilder: SetTrackFlags.$_createMessage)
    ..aOM<MoveClip>(16, _omitFieldNames ? '' : 'moveClip',
        subBuilder: MoveClip.$_createMessage)
    ..aOM<ImportMedia>(17, _omitFieldNames ? '' : 'importMedia',
        subBuilder: ImportMedia.$_createMessage)
    ..aOM<CreatePreview>(18, _omitFieldNames ? '' : 'createPreview',
        subBuilder: CreatePreview.$_createMessage)
    ..aOM<Seek>(19, _omitFieldNames ? '' : 'seek',
        subBuilder: Seek.$_createMessage)
    ..aOM<RequestThumbnails>(20, _omitFieldNames ? '' : 'requestThumbnails',
        subBuilder: RequestThumbnails.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command copyWith(void Function(Command) updates) =>
      super.copyWith((message) => updates(message as Command)) as Command;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Command() / Command.new instead')
  static Command create() => Command._();
  static $pb.GeneratedMessage $_createMessage() => Command._();
  @$core.override
  Command createEmptyInstance() => Command._();
  @$core.pragma('dart2js:noInline')
  static Command getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Command>(Command.$_createMessage);
  static Command? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  Command_Kind whichKind() => _Command_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  AddTrack get addTrack => $_getN(0);
  @$pb.TagNumber(1)
  set addTrack(AddTrack value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAddTrack() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddTrack() => $_clearField(1);
  @$pb.TagNumber(1)
  AddTrack ensureAddTrack() => $_ensure(0);

  @$pb.TagNumber(2)
  InsertClip get insertClip => $_getN(1);
  @$pb.TagNumber(2)
  set insertClip(InsertClip value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasInsertClip() => $_has(1);
  @$pb.TagNumber(2)
  void clearInsertClip() => $_clearField(2);
  @$pb.TagNumber(2)
  InsertClip ensureInsertClip() => $_ensure(1);

  @$pb.TagNumber(3)
  Undo get undo => $_getN(2);
  @$pb.TagNumber(3)
  set undo(Undo value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUndo() => $_has(2);
  @$pb.TagNumber(3)
  void clearUndo() => $_clearField(3);
  @$pb.TagNumber(3)
  Undo ensureUndo() => $_ensure(2);

  @$pb.TagNumber(4)
  Redo get redo => $_getN(3);
  @$pb.TagNumber(4)
  set redo(Redo value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRedo() => $_has(3);
  @$pb.TagNumber(4)
  void clearRedo() => $_clearField(4);
  @$pb.TagNumber(4)
  Redo ensureRedo() => $_ensure(3);

  @$pb.TagNumber(5)
  GetTimeline get getTimeline => $_getN(4);
  @$pb.TagNumber(5)
  set getTimeline(GetTimeline value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasGetTimeline() => $_has(4);
  @$pb.TagNumber(5)
  void clearGetTimeline() => $_clearField(5);
  @$pb.TagNumber(5)
  GetTimeline ensureGetTimeline() => $_ensure(4);

  @$pb.TagNumber(6)
  NewProject get newProject => $_getN(5);
  @$pb.TagNumber(6)
  set newProject(NewProject value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasNewProject() => $_has(5);
  @$pb.TagNumber(6)
  void clearNewProject() => $_clearField(6);
  @$pb.TagNumber(6)
  NewProject ensureNewProject() => $_ensure(5);

  @$pb.TagNumber(7)
  SaveProject get saveProject => $_getN(6);
  @$pb.TagNumber(7)
  set saveProject(SaveProject value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasSaveProject() => $_has(6);
  @$pb.TagNumber(7)
  void clearSaveProject() => $_clearField(7);
  @$pb.TagNumber(7)
  SaveProject ensureSaveProject() => $_ensure(6);

  @$pb.TagNumber(8)
  OpenProject get openProject => $_getN(7);
  @$pb.TagNumber(8)
  set openProject(OpenProject value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasOpenProject() => $_has(7);
  @$pb.TagNumber(8)
  void clearOpenProject() => $_clearField(8);
  @$pb.TagNumber(8)
  OpenProject ensureOpenProject() => $_ensure(7);

  @$pb.TagNumber(9)
  SetAspectRatio get setAspectRatio => $_getN(8);
  @$pb.TagNumber(9)
  set setAspectRatio(SetAspectRatio value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSetAspectRatio() => $_has(8);
  @$pb.TagNumber(9)
  void clearSetAspectRatio() => $_clearField(9);
  @$pb.TagNumber(9)
  SetAspectRatio ensureSetAspectRatio() => $_ensure(8);

  @$pb.TagNumber(10)
  RemoveClip get removeClip => $_getN(9);
  @$pb.TagNumber(10)
  set removeClip(RemoveClip value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRemoveClip() => $_has(9);
  @$pb.TagNumber(10)
  void clearRemoveClip() => $_clearField(10);
  @$pb.TagNumber(10)
  RemoveClip ensureRemoveClip() => $_ensure(9);

  @$pb.TagNumber(11)
  SplitClip get splitClip => $_getN(10);
  @$pb.TagNumber(11)
  set splitClip(SplitClip value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasSplitClip() => $_has(10);
  @$pb.TagNumber(11)
  void clearSplitClip() => $_clearField(11);
  @$pb.TagNumber(11)
  SplitClip ensureSplitClip() => $_ensure(10);

  @$pb.TagNumber(12)
  MergeClips get mergeClips => $_getN(11);
  @$pb.TagNumber(12)
  set mergeClips(MergeClips value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasMergeClips() => $_has(11);
  @$pb.TagNumber(12)
  void clearMergeClips() => $_clearField(12);
  @$pb.TagNumber(12)
  MergeClips ensureMergeClips() => $_ensure(11);

  @$pb.TagNumber(13)
  TrimClip get trimClip => $_getN(12);
  @$pb.TagNumber(13)
  set trimClip(TrimClip value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasTrimClip() => $_has(12);
  @$pb.TagNumber(13)
  void clearTrimClip() => $_clearField(13);
  @$pb.TagNumber(13)
  TrimClip ensureTrimClip() => $_ensure(12);

  @$pb.TagNumber(14)
  DuplicateClip get duplicateClip => $_getN(13);
  @$pb.TagNumber(14)
  set duplicateClip(DuplicateClip value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasDuplicateClip() => $_has(13);
  @$pb.TagNumber(14)
  void clearDuplicateClip() => $_clearField(14);
  @$pb.TagNumber(14)
  DuplicateClip ensureDuplicateClip() => $_ensure(13);

  @$pb.TagNumber(15)
  SetTrackFlags get setTrackFlags => $_getN(14);
  @$pb.TagNumber(15)
  set setTrackFlags(SetTrackFlags value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasSetTrackFlags() => $_has(14);
  @$pb.TagNumber(15)
  void clearSetTrackFlags() => $_clearField(15);
  @$pb.TagNumber(15)
  SetTrackFlags ensureSetTrackFlags() => $_ensure(14);

  @$pb.TagNumber(16)
  MoveClip get moveClip => $_getN(15);
  @$pb.TagNumber(16)
  set moveClip(MoveClip value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasMoveClip() => $_has(15);
  @$pb.TagNumber(16)
  void clearMoveClip() => $_clearField(16);
  @$pb.TagNumber(16)
  MoveClip ensureMoveClip() => $_ensure(15);

  @$pb.TagNumber(17)
  ImportMedia get importMedia => $_getN(16);
  @$pb.TagNumber(17)
  set importMedia(ImportMedia value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasImportMedia() => $_has(16);
  @$pb.TagNumber(17)
  void clearImportMedia() => $_clearField(17);
  @$pb.TagNumber(17)
  ImportMedia ensureImportMedia() => $_ensure(16);

  @$pb.TagNumber(18)
  CreatePreview get createPreview => $_getN(17);
  @$pb.TagNumber(18)
  set createPreview(CreatePreview value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCreatePreview() => $_has(17);
  @$pb.TagNumber(18)
  void clearCreatePreview() => $_clearField(18);
  @$pb.TagNumber(18)
  CreatePreview ensureCreatePreview() => $_ensure(17);

  @$pb.TagNumber(19)
  Seek get seek => $_getN(18);
  @$pb.TagNumber(19)
  set seek(Seek value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasSeek() => $_has(18);
  @$pb.TagNumber(19)
  void clearSeek() => $_clearField(19);
  @$pb.TagNumber(19)
  Seek ensureSeek() => $_ensure(18);

  @$pb.TagNumber(20)
  RequestThumbnails get requestThumbnails => $_getN(19);
  @$pb.TagNumber(20)
  set requestThumbnails(RequestThumbnails value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasRequestThumbnails() => $_has(19);
  @$pb.TagNumber(20)
  void clearRequestThumbnails() => $_clearField(20);
  @$pb.TagNumber(20)
  RequestThumbnails ensureRequestThumbnails() => $_ensure(19);
}

/// Appends an empty track.
class AddTrack extends $pb.GeneratedMessage {
  factory AddTrack({
    TrackKind? kind,
  }) {
    final result = AddTrack._();
    if (kind != null) result.kind = kind;
    return result;
  }

  AddTrack._();

  factory AddTrack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddTrack()..mergeFromBuffer(data, registry);
  factory AddTrack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddTrack()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddTrack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: AddTrack.$_createMessage)
    ..aE<TrackKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: TrackKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddTrack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddTrack copyWith(void Function(AddTrack) updates) =>
      super.copyWith((message) => updates(message as AddTrack)) as AddTrack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AddTrack() / AddTrack.new instead')
  static AddTrack create() => AddTrack._();
  static $pb.GeneratedMessage $_createMessage() => AddTrack._();
  @$core.override
  AddTrack createEmptyInstance() => AddTrack._();
  @$core.pragma('dart2js:noInline')
  static AddTrack getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddTrack>(AddTrack.$_createMessage);
  static AddTrack? _defaultInstance;

  @$pb.TagNumber(1)
  TrackKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(TrackKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);
}

/// Places a clip on a track; fails if it would overlap another clip.
class InsertClip extends $pb.GeneratedMessage {
  factory InsertClip({
    $fixnum.Int64? trackId,
    $fixnum.Int64? mediaId,
    $fixnum.Int64? sourceStart,
    $fixnum.Int64? start,
    $fixnum.Int64? duration,
  }) {
    final result = InsertClip._();
    if (trackId != null) result.trackId = trackId;
    if (mediaId != null) result.mediaId = mediaId;
    if (sourceStart != null) result.sourceStart = sourceStart;
    if (start != null) result.start = start;
    if (duration != null) result.duration = duration;
    return result;
  }

  InsertClip._();

  factory InsertClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InsertClip()..mergeFromBuffer(data, registry);
  factory InsertClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      InsertClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InsertClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: InsertClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'trackId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(3, _omitFieldNames ? '' : 'sourceStart')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'duration')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InsertClip copyWith(void Function(InsertClip) updates) =>
      super.copyWith((message) => updates(message as InsertClip)) as InsertClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use InsertClip() / InsertClip.new instead')
  static InsertClip create() => InsertClip._();
  static $pb.GeneratedMessage $_createMessage() => InsertClip._();
  @$core.override
  InsertClip createEmptyInstance() => InsertClip._();
  @$core.pragma('dart2js:noInline')
  static InsertClip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InsertClip>(InsertClip.$_createMessage);
  static InsertClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get trackId => $_getI64(0);
  @$pb.TagNumber(1)
  set trackId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get mediaId => $_getI64(1);
  @$pb.TagNumber(2)
  set mediaId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sourceStart => $_getI64(2);
  @$pb.TagNumber(3)
  set sourceStart($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSourceStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearSourceStart() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get start => $_getI64(3);
  @$pb.TagNumber(4)
  set start($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get duration => $_getI64(4);
  @$pb.TagNumber(5)
  set duration($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);
}

/// Reverts the last edit.
class Undo extends $pb.GeneratedMessage {
  factory Undo() => Undo._();

  Undo._();

  factory Undo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Undo()..mergeFromBuffer(data, registry);
  factory Undo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Undo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Undo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Undo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Undo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Undo copyWith(void Function(Undo) updates) =>
      super.copyWith((message) => updates(message as Undo)) as Undo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Undo() / Undo.new instead')
  static Undo create() => Undo._();
  static $pb.GeneratedMessage $_createMessage() => Undo._();
  @$core.override
  Undo createEmptyInstance() => Undo._();
  @$core.pragma('dart2js:noInline')
  static Undo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Undo>(Undo.$_createMessage);
  static Undo? _defaultInstance;
}

/// Re-applies the last undone edit.
class Redo extends $pb.GeneratedMessage {
  factory Redo() => Redo._();

  Redo._();

  factory Redo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Redo()..mergeFromBuffer(data, registry);
  factory Redo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Redo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Redo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Redo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Redo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Redo copyWith(void Function(Redo) updates) =>
      super.copyWith((message) => updates(message as Redo)) as Redo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Redo() / Redo.new instead')
  static Redo create() => Redo._();
  static $pb.GeneratedMessage $_createMessage() => Redo._();
  @$core.override
  Redo createEmptyInstance() => Redo._();
  @$core.pragma('dart2js:noInline')
  static Redo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Redo>(Redo.$_createMessage);
  static Redo? _defaultInstance;
}

/// Asks for the current timeline; answered with TimelineChanged, nothing is edited.
class GetTimeline extends $pb.GeneratedMessage {
  factory GetTimeline() => GetTimeline._();

  GetTimeline._();

  factory GetTimeline.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTimeline()..mergeFromBuffer(data, registry);
  factory GetTimeline.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetTimeline()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTimeline',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: GetTimeline.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTimeline clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTimeline copyWith(void Function(GetTimeline) updates) =>
      super.copyWith((message) => updates(message as GetTimeline))
          as GetTimeline;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetTimeline() / GetTimeline.new instead')
  static GetTimeline create() => GetTimeline._();
  static $pb.GeneratedMessage $_createMessage() => GetTimeline._();
  @$core.override
  GetTimeline createEmptyInstance() => GetTimeline._();
  @$core.pragma('dart2js:noInline')
  static GetTimeline getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetTimeline>(
          GetTimeline.$_createMessage);
  static GetTimeline? _defaultInstance;
}

/// Starts an empty project; the old one is dropped (save it first) and undo is cleared.
class NewProject extends $pb.GeneratedMessage {
  factory NewProject() => NewProject._();

  NewProject._();

  factory NewProject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NewProject()..mergeFromBuffer(data, registry);
  factory NewProject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NewProject()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NewProject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: NewProject.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewProject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NewProject copyWith(void Function(NewProject) updates) =>
      super.copyWith((message) => updates(message as NewProject)) as NewProject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NewProject() / NewProject.new instead')
  static NewProject create() => NewProject._();
  static $pb.GeneratedMessage $_createMessage() => NewProject._();
  @$core.override
  NewProject createEmptyInstance() => NewProject._();
  @$core.pragma('dart2js:noInline')
  static NewProject getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NewProject>(NewProject.$_createMessage);
  static NewProject? _defaultInstance;
}

/// Saves the project to `path` atomically, keeping the previous saves as backups.
class SaveProject extends $pb.GeneratedMessage {
  factory SaveProject({
    $core.String? path,
  }) {
    final result = SaveProject._();
    if (path != null) result.path = path;
    return result;
  }

  SaveProject._();

  factory SaveProject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveProject()..mergeFromBuffer(data, registry);
  factory SaveProject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveProject()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveProject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: SaveProject.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProject copyWith(void Function(SaveProject) updates) =>
      super.copyWith((message) => updates(message as SaveProject))
          as SaveProject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SaveProject() / SaveProject.new instead')
  static SaveProject create() => SaveProject._();
  static $pb.GeneratedMessage $_createMessage() => SaveProject._();
  @$core.override
  SaveProject createEmptyInstance() => SaveProject._();
  @$core.pragma('dart2js:noInline')
  static SaveProject getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SaveProject>(
          SaveProject.$_createMessage);
  static SaveProject? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);
}

/// Replaces the project with the one at `path`; undo is cleared. A file that is unreadable,
/// from a newer app, or invalid is refused and the current project stays.
class OpenProject extends $pb.GeneratedMessage {
  factory OpenProject({
    $core.String? path,
  }) {
    final result = OpenProject._();
    if (path != null) result.path = path;
    return result;
  }

  OpenProject._();

  factory OpenProject.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenProject()..mergeFromBuffer(data, registry);
  factory OpenProject.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenProject()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenProject',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: OpenProject.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenProject clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenProject copyWith(void Function(OpenProject) updates) =>
      super.copyWith((message) => updates(message as OpenProject))
          as OpenProject;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use OpenProject() / OpenProject.new instead')
  static OpenProject create() => OpenProject._();
  static $pb.GeneratedMessage $_createMessage() => OpenProject._();
  @$core.override
  OpenProject createEmptyInstance() => OpenProject._();
  @$core.pragma('dart2js:noInline')
  static OpenProject getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<OpenProject>(
          OpenProject.$_createMessage);
  static OpenProject? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);
}

/// Sets the canvas aspect ratio (undoable). Refused unless both sides are 1..=100 and the
/// ratio lies between 1:3 and 3:1. Stored reduced (18:32 becomes 9:16).
class SetAspectRatio extends $pb.GeneratedMessage {
  factory SetAspectRatio({
    $core.int? width,
    $core.int? height,
  }) {
    final result = SetAspectRatio._();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  SetAspectRatio._();

  factory SetAspectRatio.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetAspectRatio()..mergeFromBuffer(data, registry);
  factory SetAspectRatio.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetAspectRatio()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetAspectRatio',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: SetAspectRatio.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetAspectRatio clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetAspectRatio copyWith(void Function(SetAspectRatio) updates) =>
      super.copyWith((message) => updates(message as SetAspectRatio))
          as SetAspectRatio;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetAspectRatio() / SetAspectRatio.new instead')
  static SetAspectRatio create() => SetAspectRatio._();
  static $pb.GeneratedMessage $_createMessage() => SetAspectRatio._();
  @$core.override
  SetAspectRatio createEmptyInstance() => SetAspectRatio._();
  @$core.pragma('dart2js:noInline')
  static SetAspectRatio getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetAspectRatio>(
          SetAspectRatio.$_createMessage);
  static SetAspectRatio? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get width => $_getIZ(0);
  @$pb.TagNumber(1)
  set width($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);
}

/// Removes a clip.
class RemoveClip extends $pb.GeneratedMessage {
  factory RemoveClip({
    $fixnum.Int64? clipId,
  }) {
    final result = RemoveClip._();
    if (clipId != null) result.clipId = clipId;
    return result;
  }

  RemoveClip._();

  factory RemoveClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveClip()..mergeFromBuffer(data, registry);
  factory RemoveClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: RemoveClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clipId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveClip copyWith(void Function(RemoveClip) updates) =>
      super.copyWith((message) => updates(message as RemoveClip)) as RemoveClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemoveClip() / RemoveClip.new instead')
  static RemoveClip create() => RemoveClip._();
  static $pb.GeneratedMessage $_createMessage() => RemoveClip._();
  @$core.override
  RemoveClip createEmptyInstance() => RemoveClip._();
  @$core.pragma('dart2js:noInline')
  static RemoveClip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveClip>(RemoveClip.$_createMessage);
  static RemoveClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clipId => $_getI64(0);
  @$pb.TagNumber(1)
  set clipId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClipId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClipId() => $_clearField(1);
}

/// Splits a clip at timeline time `at` (strictly inside it); the right part gets a new id.
class SplitClip extends $pb.GeneratedMessage {
  factory SplitClip({
    $fixnum.Int64? clipId,
    $fixnum.Int64? at,
  }) {
    final result = SplitClip._();
    if (clipId != null) result.clipId = clipId;
    if (at != null) result.at = at;
    return result;
  }

  SplitClip._();

  factory SplitClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SplitClip()..mergeFromBuffer(data, registry);
  factory SplitClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SplitClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SplitClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: SplitClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clipId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SplitClip copyWith(void Function(SplitClip) updates) =>
      super.copyWith((message) => updates(message as SplitClip)) as SplitClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SplitClip() / SplitClip.new instead')
  static SplitClip create() => SplitClip._();
  static $pb.GeneratedMessage $_createMessage() => SplitClip._();
  @$core.override
  SplitClip createEmptyInstance() => SplitClip._();
  @$core.pragma('dart2js:noInline')
  static SplitClip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SplitClip>(SplitClip.$_createMessage);
  static SplitClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clipId => $_getI64(0);
  @$pb.TagNumber(1)
  set clipId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClipId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClipId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);
}

/// Joins `right_id` into `left_id`: neighbours on one track, same media, continuous source.
class MergeClips extends $pb.GeneratedMessage {
  factory MergeClips({
    $fixnum.Int64? leftId,
    $fixnum.Int64? rightId,
  }) {
    final result = MergeClips._();
    if (leftId != null) result.leftId = leftId;
    if (rightId != null) result.rightId = rightId;
    return result;
  }

  MergeClips._();

  factory MergeClips.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MergeClips()..mergeFromBuffer(data, registry);
  factory MergeClips.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MergeClips()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MergeClips',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: MergeClips.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'leftId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'rightId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeClips clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MergeClips copyWith(void Function(MergeClips) updates) =>
      super.copyWith((message) => updates(message as MergeClips)) as MergeClips;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MergeClips() / MergeClips.new instead')
  static MergeClips create() => MergeClips._();
  static $pb.GeneratedMessage $_createMessage() => MergeClips._();
  @$core.override
  MergeClips createEmptyInstance() => MergeClips._();
  @$core.pragma('dart2js:noInline')
  static MergeClips getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MergeClips>(MergeClips.$_createMessage);
  static MergeClips? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get leftId => $_getI64(0);
  @$pb.TagNumber(1)
  set leftId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLeftId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeftId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get rightId => $_getI64(1);
  @$pb.TagNumber(2)
  set rightId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRightId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRightId() => $_clearField(2);
}

/// Moves a clip's edges to [start, end); moving the start moves the source offset with it.
class TrimClip extends $pb.GeneratedMessage {
  factory TrimClip({
    $fixnum.Int64? clipId,
    $fixnum.Int64? start,
    $fixnum.Int64? end,
  }) {
    final result = TrimClip._();
    if (clipId != null) result.clipId = clipId;
    if (start != null) result.start = start;
    if (end != null) result.end = end;
    return result;
  }

  TrimClip._();

  factory TrimClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrimClip()..mergeFromBuffer(data, registry);
  factory TrimClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrimClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrimClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: TrimClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clipId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(2, _omitFieldNames ? '' : 'start')
    ..aInt64(3, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrimClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrimClip copyWith(void Function(TrimClip) updates) =>
      super.copyWith((message) => updates(message as TrimClip)) as TrimClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TrimClip() / TrimClip.new instead')
  static TrimClip create() => TrimClip._();
  static $pb.GeneratedMessage $_createMessage() => TrimClip._();
  @$core.override
  TrimClip createEmptyInstance() => TrimClip._();
  @$core.pragma('dart2js:noInline')
  static TrimClip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrimClip>(TrimClip.$_createMessage);
  static TrimClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clipId => $_getI64(0);
  @$pb.TagNumber(1)
  set clipId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClipId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClipId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get start => $_getI64(1);
  @$pb.TagNumber(2)
  set start($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearStart() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get end => $_getI64(2);
  @$pb.TagNumber(3)
  set end($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEnd() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnd() => $_clearField(3);
}

/// Copies a clip to right after itself; refused if that space is taken.
class DuplicateClip extends $pb.GeneratedMessage {
  factory DuplicateClip({
    $fixnum.Int64? clipId,
  }) {
    final result = DuplicateClip._();
    if (clipId != null) result.clipId = clipId;
    return result;
  }

  DuplicateClip._();

  factory DuplicateClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DuplicateClip()..mergeFromBuffer(data, registry);
  factory DuplicateClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DuplicateClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DuplicateClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: DuplicateClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clipId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DuplicateClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DuplicateClip copyWith(void Function(DuplicateClip) updates) =>
      super.copyWith((message) => updates(message as DuplicateClip))
          as DuplicateClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DuplicateClip() / DuplicateClip.new instead')
  static DuplicateClip create() => DuplicateClip._();
  static $pb.GeneratedMessage $_createMessage() => DuplicateClip._();
  @$core.override
  DuplicateClip createEmptyInstance() => DuplicateClip._();
  @$core.pragma('dart2js:noInline')
  static DuplicateClip getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DuplicateClip>(
          DuplicateClip.$_createMessage);
  static DuplicateClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clipId => $_getI64(0);
  @$pb.TagNumber(1)
  set clipId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClipId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClipId() => $_clearField(1);
}

/// Changes a track's switches; unset fields keep their value, so quick taps on different
/// switches never undo each other. Allowed while locked (so it can be unlocked). Only video
/// tracks can be hidden. A locked track refuses clip edits.
class SetTrackFlags extends $pb.GeneratedMessage {
  factory SetTrackFlags({
    $fixnum.Int64? trackId,
    $core.bool? muted,
    $core.bool? hidden,
    $core.bool? locked,
  }) {
    final result = SetTrackFlags._();
    if (trackId != null) result.trackId = trackId;
    if (muted != null) result.muted = muted;
    if (hidden != null) result.hidden = hidden;
    if (locked != null) result.locked = locked;
    return result;
  }

  SetTrackFlags._();

  factory SetTrackFlags.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetTrackFlags()..mergeFromBuffer(data, registry);
  factory SetTrackFlags.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetTrackFlags()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetTrackFlags',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: SetTrackFlags.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'trackId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(2, _omitFieldNames ? '' : 'muted')
    ..aOB(3, _omitFieldNames ? '' : 'hidden')
    ..aOB(4, _omitFieldNames ? '' : 'locked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTrackFlags clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetTrackFlags copyWith(void Function(SetTrackFlags) updates) =>
      super.copyWith((message) => updates(message as SetTrackFlags))
          as SetTrackFlags;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetTrackFlags() / SetTrackFlags.new instead')
  static SetTrackFlags create() => SetTrackFlags._();
  static $pb.GeneratedMessage $_createMessage() => SetTrackFlags._();
  @$core.override
  SetTrackFlags createEmptyInstance() => SetTrackFlags._();
  @$core.pragma('dart2js:noInline')
  static SetTrackFlags getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetTrackFlags>(
          SetTrackFlags.$_createMessage);
  static SetTrackFlags? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get trackId => $_getI64(0);
  @$pb.TagNumber(1)
  set trackId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTrackId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTrackId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get muted => $_getBF(1);
  @$pb.TagNumber(2)
  set muted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMuted() => $_has(1);
  @$pb.TagNumber(2)
  void clearMuted() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get hidden => $_getBF(2);
  @$pb.TagNumber(3)
  set hidden($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHidden() => $_has(2);
  @$pb.TagNumber(3)
  void clearHidden() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get locked => $_getBF(3);
  @$pb.TagNumber(4)
  set locked($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLocked() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocked() => $_clearField(4);
}

/// Moves a clip to `start` on `track_id` (its own or another track of the same kind); refused
/// if either track is locked or the spot is taken.
class MoveClip extends $pb.GeneratedMessage {
  factory MoveClip({
    $fixnum.Int64? clipId,
    $fixnum.Int64? trackId,
    $fixnum.Int64? start,
  }) {
    final result = MoveClip._();
    if (clipId != null) result.clipId = clipId;
    if (trackId != null) result.trackId = trackId;
    if (start != null) result.start = start;
    return result;
  }

  MoveClip._();

  factory MoveClip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveClip()..mergeFromBuffer(data, registry);
  factory MoveClip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveClip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoveClip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: MoveClip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'clipId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'trackId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(3, _omitFieldNames ? '' : 'start')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveClip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveClip copyWith(void Function(MoveClip) updates) =>
      super.copyWith((message) => updates(message as MoveClip)) as MoveClip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MoveClip() / MoveClip.new instead')
  static MoveClip create() => MoveClip._();
  static $pb.GeneratedMessage $_createMessage() => MoveClip._();
  @$core.override
  MoveClip createEmptyInstance() => MoveClip._();
  @$core.pragma('dart2js:noInline')
  static MoveClip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MoveClip>(MoveClip.$_createMessage);
  static MoveClip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get clipId => $_getI64(0);
  @$pb.TagNumber(1)
  set clipId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClipId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClipId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get trackId => $_getI64(1);
  @$pb.TagNumber(2)
  set trackId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrackId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrackId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get start => $_getI64(2);
  @$pb.TagNumber(3)
  set start($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearStart() => $_clearField(3);
}

/// Adds picked media, in pick order, back to back at the end of the first unlocked video track
/// (a new one if none). All or nothing: one bad item refuses the whole import. Photos get the
/// default photo duration.
class ImportMedia extends $pb.GeneratedMessage {
  factory ImportMedia({
    $core.Iterable<MediaItem>? items,
  }) {
    final result = ImportMedia._();
    if (items != null) result.items.addAll(items);
    return result;
  }

  ImportMedia._();

  factory ImportMedia.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMedia()..mergeFromBuffer(data, registry);
  factory ImportMedia.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMedia()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportMedia',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: ImportMedia.$_createMessage)
    ..pPM<MediaItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: MediaItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMedia clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMedia copyWith(void Function(ImportMedia) updates) =>
      super.copyWith((message) => updates(message as ImportMedia))
          as ImportMedia;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImportMedia() / ImportMedia.new instead')
  static ImportMedia create() => ImportMedia._();
  static $pb.GeneratedMessage $_createMessage() => ImportMedia._();
  @$core.override
  ImportMedia createEmptyInstance() => ImportMedia._();
  @$core.pragma('dart2js:noInline')
  static ImportMedia getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImportMedia>(
          ImportMedia.$_createMessage);
  static ImportMedia? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get items => $_getList(0);
}

/// One picked file, as reported by the platform layer (untrusted). `uri` is opaque to the
/// engine: content://... on Android, a path relative to the app's media folder on iOS.
class MediaItem extends $pb.GeneratedMessage {
  factory MediaItem({
    $core.String? uri,
    MediaKind? kind,
    $fixnum.Int64? durationValue,
    $core.int? durationTimescale,
    $core.int? width,
    $core.int? height,
    $core.int? rotation,
    $core.String? codec,
  }) {
    final result = MediaItem._();
    if (uri != null) result.uri = uri;
    if (kind != null) result.kind = kind;
    if (durationValue != null) result.durationValue = durationValue;
    if (durationTimescale != null) result.durationTimescale = durationTimescale;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (rotation != null) result.rotation = rotation;
    if (codec != null) result.codec = codec;
    return result;
  }

  MediaItem._();

  factory MediaItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaItem()..mergeFromBuffer(data, registry);
  factory MediaItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MediaItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: MediaItem.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'uri')
    ..aE<MediaKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: MediaKind.values)
    ..aInt64(3, _omitFieldNames ? '' : 'durationValue')
    ..aI(4, _omitFieldNames ? '' : 'durationTimescale',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'rotation', fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'codec')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem copyWith(void Function(MediaItem) updates) =>
      super.copyWith((message) => updates(message as MediaItem)) as MediaItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MediaItem() / MediaItem.new instead')
  static MediaItem create() => MediaItem._();
  static $pb.GeneratedMessage $_createMessage() => MediaItem._();
  @$core.override
  MediaItem createEmptyInstance() => MediaItem._();
  @$core.pragma('dart2js:noInline')
  static MediaItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaItem>(MediaItem.$_createMessage);
  static MediaItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uri => $_getSZ(0);
  @$pb.TagNumber(1)
  set uri($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUri() => $_has(0);
  @$pb.TagNumber(1)
  void clearUri() => $_clearField(1);

  @$pb.TagNumber(2)
  MediaKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(MediaKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// Video duration = duration_value / duration_timescale seconds; ignored for images.
  @$pb.TagNumber(3)
  $fixnum.Int64 get durationValue => $_getI64(2);
  @$pb.TagNumber(3)
  set durationValue($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationValue() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get durationTimescale => $_getIZ(3);
  @$pb.TagNumber(4)
  set durationTimescale($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationTimescale() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationTimescale() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get width => $_getIZ(4);
  @$pb.TagNumber(5)
  set width($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get height => $_getIZ(5);
  @$pb.TagNumber(6)
  set height($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  /// Clockwise display rotation: 0, 90, 180 or 270.
  @$pb.TagNumber(7)
  $core.int get rotation => $_getIZ(6);
  @$pb.TagNumber(7)
  set rotation($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRotation() => $_has(6);
  @$pb.TagNumber(7)
  void clearRotation() => $_clearField(7);

  /// Informational codec tag, at most 16 ASCII characters: the fourCC on iOS ("avc1", "hvc1"),
  /// the MIME subtype on Android ("avc", "hevc", "x-vnd.on2.vp9"); empty when unknown.
  @$pb.TagNumber(8)
  $core.String get codec => $_getSZ(7);
  @$pb.TagNumber(8)
  set codec($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCodec() => $_has(7);
  @$pb.TagNumber(8)
  void clearCodec() => $_clearField(8);
}

/// Asks the platform layer for a preview texture of this size (each side 1..=8192) and draws
/// into it. Answered at once with CommandAccepted (or CommandFailed); the result follows later
/// as PreviewReady or CommandFailed (docs/adr/0003-platform-callbacks.md).
class CreatePreview extends $pb.GeneratedMessage {
  factory CreatePreview({
    $core.int? width,
    $core.int? height,
  }) {
    final result = CreatePreview._();
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    return result;
  }

  CreatePreview._();

  factory CreatePreview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreatePreview()..mergeFromBuffer(data, registry);
  factory CreatePreview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreatePreview()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreatePreview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: CreatePreview.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'width', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'height', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePreview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreatePreview copyWith(void Function(CreatePreview) updates) =>
      super.copyWith((message) => updates(message as CreatePreview))
          as CreatePreview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CreatePreview() / CreatePreview.new instead')
  static CreatePreview create() => CreatePreview._();
  static $pb.GeneratedMessage $_createMessage() => CreatePreview._();
  @$core.override
  CreatePreview createEmptyInstance() => CreatePreview._();
  @$core.pragma('dart2js:noInline')
  static CreatePreview getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreatePreview>(
          CreatePreview.$_createMessage);
  static CreatePreview? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get width => $_getIZ(0);
  @$pb.TagNumber(1)
  set width($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWidth() => $_has(0);
  @$pb.TagNumber(1)
  void clearWidth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get height => $_getIZ(1);
  @$pb.TagNumber(2)
  set height($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeight() => $_clearField(2);
}

/// Asks for thumbnails of one media at source `times` (each snapped down to
/// TimelineChanged.thumbnail_step, at most 64), each side at most `max_side` (32..=512).
/// Answered with CommandAccepted; each new thumbnail arrives later as ThumbnailReady. Times
/// already asked for are not made again; failures send nothing.
class RequestThumbnails extends $pb.GeneratedMessage {
  factory RequestThumbnails({
    $fixnum.Int64? mediaId,
    $core.Iterable<$fixnum.Int64>? times,
    $core.int? maxSide,
  }) {
    final result = RequestThumbnails._();
    if (mediaId != null) result.mediaId = mediaId;
    if (times != null) result.times.addAll(times);
    if (maxSide != null) result.maxSide = maxSide;
    return result;
  }

  RequestThumbnails._();

  factory RequestThumbnails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequestThumbnails()..mergeFromBuffer(data, registry);
  factory RequestThumbnails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequestThumbnails()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestThumbnails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: RequestThumbnails.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..p<$fixnum.Int64>(2, _omitFieldNames ? '' : 'times', $pb.PbFieldType.K6)
    ..aI(3, _omitFieldNames ? '' : 'maxSide', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestThumbnails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestThumbnails copyWith(void Function(RequestThumbnails) updates) =>
      super.copyWith((message) => updates(message as RequestThumbnails))
          as RequestThumbnails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RequestThumbnails() / RequestThumbnails.new instead')
  static RequestThumbnails create() => RequestThumbnails._();
  static $pb.GeneratedMessage $_createMessage() => RequestThumbnails._();
  @$core.override
  RequestThumbnails createEmptyInstance() => RequestThumbnails._();
  @$core.pragma('dart2js:noInline')
  static RequestThumbnails getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RequestThumbnails>(
          RequestThumbnails.$_createMessage);
  static RequestThumbnails? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get mediaId => $_getI64(0);
  @$pb.TagNumber(1)
  set mediaId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get times => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get maxSide => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxSide($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxSide() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxSide() => $_clearField(3);
}

/// Moves the playhead to `time` (snapped, then clamped to [0, timeline duration]) and redraws
/// the preview there. Not an undo step. Answered with PlayheadChanged.
class Seek extends $pb.GeneratedMessage {
  factory Seek({
    $fixnum.Int64? time,
    $fixnum.Int64? snapWithin,
  }) {
    final result = Seek._();
    if (time != null) result.time = time;
    if (snapWithin != null) result.snapWithin = snapWithin;
    return result;
  }

  Seek._();

  factory Seek.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Seek()..mergeFromBuffer(data, registry);
  factory Seek.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Seek()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Seek',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Seek.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'time')
    ..aInt64(2, _omitFieldNames ? '' : 'snapWithin')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Seek clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Seek copyWith(void Function(Seek) updates) =>
      super.copyWith((message) => updates(message as Seek)) as Seek;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Seek() / Seek.new instead')
  static Seek create() => Seek._();
  static $pb.GeneratedMessage $_createMessage() => Seek._();
  @$core.override
  Seek createEmptyInstance() => Seek._();
  @$core.pragma('dart2js:noInline')
  static Seek getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Seek>(Seek.$_createMessage);
  static Seek? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get time => $_getI64(0);
  @$pb.TagNumber(1)
  set time($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearTime() => $_clearField(1);

  /// Snap to the nearest edge (0, a clip start or end, the timeline end) within this many ticks;
  /// 0 means no snapping, more than 10 s is capped, negative is refused.
  @$pb.TagNumber(2)
  $fixnum.Int64 get snapWithin => $_getI64(1);
  @$pb.TagNumber(2)
  set snapWithin($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapWithin() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapWithin() => $_clearField(2);
}

enum Event_Kind {
  timelineChanged,
  commandFailed,
  projectSaved,
  commandAccepted,
  previewReady,
  playheadChanged,
  thumbnailReady,
  notSet
}

/// Sent by the engine. Exactly one kind is set. Every command is answered by exactly one event,
/// in command order; results of accepted platform work (PreviewReady, or CommandFailed) arrive
/// later on their own.
class Event extends $pb.GeneratedMessage {
  factory Event({
    TimelineChanged? timelineChanged,
    CommandFailed? commandFailed,
    ProjectSaved? projectSaved,
    CommandAccepted? commandAccepted,
    PreviewReady? previewReady,
    PlayheadChanged? playheadChanged,
    ThumbnailReady? thumbnailReady,
  }) {
    final result = Event._();
    if (timelineChanged != null) result.timelineChanged = timelineChanged;
    if (commandFailed != null) result.commandFailed = commandFailed;
    if (projectSaved != null) result.projectSaved = projectSaved;
    if (commandAccepted != null) result.commandAccepted = commandAccepted;
    if (previewReady != null) result.previewReady = previewReady;
    if (playheadChanged != null) result.playheadChanged = playheadChanged;
    if (thumbnailReady != null) result.thumbnailReady = thumbnailReady;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Event()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Event()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Event_Kind> _Event_KindByTag = {
    1: Event_Kind.timelineChanged,
    2: Event_Kind.commandFailed,
    3: Event_Kind.projectSaved,
    4: Event_Kind.commandAccepted,
    5: Event_Kind.previewReady,
    6: Event_Kind.playheadChanged,
    7: Event_Kind.thumbnailReady,
    0: Event_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Event.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7])
    ..aOM<TimelineChanged>(1, _omitFieldNames ? '' : 'timelineChanged',
        subBuilder: TimelineChanged.$_createMessage)
    ..aOM<CommandFailed>(2, _omitFieldNames ? '' : 'commandFailed',
        subBuilder: CommandFailed.$_createMessage)
    ..aOM<ProjectSaved>(3, _omitFieldNames ? '' : 'projectSaved',
        subBuilder: ProjectSaved.$_createMessage)
    ..aOM<CommandAccepted>(4, _omitFieldNames ? '' : 'commandAccepted',
        subBuilder: CommandAccepted.$_createMessage)
    ..aOM<PreviewReady>(5, _omitFieldNames ? '' : 'previewReady',
        subBuilder: PreviewReady.$_createMessage)
    ..aOM<PlayheadChanged>(6, _omitFieldNames ? '' : 'playheadChanged',
        subBuilder: PlayheadChanged.$_createMessage)
    ..aOM<ThumbnailReady>(7, _omitFieldNames ? '' : 'thumbnailReady',
        subBuilder: ThumbnailReady.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Event() / Event.new instead')
  static Event create() => Event._();
  static $pb.GeneratedMessage $_createMessage() => Event._();
  @$core.override
  Event createEmptyInstance() => Event._();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Event>(Event.$_createMessage);
  static Event? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  Event_Kind whichKind() => _Event_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  TimelineChanged get timelineChanged => $_getN(0);
  @$pb.TagNumber(1)
  set timelineChanged(TimelineChanged value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTimelineChanged() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimelineChanged() => $_clearField(1);
  @$pb.TagNumber(1)
  TimelineChanged ensureTimelineChanged() => $_ensure(0);

  @$pb.TagNumber(2)
  CommandFailed get commandFailed => $_getN(1);
  @$pb.TagNumber(2)
  set commandFailed(CommandFailed value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCommandFailed() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommandFailed() => $_clearField(2);
  @$pb.TagNumber(2)
  CommandFailed ensureCommandFailed() => $_ensure(1);

  @$pb.TagNumber(3)
  ProjectSaved get projectSaved => $_getN(2);
  @$pb.TagNumber(3)
  set projectSaved(ProjectSaved value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasProjectSaved() => $_has(2);
  @$pb.TagNumber(3)
  void clearProjectSaved() => $_clearField(3);
  @$pb.TagNumber(3)
  ProjectSaved ensureProjectSaved() => $_ensure(2);

  @$pb.TagNumber(4)
  CommandAccepted get commandAccepted => $_getN(3);
  @$pb.TagNumber(4)
  set commandAccepted(CommandAccepted value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCommandAccepted() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommandAccepted() => $_clearField(4);
  @$pb.TagNumber(4)
  CommandAccepted ensureCommandAccepted() => $_ensure(3);

  @$pb.TagNumber(5)
  PreviewReady get previewReady => $_getN(4);
  @$pb.TagNumber(5)
  set previewReady(PreviewReady value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPreviewReady() => $_has(4);
  @$pb.TagNumber(5)
  void clearPreviewReady() => $_clearField(5);
  @$pb.TagNumber(5)
  PreviewReady ensurePreviewReady() => $_ensure(4);

  @$pb.TagNumber(6)
  PlayheadChanged get playheadChanged => $_getN(5);
  @$pb.TagNumber(6)
  set playheadChanged(PlayheadChanged value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlayheadChanged() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlayheadChanged() => $_clearField(6);
  @$pb.TagNumber(6)
  PlayheadChanged ensurePlayheadChanged() => $_ensure(5);

  @$pb.TagNumber(7)
  ThumbnailReady get thumbnailReady => $_getN(6);
  @$pb.TagNumber(7)
  set thumbnailReady(ThumbnailReady value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasThumbnailReady() => $_has(6);
  @$pb.TagNumber(7)
  void clearThumbnailReady() => $_clearField(7);
  @$pb.TagNumber(7)
  ThumbnailReady ensureThumbnailReady() => $_ensure(6);
}

/// A thumbnail file for one media at a snapped source time; show it as an image file.
class ThumbnailReady extends $pb.GeneratedMessage {
  factory ThumbnailReady({
    $fixnum.Int64? mediaId,
    $fixnum.Int64? time,
    $core.int? maxSide,
    $core.String? path,
  }) {
    final result = ThumbnailReady._();
    if (mediaId != null) result.mediaId = mediaId;
    if (time != null) result.time = time;
    if (maxSide != null) result.maxSide = maxSide;
    if (path != null) result.path = path;
    return result;
  }

  ThumbnailReady._();

  factory ThumbnailReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThumbnailReady()..mergeFromBuffer(data, registry);
  factory ThumbnailReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThumbnailReady()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThumbnailReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: ThumbnailReady.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(2, _omitFieldNames ? '' : 'time')
    ..aI(3, _omitFieldNames ? '' : 'maxSide', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThumbnailReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThumbnailReady copyWith(void Function(ThumbnailReady) updates) =>
      super.copyWith((message) => updates(message as ThumbnailReady))
          as ThumbnailReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ThumbnailReady() / ThumbnailReady.new instead')
  static ThumbnailReady create() => ThumbnailReady._();
  static $pb.GeneratedMessage $_createMessage() => ThumbnailReady._();
  @$core.override
  ThumbnailReady createEmptyInstance() => ThumbnailReady._();
  @$core.pragma('dart2js:noInline')
  static ThumbnailReady getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ThumbnailReady>(
          ThumbnailReady.$_createMessage);
  static ThumbnailReady? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get mediaId => $_getI64(0);
  @$pb.TagNumber(1)
  set mediaId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get time => $_getI64(1);
  @$pb.TagNumber(2)
  set time($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearTime() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxSide => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxSide($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxSide() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxSide() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get path => $_getSZ(3);
  @$pb.TagNumber(4)
  set path($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearPath() => $_clearField(4);
}

/// Where the playhead is now, after a Seek.
class PlayheadChanged extends $pb.GeneratedMessage {
  factory PlayheadChanged({
    $fixnum.Int64? time,
    $core.bool? snapped,
  }) {
    final result = PlayheadChanged._();
    if (time != null) result.time = time;
    if (snapped != null) result.snapped = snapped;
    return result;
  }

  PlayheadChanged._();

  factory PlayheadChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayheadChanged()..mergeFromBuffer(data, registry);
  factory PlayheadChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlayheadChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlayheadChanged',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: PlayheadChanged.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'time')
    ..aOB(2, _omitFieldNames ? '' : 'snapped')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayheadChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlayheadChanged copyWith(void Function(PlayheadChanged) updates) =>
      super.copyWith((message) => updates(message as PlayheadChanged))
          as PlayheadChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlayheadChanged() / PlayheadChanged.new instead')
  static PlayheadChanged create() => PlayheadChanged._();
  static $pb.GeneratedMessage $_createMessage() => PlayheadChanged._();
  @$core.override
  PlayheadChanged createEmptyInstance() => PlayheadChanged._();
  @$core.pragma('dart2js:noInline')
  static PlayheadChanged getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlayheadChanged>(
          PlayheadChanged.$_createMessage);
  static PlayheadChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get time => $_getI64(0);
  @$pb.TagNumber(1)
  set time($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearTime() => $_clearField(1);

  /// The seek landed on a snap point.
  @$pb.TagNumber(2)
  $core.bool get snapped => $_getBF(1);
  @$pb.TagNumber(2)
  set snapped($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapped() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapped() => $_clearField(2);
}

/// The command started work whose result comes later as its own event.
class CommandAccepted extends $pb.GeneratedMessage {
  factory CommandAccepted() => CommandAccepted._();

  CommandAccepted._();

  factory CommandAccepted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandAccepted()..mergeFromBuffer(data, registry);
  factory CommandAccepted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandAccepted()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommandAccepted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: CommandAccepted.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandAccepted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandAccepted copyWith(void Function(CommandAccepted) updates) =>
      super.copyWith((message) => updates(message as CommandAccepted))
          as CommandAccepted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommandAccepted() / CommandAccepted.new instead')
  static CommandAccepted create() => CommandAccepted._();
  static $pb.GeneratedMessage $_createMessage() => CommandAccepted._();
  @$core.override
  CommandAccepted createEmptyInstance() => CommandAccepted._();
  @$core.pragma('dart2js:noInline')
  static CommandAccepted getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommandAccepted>(
          CommandAccepted.$_createMessage);
  static CommandAccepted? _defaultInstance;
}

/// The preview texture exists and holds a frame; show it with Flutter's Texture widget.
class PreviewReady extends $pb.GeneratedMessage {
  factory PreviewReady({
    $fixnum.Int64? textureId,
  }) {
    final result = PreviewReady._();
    if (textureId != null) result.textureId = textureId;
    return result;
  }

  PreviewReady._();

  factory PreviewReady.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PreviewReady()..mergeFromBuffer(data, registry);
  factory PreviewReady.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PreviewReady()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PreviewReady',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: PreviewReady.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'textureId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewReady clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PreviewReady copyWith(void Function(PreviewReady) updates) =>
      super.copyWith((message) => updates(message as PreviewReady))
          as PreviewReady;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PreviewReady() / PreviewReady.new instead')
  static PreviewReady create() => PreviewReady._();
  static $pb.GeneratedMessage $_createMessage() => PreviewReady._();
  @$core.override
  PreviewReady createEmptyInstance() => PreviewReady._();
  @$core.pragma('dart2js:noInline')
  static PreviewReady getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PreviewReady>(
          PreviewReady.$_createMessage);
  static PreviewReady? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get textureId => $_getI64(0);
  @$pb.TagNumber(1)
  set textureId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTextureId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTextureId() => $_clearField(1);
}

/// Full timeline state after a successful command or GetTimeline.
class TimelineChanged extends $pb.GeneratedMessage {
  factory TimelineChanged({
    $core.Iterable<Track>? tracks,
    $fixnum.Int64? duration,
    $core.bool? canUndo,
    $core.bool? canRedo,
    $core.int? aspectWidth,
    $core.int? aspectHeight,
    $fixnum.Int64? playhead,
    $fixnum.Int64? ticksPerSecond,
    $fixnum.Int64? thumbnailStep,
  }) {
    final result = TimelineChanged._();
    if (tracks != null) result.tracks.addAll(tracks);
    if (duration != null) result.duration = duration;
    if (canUndo != null) result.canUndo = canUndo;
    if (canRedo != null) result.canRedo = canRedo;
    if (aspectWidth != null) result.aspectWidth = aspectWidth;
    if (aspectHeight != null) result.aspectHeight = aspectHeight;
    if (playhead != null) result.playhead = playhead;
    if (ticksPerSecond != null) result.ticksPerSecond = ticksPerSecond;
    if (thumbnailStep != null) result.thumbnailStep = thumbnailStep;
    return result;
  }

  TimelineChanged._();

  factory TimelineChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineChanged()..mergeFromBuffer(data, registry);
  factory TimelineChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TimelineChanged()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TimelineChanged',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: TimelineChanged.$_createMessage)
    ..pPM<Track>(1, _omitFieldNames ? '' : 'tracks',
        subBuilder: Track.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'duration')
    ..aOB(3, _omitFieldNames ? '' : 'canUndo')
    ..aOB(4, _omitFieldNames ? '' : 'canRedo')
    ..aI(5, _omitFieldNames ? '' : 'aspectWidth',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'aspectHeight',
        fieldType: $pb.PbFieldType.OU3)
    ..aInt64(7, _omitFieldNames ? '' : 'playhead')
    ..aInt64(8, _omitFieldNames ? '' : 'ticksPerSecond')
    ..aInt64(9, _omitFieldNames ? '' : 'thumbnailStep')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TimelineChanged copyWith(void Function(TimelineChanged) updates) =>
      super.copyWith((message) => updates(message as TimelineChanged))
          as TimelineChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TimelineChanged() / TimelineChanged.new instead')
  static TimelineChanged create() => TimelineChanged._();
  static $pb.GeneratedMessage $_createMessage() => TimelineChanged._();
  @$core.override
  TimelineChanged createEmptyInstance() => TimelineChanged._();
  @$core.pragma('dart2js:noInline')
  static TimelineChanged getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TimelineChanged>(
          TimelineChanged.$_createMessage);
  static TimelineChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Track> get tracks => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get duration => $_getI64(1);
  @$pb.TagNumber(2)
  set duration($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDuration() => $_has(1);
  @$pb.TagNumber(2)
  void clearDuration() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get canUndo => $_getBF(2);
  @$pb.TagNumber(3)
  set canUndo($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCanUndo() => $_has(2);
  @$pb.TagNumber(3)
  void clearCanUndo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get canRedo => $_getBF(3);
  @$pb.TagNumber(4)
  set canRedo($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCanRedo() => $_has(3);
  @$pb.TagNumber(4)
  void clearCanRedo() => $_clearField(4);

  /// Canvas aspect ratio, reduced (9:16, 16:9, ...).
  @$pb.TagNumber(5)
  $core.int get aspectWidth => $_getIZ(4);
  @$pb.TagNumber(5)
  set aspectWidth($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAspectWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearAspectWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get aspectHeight => $_getIZ(5);
  @$pb.TagNumber(6)
  set aspectHeight($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAspectHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearAspectHeight() => $_clearField(6);

  /// Playhead, kept inside [0, duration] when edits shorten the timeline.
  @$pb.TagNumber(7)
  $fixnum.Int64 get playhead => $_getI64(6);
  @$pb.TagNumber(7)
  set playhead($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPlayhead() => $_has(6);
  @$pb.TagNumber(7)
  void clearPlayhead() => $_clearField(7);

  /// Ticks per second of every time field, so the UI can place times without its own copy.
  @$pb.TagNumber(8)
  $fixnum.Int64 get ticksPerSecond => $_getI64(7);
  @$pb.TagNumber(8)
  set ticksPerSecond($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTicksPerSecond() => $_has(7);
  @$pb.TagNumber(8)
  void clearTicksPerSecond() => $_clearField(8);

  /// Thumbnail times are multiples of this many ticks (RequestThumbnails snaps to it).
  @$pb.TagNumber(9)
  $fixnum.Int64 get thumbnailStep => $_getI64(8);
  @$pb.TagNumber(9)
  set thumbnailStep($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasThumbnailStep() => $_has(8);
  @$pb.TagNumber(9)
  void clearThumbnailStep() => $_clearField(9);
}

/// A track and its clips, sorted by start.
class Track extends $pb.GeneratedMessage {
  factory Track({
    $fixnum.Int64? id,
    TrackKind? kind,
    $core.Iterable<Clip>? clips,
    $core.int? number,
    $core.bool? muted,
    $core.bool? hidden,
    $core.bool? locked,
  }) {
    final result = Track._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (clips != null) result.clips.addAll(clips);
    if (number != null) result.number = number;
    if (muted != null) result.muted = muted;
    if (hidden != null) result.hidden = hidden;
    if (locked != null) result.locked = locked;
    return result;
  }

  Track._();

  factory Track.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Track()..mergeFromBuffer(data, registry);
  factory Track.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Track()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Track',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Track.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aE<TrackKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: TrackKind.values)
    ..pPM<Clip>(3, _omitFieldNames ? '' : 'clips',
        subBuilder: Clip.$_createMessage)
    ..aI(4, _omitFieldNames ? '' : 'number', fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'muted')
    ..aOB(6, _omitFieldNames ? '' : 'hidden')
    ..aOB(7, _omitFieldNames ? '' : 'locked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Track clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Track copyWith(void Function(Track) updates) =>
      super.copyWith((message) => updates(message as Track)) as Track;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Track() / Track.new instead')
  static Track create() => Track._();
  static $pb.GeneratedMessage $_createMessage() => Track._();
  @$core.override
  Track createEmptyInstance() => Track._();
  @$core.pragma('dart2js:noInline')
  static Track getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Track>(Track.$_createMessage);
  static Track? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  TrackKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(TrackKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<Clip> get clips => $_getList(2);

  /// 1-based position among tracks of the same kind (Video 1, Video 2, Audio 1).
  @$pb.TagNumber(4)
  $core.int get number => $_getIZ(3);
  @$pb.TagNumber(4)
  set number($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNumber() => $_has(3);
  @$pb.TagNumber(4)
  void clearNumber() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get muted => $_getBF(4);
  @$pb.TagNumber(5)
  set muted($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMuted() => $_has(4);
  @$pb.TagNumber(5)
  void clearMuted() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get hidden => $_getBF(5);
  @$pb.TagNumber(6)
  set hidden($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHidden() => $_has(5);
  @$pb.TagNumber(6)
  void clearHidden() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get locked => $_getBF(6);
  @$pb.TagNumber(7)
  set locked($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLocked() => $_has(6);
  @$pb.TagNumber(7)
  void clearLocked() => $_clearField(7);
}

/// A clip on a track.
class Clip extends $pb.GeneratedMessage {
  factory Clip({
    $fixnum.Int64? id,
    $fixnum.Int64? mediaId,
    $fixnum.Int64? sourceStart,
    $fixnum.Int64? start,
    $fixnum.Int64? duration,
    MediaKind? mediaKind,
  }) {
    final result = Clip._();
    if (id != null) result.id = id;
    if (mediaId != null) result.mediaId = mediaId;
    if (sourceStart != null) result.sourceStart = sourceStart;
    if (start != null) result.start = start;
    if (duration != null) result.duration = duration;
    if (mediaKind != null) result.mediaKind = mediaKind;
    return result;
  }

  Clip._();

  factory Clip.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Clip()..mergeFromBuffer(data, registry);
  factory Clip.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Clip()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Clip',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Clip.$_createMessage)
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'mediaId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aInt64(3, _omitFieldNames ? '' : 'sourceStart')
    ..aInt64(4, _omitFieldNames ? '' : 'start')
    ..aInt64(5, _omitFieldNames ? '' : 'duration')
    ..aE<MediaKind>(6, _omitFieldNames ? '' : 'mediaKind',
        enumValues: MediaKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Clip clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Clip copyWith(void Function(Clip) updates) =>
      super.copyWith((message) => updates(message as Clip)) as Clip;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Clip() / Clip.new instead')
  static Clip create() => Clip._();
  static $pb.GeneratedMessage $_createMessage() => Clip._();
  @$core.override
  Clip createEmptyInstance() => Clip._();
  @$core.pragma('dart2js:noInline')
  static Clip getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Clip>(Clip.$_createMessage);
  static Clip? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get mediaId => $_getI64(1);
  @$pb.TagNumber(2)
  set mediaId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sourceStart => $_getI64(2);
  @$pb.TagNumber(3)
  set sourceStart($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSourceStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearSourceStart() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get start => $_getI64(3);
  @$pb.TagNumber(4)
  set start($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearStart() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get duration => $_getI64(4);
  @$pb.TagNumber(5)
  set duration($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);

  /// Video or photo, so the UI shows one thumbnail for a photo's whole clip.
  @$pb.TagNumber(6)
  MediaKind get mediaKind => $_getN(5);
  @$pb.TagNumber(6)
  set mediaKind(MediaKind value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMediaKind() => $_has(5);
  @$pb.TagNumber(6)
  void clearMediaKind() => $_clearField(6);
}

/// SaveProject finished.
class ProjectSaved extends $pb.GeneratedMessage {
  factory ProjectSaved() => ProjectSaved._();

  ProjectSaved._();

  factory ProjectSaved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProjectSaved()..mergeFromBuffer(data, registry);
  factory ProjectSaved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProjectSaved()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProjectSaved',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: ProjectSaved.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectSaved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProjectSaved copyWith(void Function(ProjectSaved) updates) =>
      super.copyWith((message) => updates(message as ProjectSaved))
          as ProjectSaved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProjectSaved() / ProjectSaved.new instead')
  static ProjectSaved create() => ProjectSaved._();
  static $pb.GeneratedMessage $_createMessage() => ProjectSaved._();
  @$core.override
  ProjectSaved createEmptyInstance() => ProjectSaved._();
  @$core.pragma('dart2js:noInline')
  static ProjectSaved getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProjectSaved>(
          ProjectSaved.$_createMessage);
  static ProjectSaved? _defaultInstance;
}

/// A command was rejected; the timeline is unchanged. `reason` is developer text for logs,
/// never shown to users; add a code enum when the UI needs to explain failures.
class CommandFailed extends $pb.GeneratedMessage {
  factory CommandFailed({
    $core.String? reason,
  }) {
    final result = CommandFailed._();
    if (reason != null) result.reason = reason;
    return result;
  }

  CommandFailed._();

  factory CommandFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandFailed()..mergeFromBuffer(data, registry);
  factory CommandFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommandFailed()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommandFailed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: CommandFailed.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandFailed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommandFailed copyWith(void Function(CommandFailed) updates) =>
      super.copyWith((message) => updates(message as CommandFailed))
          as CommandFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommandFailed() / CommandFailed.new instead')
  static CommandFailed create() => CommandFailed._();
  static $pb.GeneratedMessage $_createMessage() => CommandFailed._();
  @$core.override
  CommandFailed createEmptyInstance() => CommandFailed._();
  @$core.pragma('dart2js:noInline')
  static CommandFailed getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommandFailed>(
          CommandFailed.$_createMessage);
  static CommandFailed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reason => $_getSZ(0);
  @$pb.TagNumber(1)
  set reason($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReason() => $_has(0);
  @$pb.TagNumber(1)
  void clearReason() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
