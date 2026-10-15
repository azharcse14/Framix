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

enum Command_Kind { addTrack, insertClip, undo, redo, notSet }

/// Sent by the UI. Exactly one kind is set.
class Command extends $pb.GeneratedMessage {
  factory Command({
    AddTrack? addTrack,
    InsertClip? insertClip,
    Undo? undo,
    Redo? redo,
  }) {
    final result = Command._();
    if (addTrack != null) result.addTrack = addTrack;
    if (insertClip != null) result.insertClip = insertClip;
    if (undo != null) result.undo = undo;
    if (redo != null) result.redo = redo;
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
    0: Command_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Command',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Command.$_createMessage)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<AddTrack>(1, _omitFieldNames ? '' : 'addTrack',
        subBuilder: AddTrack.$_createMessage)
    ..aOM<InsertClip>(2, _omitFieldNames ? '' : 'insertClip',
        subBuilder: InsertClip.$_createMessage)
    ..aOM<Undo>(3, _omitFieldNames ? '' : 'undo',
        subBuilder: Undo.$_createMessage)
    ..aOM<Redo>(4, _omitFieldNames ? '' : 'redo',
        subBuilder: Redo.$_createMessage)
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
  Command_Kind whichKind() => _Command_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
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

enum Event_Kind { timelineChanged, commandFailed, notSet }

/// Sent by the engine. Exactly one kind is set.
class Event extends $pb.GeneratedMessage {
  factory Event({
    TimelineChanged? timelineChanged,
    CommandFailed? commandFailed,
  }) {
    final result = Event._();
    if (timelineChanged != null) result.timelineChanged = timelineChanged;
    if (commandFailed != null) result.commandFailed = commandFailed;
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
    0: Event_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'framix.v1'),
      createEmptyInstance: Event.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<TimelineChanged>(1, _omitFieldNames ? '' : 'timelineChanged',
        subBuilder: TimelineChanged.$_createMessage)
    ..aOM<CommandFailed>(2, _omitFieldNames ? '' : 'commandFailed',
        subBuilder: CommandFailed.$_createMessage)
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
  Event_Kind whichKind() => _Event_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
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
}

/// Full timeline state after a successful command.
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
  }) {
    final result = Track._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (clips != null) result.clips.addAll(clips);
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
