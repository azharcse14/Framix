import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/media/export_sharer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void handle(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });

  tearDown(() async {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('the export folder comes from the platform', () async {
    handle((_) async => '/data/user/0/app/cache');
    expect(await ExportSharer.exportDir(), '/data/user/0/app/cache');
    expect(calls.single.method, 'exportDir');
  });

  test('without a platform answer the export folder is Dart temp', () async {
    expect(await ExportSharer.exportDir(), Directory.systemTemp.path);
  });
}
