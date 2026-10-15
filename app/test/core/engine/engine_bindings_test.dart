import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/engine_bindings.g.dart';

void main() {
  test('generated bindings reach the bundled engine', () {
    final empty = Struct.create<EngineBuffer>()
      ..ptr = nullptr
      ..len = 0;
    expect(engine_free_buffer(empty), ENGINE_OK);
    expect(ENGINE_ERR_PANIC, -1);
  });
}
