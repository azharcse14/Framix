import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'engine_bindings.g.dart';
import 'proto/framix/v1/engine.pb.dart';

/// The Rust engine: send [Command]s, listen to [events]. Owns one native engine instance.
class FramixEngine {
  FramixEngine._(this._engine, this._listener, this._events);

  final Pointer<Engine> _engine;
  final NativeCallable<EngineEventCallbackFunction> _listener;
  final StreamController<Event> _events;
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
      // Called from the engine thread; a listener hops onto this isolate (GOT-007).
      final listener = NativeCallable<EngineEventCallbackFunction>.listener(
        (Pointer<Uint8> ptr, int len) => events.add(_takeEvent(ptr, len)),
      );
      engine_set_event_callback(engine, listener.nativeFunction);
      return FramixEngine._(engine, listener, events);
    } finally {
      calloc.free(out);
    }
  }

  /// Engine events: exactly one per command, in command order; results of accepted platform
  /// work (PreviewReady, or CommandFailed) arrive later on their own.
  Stream<Event> get events => _events.stream;

  /// Queues [command]; returns at once.
  void send(Command command) {
    if (_disposed) throw StateError('FramixEngine used after dispose');
    final bytes = command.writeToBuffer();
    final native = malloc<Uint8>(bytes.length);
    try {
      native.asTypedList(bytes.length).setAll(0, bytes);
      final code = engine_send(_engine, native, bytes.length);
      if (code != ENGINE_OK) throw StateError('engine_send failed: $code');
    } finally {
      malloc.free(native);
    }
  }

  /// Stops the engine (after queued commands) and closes [events]. Safe to call twice.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Blocks until queued commands finish (engine_destroy joins the engine thread).
    engine_destroy(_engine);
    // ponytail: every event not yet delivered to this isolate (each a full timeline
    // snapshot) is dropped and its buffer leaked; P1-044 makes destroy non-blocking with
    // an end-of-stream marker so in-flight events are freed.
    _listener.close();
    _events.close();
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
