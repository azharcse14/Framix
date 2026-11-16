import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/media/export_sharer.dart';
import '../../../core/ui/framix_theme.dart';
import '../../../core/ui/messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../preview/view/preview_view.dart';
import '../../timeline/bloc/playback_cubit.dart';

/// The Result screen over the editor once an export finished: the preview, save to the
/// gallery, share (Files is in the share sheet), Back to edit, and Done (Home).
class ExportResultPage extends StatefulWidget {
  const ExportResultPage({super.key, required this.path});

  /// The exported file; save and share read it.
  final String path;

  @override
  State<ExportResultPage> createState() => _ExportResultPageState();
}

class _ExportResultPageState extends State<ExportResultPage> {
  /// A save or share is reading the file. Leaving is held too: back in the editor a new
  /// export would overwrite the file underneath.
  bool _busy = false;

  /// A one-time result: it replaces a message still showing (except a failed-autosave
  /// message) and outranks a generic one waiting behind that.
  void _tell(String text) => showMessage(context, text, important: true);

  Future<void> _whileBusy(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(AppLocalizations l10n) => _whileBusy(() async {
    final result = await const ExportSharer().saveToGallery(widget.path);
    if (!mounted) return;
    _tell(switch (result) {
      SaveResult.saved => l10n.savedToGallery,
      SaveResult.denied => l10n.saveDenied,
      SaveResult.failed => l10n.saveFailed,
    });
  });

  Future<void> _share(AppLocalizations l10n) => _whileBusy(() async {
    if (await const ExportSharer().share(widget.path)) return;
    if (mounted) _tell(l10n.shareFailed);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _busy;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.backToEdit,
            icon: const BackButtonIcon(),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
          title: Text(l10n.exportResultTitle),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(l10n.done),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FramixSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The engine's preview: the same render path the export used.
                const Expanded(
                  child: Center(child: PreviewView(editable: false)),
                ),
                Center(
                  child: BlocBuilder<PlaybackCubit, bool>(
                    builder: (context, playing) => IconButton(
                      tooltip: playing ? l10n.pause : l10n.play,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: playing
                          ? context.read<PlaybackCubit>().pause
                          : context.read<PlaybackCubit>().play,
                    ),
                  ),
                ),
                const SizedBox(height: FramixSpace.m),
                // The one primary action, low on the screen (docs/design-system.md).
                FilledButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: Text(l10n.saveToGallery),
                  onPressed: busy ? null : () => _save(l10n),
                ),
                const SizedBox(height: FramixSpace.s),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: Text(l10n.share),
                  onPressed: busy ? null : () => _share(l10n),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
