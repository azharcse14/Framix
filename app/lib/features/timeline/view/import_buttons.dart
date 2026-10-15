import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/media/media_importer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/timeline_cubit.dart';

/// Gallery and Files import buttons; disabled while a pick (copy and metadata) is running.
class ImportButtons extends StatefulWidget {
  const ImportButtons({super.key});

  @override
  State<ImportButtons> createState() => _ImportButtonsState();
}

class _ImportButtonsState extends State<ImportButtons> {
  bool _busy = false;

  Future<void> _import(Future<List<MediaItem>> Function() pick) async {
    setState(() => _busy = true);
    try {
      await context.read<TimelineCubit>().importMedia(pick);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final importer = context.read<MediaImporter>();
    if (_busy) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: l10n.importing,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.importFromGallery,
          icon: const Icon(Icons.photo_library),
          onPressed: () => _import(importer.pickFromGallery),
        ),
        IconButton(
          tooltip: l10n.importFromFiles,
          icon: const Icon(Icons.folder_open),
          onPressed: () => _import(importer.pickFromFiles),
        ),
      ],
    );
  }
}
