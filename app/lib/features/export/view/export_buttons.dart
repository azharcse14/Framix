import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/media/export_sharer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/export_cubit.dart';

/// Export, its progress and cancel, then save to gallery and share for the finished file.
class ExportButtons extends StatefulWidget {
  const ExportButtons({super.key});

  @override
  State<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<ExportButtons> {
  /// The export folder: Dart temp until the platform answers (within the first frames).
  String _dir = Directory.systemTemp.path;

  /// Where the last export was written; save and share read this file.
  String? _exported;

  /// One export file; each export replaces it.
  String get _path => _exported ?? '$_dir/framix-export.mp4';

  @override
  void initState() {
    super.initState();
    ExportSharer.exportDir().then((dir) => _dir = dir);
  }

  void _export(ExportCubit cubit) {
    final path = '$_dir/framix-export.mp4';
    _exported = path;
    cubit.start(path);
  }

  /// A save or share is reading the file; a new export would overwrite it underneath.
  bool _busy = false;

  void _tell(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _whileBusy(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(AppLocalizations l10n) => _whileBusy(() async {
    final result = await const ExportSharer().saveToGallery(_path);
    if (!mounted) return;
    _tell(switch (result) {
      SaveResult.saved => l10n.savedToGallery,
      SaveResult.denied => l10n.saveDenied,
      SaveResult.failed => l10n.saveFailed,
    });
  });

  Future<void> _share(AppLocalizations l10n) => _whileBusy(() async {
    if (await const ExportSharer().share(_path)) return;
    if (mounted) _tell(l10n.shareFailed);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExportCubit>();
    return BlocConsumer<ExportCubit, ExportState>(
      listenWhen: (_, next) => next is ExportFailed,
      listener: (_, _) => _tell(l10n.exportFailed),
      builder: (context, state) {
        if (state is ExportRunning) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: state.frames > 0 ? state.frame / state.frames : null,
                  semanticsLabel: l10n.exporting,
                ),
              ),
              IconButton(
                tooltip: l10n.cancelExport,
                icon: const Icon(Icons.close),
                onPressed: cubit.cancel,
              ),
            ],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state is ExportDone) ...[
              IconButton(
                tooltip: l10n.saveToGallery,
                icon: const Icon(Icons.save_alt),
                onPressed: _busy ? null : () => _save(l10n),
              ),
              IconButton(
                tooltip: l10n.share,
                icon: const Icon(Icons.share),
                onPressed: _busy ? null : () => _share(l10n),
              ),
            ],
            IconButton(
              tooltip: l10n.export,
              icon: const Icon(Icons.movie),
              onPressed: _busy ? null : () => _export(cubit),
            ),
          ],
        );
      },
    );
  }
}
