import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/media/export_sharer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void reply(Object? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return handler(call);
      });

  tearDown(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('save sends the path and maps the platform answer', () async {
    reply((_) => 'saved');
    expect(
      await const ExportSharer().saveToGallery('/tmp/a.mp4'),
      SaveResult.saved,
    );
    expect(calls.single.method, 'saveToGallery');
    expect(calls.single.arguments, {'path': '/tmp/a.mp4'});

    reply((_) => 'denied');
    expect(
      await const ExportSharer().saveToGallery('/tmp/a.mp4'),
      SaveResult.denied,
    );
  });

  test('a platform error or an unknown answer is a failed save', () async {
    reply((_) => throw PlatformException(code: 'io'));
    expect(
      await const ExportSharer().saveToGallery('/tmp/a.mp4'),
      SaveResult.failed,
    );
    reply((_) => 'maybe');
    expect(
      await const ExportSharer().saveToGallery('/tmp/a.mp4'),
      SaveResult.failed,
    );
  });

  test('share sends the path; a platform error never throws', () async {
    reply((_) => null);
    expect(await const ExportSharer().share('/tmp/a.mp4'), isTrue);
    expect(calls.single.method, 'share');
    expect(calls.single.arguments, {'path': '/tmp/a.mp4'});

    reply((_) => throw PlatformException(code: 'no-presenter'));
    expect(await const ExportSharer().share('/tmp/a.mp4'), isFalse);
  });
}
