# P1-011 plan: media import (with P1-013 metadata and P1-028 photo default)

Status: accepted (2026-10-15). Defaults chosen under the user's "decide yourself" rule:
iOS copies picked files into the app; native code lives in app/ios/Runner and
app/android/app/src/main/kotlin; a MethodChannel carries picks until P1-005 replaces it with
C ABI callbacks (the proto contract does not change).

## Picker: hand-written, one MethodChannel `framix/media`, no new dependency
- image_picker (Photos only on iOS, copies on Android, no metadata) and file_picker (copies,
  churn, no metadata) both still need native metadata code, so the picker joins that channel.
- iOS: PHPickerViewController (selectionLimit 0, .ordered, images+videos,
  preferredAssetRepresentationMode .current) for Gallery; UIDocumentPickerViewController
  ([.movie, .image], asCopy: true, multiple) for Files/iCloud/Drive.
- Android: ACTION_OPEN_DOCUMENT, EXTRA_MIME_TYPES [image/*, video/*], EXTRA_ALLOW_MULTIPLE,
  takePersistableUriPermission. No permission, no androidx.

## Media reference
- Opaque `uri`, never opened by the engine, never logged.
- Android: the content:// URI, no copy (P1-012 later opens it with openFileDescriptor).
- iOS: moved into Application Support/media/<uuid>.<ext>, stored as relative `media/<uuid>.<ext>`
  (container path changes between installs: ENG-019).
- Engine validation on import and on project open: `content://...` or relative
  `media/[A-Za-z0-9-]+\.[a-z0-9]{1,5}`; no `..`, not absolute; <= 2048 bytes.

## Metadata (native now; Rust probe later, P1-013 note)
- iOS video: AVURLAsset load(.duration) (value/timescale), video track naturalSize,
  preferredTransform -> rotation, format description fourcc. Image: CGImageSource properties.
- Android video: MediaMetadataRetriever (ms, width, height, rotation) + MediaExtractor
  KEY_MIME. Image: BitmapFactory inJustDecodeBounds + android.media.ExifInterface.

## Engine contract (protocol 8 -> 9)
```proto
ImportMedia import_media = 17;  // Command.oneof
enum MediaKind { MEDIA_KIND_UNSPECIFIED = 0; MEDIA_KIND_VIDEO = 1; MEDIA_KIND_IMAGE = 2; }
message ImportMedia { repeated MediaItem items = 1; }  // pick order
message MediaItem { string uri = 1; MediaKind kind = 2; int64 duration_value = 3;
  uint32 duration_timescale = 4; uint32 width = 5; uint32 height = 6; uint32 rotation = 7;
  string codec = 8; }
```
- Reply: TimelineChanged.
- core::media: Media{uri, kind, duration: Time, width, height, rotation, codec} and
  validate(item) -> Result<Media, MediaError>. Limits: <= 100 items; sides 1..=16384; rotation in
  {0, 90, 180, 270}; codec <= 16 ASCII; video duration in (0, 24 h]; checked
  value * TICKS_PER_SECOND / timescale.
- Registry: BTreeMap<MediaId, Media> inside Timeline (same next_id), so undo, equality and save
  cover it.
- Timeline::import(Vec<Media>), all-or-nothing: first unlocked video track (or a new one), clips
  back to back from that track's end, source_start 0; video uses its duration, photos get
  PHOTO_DEFAULT_DURATION = 3 s (P1-028 default part). One undo step.
- project.proto: `repeated SavedMedia media = 6` (id, uri, kind, duration, width, height,
  rotation, codec). FORMAT_VERSION and min_reader_version -> 2 (a v1 reader would drop media on
  resave). Add a v2 fixture; the v1 fixture still opens.

## Dart UI
- "Gallery" and "Files" buttons in the timeline bottom bar (l10n en/bn, Semantics).
- app/lib/core/media/media_importer.dart wraps the channel and returns List<MediaItem>;
  registered in get_it; TimelineCubit.importMedia sends ImportMedia; cancel sends nothing.
- Progress indicator while copying/probing; CommandFailed shows a generic SnackBar.

## Tests
- Rust: each validation bound; traversal/absolute/file:// refused; all-or-nothing; locked video
  track skipped; photos 3 s; one undo step. Proptest: back to back in order, total = sum, no
  overlap, every clip's media registered.
- Project: round trip with media; v1 fixture opens; tampered uri refused; reader > 2 refused.
- Dart: fake MediaImporter + engine; Gallery sends ImportMedia in order; cancel sends nothing.
- Device/simulator (human check task): pickers, iCloud delay, Drive URIs, persistable permission
  after restart, HEIC/HEVC metadata, portrait rotation.

## Commits
1. test: core media, import, proptest, project v2 tests.
2. feat(engine): core::media, Timeline::import, proto, protocol 9, format 2 + fixture.
3. feat(native): Swift + Kotlin pickers and metadata on the channel.
4. feat(app): buttons, MediaImporter, cubit, l10n, widget test. Closes P1-011.

File: P1-028 bulk "set duration on all photos"; trims/splits must stay inside media duration
(InsertClip accepts any media_id today); color/blank clip; in-app picker with order badges.

Open: Android ACTION_OPEN_DOCUMENT does not guarantee tap order.
