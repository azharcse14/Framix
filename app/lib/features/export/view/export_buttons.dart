import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/media/export_sharer.dart';
import '../../../core/ui/file_size.dart';
import '../../../core/ui/messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/ui/small_spinner.dart';
import '../../preview/bloc/preview_cubit.dart';
import '../../timeline/bloc/playback_cubit.dart';
import '../bloc/export_cubit.dart';
import 'export_result_page.dart';

/// Export, its progress and cancel; a finished export opens the Result screen.
class ExportButtons extends StatefulWidget {
  const ExportButtons({super.key});

  @override
  State<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<ExportButtons> {
  /// The export folder: Dart temp until the platform answers (within the first frames).
  String _dir = Directory.systemTemp.path;

  /// Where the last export was written; the Result screen saves and shares this file.
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

  /// A one-time result: it replaces a message still showing (except a failed-autosave
  /// message) and outranks a generic one waiting behind that.
  void _tell(String text) => showMessage(context, text, important: true);

  /// Opens the Result screen for the file just exported. The route carries the cubits it
  /// reads, as the editor sees them (they may sit below the Navigator).
  void _showResult() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<PreviewCubit>()),
          BlocProvider.value(value: context.read<PlaybackCubit>()),
        ],
        child: ExportResultPage(path: _path),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExportCubit>();
    final locale = '${Localizations.localeOf(context)}';
    return BlocConsumer<ExportCubit, ExportState>(
      listenWhen: (_, next) =>
          next is ExportDone || next is ExportFailed || next is ExportNoSpace,
      listener: (_, state) {
        if (state is ExportDone) return _showResult();
        _tell(switch (state) {
          // Needed rounds up, free rounds down: needed always reads as more than free.
          ExportNoSpace(:final neededBytes, :final freeBytes) =>
            l10n.exportNoSpace(
              fileSize(l10n, locale, neededBytes, rounding: SizeRounding.up),
              fileSize(l10n, locale, freeBytes, rounding: SizeRounding.down),
            ),
          _ => l10n.exportFailed,
        });
      },
      builder: (context, state) {
        if (state is ExportRunning) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SmallSpinner(
                label: l10n.exporting,
                value: state.frames > 0 ? state.frame / state.frames : null,
              ),
              IconButton(
                tooltip: l10n.cancelExport,
                icon: const Icon(Icons.close),
                onPressed: cubit.cancel,
              ),
            ],
          );
        }
        return IconButton(
          tooltip: l10n.export,
          icon: const Icon(Icons.movie),
          onPressed: () => _export(cubit),
        );
      },
    );
  }
}
