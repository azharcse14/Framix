import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';
import '../../../core/media/channel_media_importer.dart' as media;
import '../../../core/ui/framix_theme.dart';
import '../../../core/ui/timecode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/view/timeline_page.dart';
import '../bloc/home_cubit.dart';

/// Home: New project and the user's projects (P1-089). The editor opens on top of it.
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.projectsDir = media.projectsDir});

  /// Where the projects live (the platform's folder; a temp folder in tests).
  final Future<String?> Function() projectsDir;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => HomeCubit(context.read<FramixEngine>(), projectsDir),
    child: const _HomeView(),
  );
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  /// Shows the editor, then lists again so the edited project moves to the top.
  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TimelinePage()));
    cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<FramixColors>()!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectsTitle)),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) => switch (state) {
          HomeLoading() => const Center(child: CircularProgressIndicator()),
          HomeUnavailable() => Center(
            child: Padding(
              padding: const EdgeInsets.all(FramixSpace.m),
              child: Text(
                l10n.projectsUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
          HomeProjects(:final projects) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(FramixSpace.m),
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newProject),
                  onPressed: () {
                    context.read<HomeCubit>().newProject();
                    _edit(context);
                  },
                ),
              ),
              Expanded(
                child: projects.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(FramixSpace.m),
                          child: Text(
                            l10n.projectsEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (context, i) => _ProjectRow(
                          project: projects[i],
                          onTap: () {
                            context.read<HomeCubit>().open(projects[i].id);
                            _edit(context);
                          },
                        ),
                      ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// One project: its length, clips and when it was last edited.
class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});

  final ProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final edited = DateFormat.yMMMd(locale).add_jm().format(
      DateTime.fromMillisecondsSinceEpoch(project.modifiedMs.toInt()),
    );
    return ListTile(
      leading: const Icon(Icons.movie_outlined),
      title: Text(
        timecode(project.duration.toInt(), project.ticksPerSecond.toInt()),
      ),
      subtitle: Text(
        '${l10n.clipCount(project.clips)} · ${l10n.projectEdited(edited)}',
      ),
      onTap: onTap,
    );
  }
}
