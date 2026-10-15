import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';

// Test-only binding: proves the build hook bundles the Rust library. The real bindings
// come from ffigen (P1-007).
final class _EngineBuffer extends Struct {
  external Pointer<Uint8> ptr;

  @Size()
  external int len;
}

@Native<Int32 Function(_EngineBuffer)>(
  symbol: 'engine_free_buffer',
  assetId: 'package:framix/engine',
)
external int _engineFreeBuffer(_EngineBuffer buffer);

void main() {
  test('Rust engine library is bundled and callable', () {
    final empty = Struct.create<_EngineBuffer>()
      ..ptr = nullptr
      ..len = 0;
    expect(_engineFreeBuffer(empty), 0);
  });
}
