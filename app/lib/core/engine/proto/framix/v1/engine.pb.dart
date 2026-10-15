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
    0: Command_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Command',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Command.$_createMessage)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8])
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
  Command_Kind whichKind() => _Command_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
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

enum Event_Kind { timelineChanged, commandFailed, projectSaved, notSet }

/// Sent by the engine. Exactly one kind is set.
class Event extends $pb.GeneratedMessage {
  factory Event({
    TimelineChanged? timelineChanged,
    CommandFailed? commandFailed,
    ProjectSaved? projectSaved,
  }) {
    final result = Event._();
    if (timelineChanged != null) result.timelineChanged = timelineChanged;
    if (commandFailed != null) result.commandFailed = commandFailed;
    if (projectSaved != null) result.projectSaved = projectSaved;
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
    0: Event_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Event.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<TimelineChanged>(1, _omitFieldNames ? '' : 'timelineChanged',
        subBuilder: TimelineChanged.$_createMessage)
    ..aOM<CommandFailed>(2, _omitFieldNames ? '' : 'commandFailed',
        subBuilder: CommandFailed.$_createMessage)
    ..aOM<ProjectSaved>(3, _omitFieldNames ? '' : 'projectSaved',
        subBuilder: ProjectSaved.$_createMessage)
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
  Event_Kind whichKind() => _Event_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
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
}

/// Full timeline state after a successful command or GetTimeline.
class TimelineChanged extends $pb.GeneratedMessage {
  factory TimelineChanged({
    $core.Iterable<Track>? tracks,
    $fixnum.Int64? duration,
    $core.bool? canUndo,
    $core.bool? canRedo,
  }) {
    final result = TimelineChanged._();
    if (tracks != null) result.tracks.addAll(tracks);
    if (duration != null) result.duration = duration;
    if (canUndo != null) result.canUndo = canUndo;
    if (canRedo != null) result.canRedo = canRedo;
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
}

/// A track and its clips, sorted by start.
class Track extends $pb.GeneratedMessage {
  factory Track({
    $fixnum.Int64? id,
    TrackKind? kind,
    $core.Iterable<Clip>? clips,
    $core.int? number,
  }) {
    final result = Track._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (clips != null) result.clips.addAll(clips);
    if (number != null) result.number = number;
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
}

/// A clip on a track.
class Clip extends $pb.GeneratedMessage {
  factory Clip({
    $fixnum.Int64? id,
    $fixnum.Int64? mediaId,
    $fixnum.Int64? sourceStart,
    $fixnum.Int64? start,
    $fixnum.Int64? duration,
  }) {
    final result = Clip._();
    if (id != null) result.id = id;
    if (mediaId != null) result.mediaId = mediaId;
    if (sourceStart != null) result.sourceStart = sourceStart;
    if (start != null) result.start = start;
    if (duration != null) result.duration = duration;
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
