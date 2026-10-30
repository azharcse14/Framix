import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:fixnum/fixnum.dart';

import 'engine_bindings.g.dart';
import 'proto/framix/v1/engine.pb.dart';

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

  /// Starts the engine. Throws [StateError] if the native side refuses (for example a
  /// protocol version mismatch between these bindings and the bundled library).
  factory FramixEngine.create() {
    final out = calloc<Pointer<Engine>>();
    try {
      final code = engine_create(ENGINE_PROTOCOL_VERSION, out);
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
          final id = event.commandFailed.commandId.toInt();
          // Id 0 answers no command (autosave); it is not shown.
          if (id != 0 && !reported.remove(id)) {
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

  /// Refused commands that no feature reports itself (see [send]'s `reportsFailure`); the UI
  /// shows a generic message for them.
  Stream<CommandFailed> get failures => _failures.stream;

  /// Queues [command] under a new id and returns the id at once; the command's
  /// CommandAccepted or CommandFailed carries it back. [reportsFailure]: the caller shows its
  /// own message, so the failure stays off [failures].
  int send(Command command, {bool reportsFailure = false}) {
    if (_disposed) throw StateError('FramixEngine used after dispose');
    final id = ++_lastId;
    command.id = Int64(id);
    if (reportsFailure) _reported.add(id);
    final bytes = command.writeToBuffer();
    final native = malloc<Uint8>(bytes.length);
    try {
      native.asTypedList(bytes.length).setAll(0, bytes);
      final code = engine_send(_engine, native, bytes.length);
      if (code != ENGINE_OK) throw StateError('engine_send failed: $code');
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
