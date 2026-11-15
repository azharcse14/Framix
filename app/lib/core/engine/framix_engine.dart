import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import 'engine_bindings.g.dart';
import 'proto/framix/v1/engine.pb.dart';

/// The bundled engine library refused these bindings' protocol [version]: the app and the
/// library were built from different contracts.
class EngineProtocolMismatch extends Error {
  EngineProtocolMismatch(this.version);

  /// The version these bindings asked for.
  final int version;

  @override
  String toString() => 'Engine refused protocol version $version';
}

/// Starts the engine (ENG-045). On a protocol mismatch a debug build fails fast
/// ([failFast]); a release build reports it through [FlutterError.reportError] (Sentry)
/// and returns null, so the app shows an error screen instead of nothing.
FramixEngine? startEngine({
  bool failFast = kDebugMode,
  FramixEngine Function() create = FramixEngine.create,
}) {
  try {
    return create();
  } on EngineProtocolMismatch catch (error, stack) {
    if (failFast) rethrow;
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'framix'),
    );
    return null;
  }
}

/// The Rust engine: send [Command]s, listen to [events]. Owns one native engine instance.
class FramixEngine {
  FramixEngine._(this._engine, this._events, this._failures, this._reported);

  final Pointer<Engine> _engine;
  final StreamController<Event> _events;
  final StreamController<CommandFailed> _failures;

  /// Ids of sent commands whose sender reports a failure itself, until their reply arrives.
  final Set<int> _reported;
  int _lastId = 0;
  bool _disposed = false;

  /// Starts the engine. Throws [EngineProtocolMismatch] if the bundled library speaks
  /// another protocol than these bindings, [StateError] if it refuses for another reason.
  /// [protocolVersion] is only overridden by tests.
  factory FramixEngine.create({
    @visibleForTesting int protocolVersion = ENGINE_PROTOCOL_VERSION,
  }) {
    final out = calloc<Pointer<Engine>>();
    try {
      final code = engine_create(protocolVersion, out);
      if (code == ENGINE_ERR_PROTOCOL) {
        throw EngineProtocolMismatch(protocolVersion);
      }
      if (code != ENGINE_OK) throw StateError('engine_create failed: $code');
      final engine = out.value;
      final events = StreamController<Event>.broadcast();
      final failures = StreamController<CommandFailed>.broadcast();
      final reported = <int>{};
      late final NativeCallable<EngineEventCallbackFunction> listener;
      // Called from the engine thread; a listener hops onto this isolate (GOT-007).
      listener = NativeCallable<EngineEventCallbackFunction>.listener((
        Pointer<Uint8> ptr,
        int len,
      ) {
        final event = _takeEvent(ptr, len);
        if (event.hasCommandAccepted()) {
          reported.remove(event.commandAccepted.commandId.toInt());
        }
        if (event.hasCommandFailed()) {
          final failed = event.commandFailed;
          final id = failed.commandId.toInt();
          // Id 0 answers no command (a late preview failure); only a failed autosave is
          // shown, as the edits are unsaved.
          final shown =
              id != 0 || failed.kind == FailureKind.FAILURE_KIND_AUTOSAVE;
          if (shown && !reported.remove(id)) {
            failures.add(event.commandFailed);
          }
        }
        if (!event.hasEngineStopped()) return events.add(event);
        // The engine's last event: nothing else will call the listener.
        listener.close();
        events.close();
        failures.close();
      });
      engine_set_event_callback(engine, listener.nativeFunction);
      return FramixEngine._(engine, events, failures, reported);
    } finally {
      calloc.free(out);
    }
  }

  /// Engine events: exactly one per command, in command order; results of accepted platform
  /// work (PreviewReady, or CommandFailed) arrive later on their own.
  Stream<Event> get events => _events.stream;

  /// Refused commands that no feature reports itself (see [send]'s `reportsFailure`), and
  /// failed autosaves (id 0, FAILURE_KIND_AUTOSAVE); the UI shows a message for them.
  Stream<CommandFailed> get failures => _failures.stream;

  /// Queues [command] under a new id and returns the id at once; the command's
  /// CommandAccepted or CommandFailed carries it back. [reportsFailure]: the caller shows its
  /// own message, so the failure stays off [failures].
  int send(Command command, {bool reportsFailure = false}) {
    if (_disposed) throw StateError('FramixEngine used after dispose');
    final id = ++_lastId;
    command.id = Int64(id);
    final bytes = command.writeToBuffer();
    final native = malloc<Uint8>(bytes.length);
    try {
      native.asTypedList(bytes.length).setAll(0, bytes);
      final code = engine_send(_engine, native, bytes.length);
      if (code != ENGINE_OK) throw StateError('engine_send failed: $code');
      // Only once sent: a send that throws gets no reply to clear the id.
      if (reportsFailure) _reported.add(id);
    } finally {
      malloc.free(native);
    }
    return id;
  }

  /// Stops the engine and returns at once. Replies to queued commands still arrive on
  /// [events], which then closes. Safe to call twice.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    engine_destroy(_engine);
  }

  /// Decodes an engine-owned buffer and gives it back to the engine.
  static Event _takeEvent(Pointer<Uint8> ptr, int len) {
    final bytes = Uint8List.fromList(ptr.asTypedList(len));
    engine_free_buffer(
      Struct.create<EngineBuffer>()
        ..ptr = ptr
        ..len = len,
    );
    return Event.fromBuffer(bytes);
  }
}
