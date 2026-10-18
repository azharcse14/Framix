import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framix/core/engine/proto/framix/v1/engine.pb.dart';
import 'package:framix/core/media/channel_media_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('framix/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void reply(Object? Function(MethodCall call) handler) => messenger
      .setMockMethodCallHandler(channel, (call) async => handler(call));

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('maps channel maps to MediaItems in order', () async {
    reply(
      (call) => [
        {
          'uri': 'content://media/1',
          'kind': 'video',
          'durationValue': 1500,
          'durationTimescale': 1000,
          'width': 1920,
          'height': 1080,
          'rotation': 90,
          'codec': 'hevc',
        },
        {'uri': 'media/a.jpg', 'kind': 'image', 'width': 4, 'height': 3},
      ],
    );
    final items = await const ChannelMediaImporter().pickFromGallery();
    expect(items.map((i) => i.uri), ['content://media/1', 'media/a.jpg']);
    expect(items[0].kind, MediaKind.MEDIA_KIND_VIDEO);
    expect(items[0].durationValue.toInt(), 1500);
    expect(
      (items[0].width, items[0].rotation, items[0].codec),
      (1920, 90, 'hevc'),
    );
    expect(items[1].kind, MediaKind.MEDIA_KIND_IMAGE);
  });

  test('a platform error or a bad value never throws', () async {
    reply((call) => throw PlatformException(code: 'busy'));
    expect(await const ChannelMediaImporter().pickFromFiles(), isEmpty);

    reply(
      (call) => [
        {'uri': 'media/bad.jpg', 'kind': 'image', 'width': -1, 'height': -1},
        {'uri': 'media/ok.jpg', 'kind': 'image', 'width': 2, 'height': 2},
      ],
    );
    final items = await const ChannelMediaImporter().pickFromGallery();
    expect(items.map((i) => i.uri), [
      'media/ok.jpg',
    ], reason: 'bad item skipped');
  });
}
