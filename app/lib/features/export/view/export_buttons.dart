import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/media/export_sharer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bloc/export_cubit.dart';

/// Export, its progress and cancel, then save to gallery and share for the finished file.
class ExportButtons extends StatelessWidget {
  const ExportButtons({super.key});

  /// One export file in the app's temp folder; each export replaces it.
  static String get exportPath =>
      '${Directory.systemTemp.path}/framix-export.mp4';

  static void _tell(BuildContext context, String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save(BuildContext context, AppLocalizations l10n) async {
    final result = await const ExportSharer().saveToGallery(exportPath);
    if (!context.mounted) return;
    _tell(context, switch (result) {
      SaveResult.saved => l10n.savedToGallery,
      SaveResult.denied => l10n.saveDenied,
      SaveResult.failed => l10n.saveFailed,
    });
  }

  Future<void> _share(BuildContext context, AppLocalizations l10n) async {
    if (await const ExportSharer().share(exportPath)) return;
    if (context.mounted) _tell(context, l10n.shareFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExportCubit>();
    return BlocConsumer<ExportCubit, ExportState>(
      listenWhen: (_, next) => next is ExportFailed,
      listener: (context, _) => _tell(context, l10n.exportFailed),
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
                onPressed: () => _save(context, l10n),
              ),
              IconButton(
                tooltip: l10n.share,
                icon: const Icon(Icons.share),
                onPressed: () => _share(context, l10n),
              ),
            ],
            IconButton(
              tooltip: l10n.export,
              icon: const Icon(Icons.movie),
              onPressed: () => cubit.start(exportPath),
            ),
          ],
        );
      },
    );
  }
}
