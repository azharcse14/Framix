import 'dart:async';

import 'proto/framix/v1/engine.pb.dart';

/// The Rust engine: send [Command]s, listen to [events]. Owns one native engine instance.
class FramixEngine {
  FramixEngine._();

  /// Starts the engine. Throws [StateError] if the native side refuses.
  factory FramixEngine.create() => FramixEngine._();

  /// Engine events, one per command, in command order.
  Stream<Event> get events => const Stream.empty();

  /// Queues [command]; returns at once.
  void send(Command command) {}

  /// Stops the engine and closes [events].
  void dispose() {}
}
