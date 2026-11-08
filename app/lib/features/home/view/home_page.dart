import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart'
    show ProjectSummary;
import '../../../core/media/channel_media_importer.dart' as media;
import '../../../core/ui/framix_theme.dart';
import '../../../core/ui/small_spinner.dart';
import '../../../core/ui/timecode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/view/timeline_page.dart';
import '../bloc/home_cubit.dart';
import 'edited_label.dart';

/// Home: the user's projects and New project (P1-089, P1-090). The editor opens on top.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.projectsDir = media.projectsDir,
    this.cacheDir = media.cacheDir,
  });

  /// Where the projects live (the platform's folder; a temp folder in tests).
  final Future<String?> Function() projectsDir;

  /// The platform's cache folder (thumbnails, proxies); null when there is none.
  final Future<String?> Function() cacheDir;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => HomeCubit(context.read<FramixEngine>(), projectsDir),
    child: const _HomeView(),
  );
}

/// Corner radius of project cards and their thumbnails.
const double _cardRadius = 16;

class _HomeView extends StatelessWidget {
  const _HomeView();

  /// Shows the editor once [switched] says the engine opened the project.
  static Future<void> _editAfter(
    BuildContext context,
    Future<bool> switched,
  ) async {
    if (await switched && context.mounted) await _edit(context);
  }

  /// Shows the editor, then lists again so the edited project moves to the top.
  static Future<void> _edit(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TimelinePage()));
    cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FramixSpace.m,
                  FramixSpace.m,
                  FramixSpace.m,
                  FramixSpace.s,
                ),
                child: Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: switch (state) {
                  HomeLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  HomeUnavailable() => _Message(
                    icon: Icons.folder_off_outlined,
                    body: l10n.projectsUnavailable,
                    action: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                      onPressed: context.read<HomeCubit>().retry,
                    ),
                  ),
                  HomeProjects(projects: []) => _Message(
                    icon: Icons.movie_creation_outlined,
                    title: l10n.projectsEmptyTitle,
                    body: l10n.projectsEmpty,
                  ),
                  HomeProjects(:final projects, :final opening) => _ProjectGrid(
                    projects: projects,
                    opening: opening,
                    onOpen: (id) =>
                        _editAfter(context, context.read<HomeCubit>().open(id)),
                  ),
                },
              ),
              if (state is HomeProjects)
                Padding(
                  padding: const EdgeInsets.all(FramixSpace.m),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: state.opening == HomeProjects.newProjectKey
                        ? _progress(context)
                        : const Icon(Icons.add),
                    label: Text(l10n.newProject),
                    onPressed: () => _editAfter(
                      context,
                      context.read<HomeCubit>().newProject(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred icon in a circle with a short message (empty list, no projects folder).
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.body,
    this.title,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String body;

  /// A button under the message, if there is something to do.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = FramixColors.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FramixSpace.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(FramixSpace.m),
                child: Icon(icon, size: 44, color: colors.textMuted),
              ),
            ),
            if (title case final title?) ...[
              const SizedBox(height: FramixSpace.m),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: FramixSpace.s),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(height: FramixSpace.m),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// The projects, newest first, two cards per row on a phone (more on wider screens).
class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({
    required this.projects,
    required this.onOpen,
    this.opening,
  });

  /// The project the engine is loading for the editor, if any.
  final String? opening;

  final List<ProjectSummary> projects;
  final void Function(String id) onOpen;

  /// Widest a card gets before another column fits.
  static const double _maxCardWidth = 240;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = FramixColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = FramixSpace.s;
        final inner = constraints.maxWidth - 2 * FramixSpace.m;
        final columns = ((inner + gap) / (_maxCardWidth + gap)).ceil().clamp(
          2,
          6,
        );
        final width = (inner - gap * (columns - 1)) / columns;
        // A Wrap, not a fixed-height grid: Bangla and large text make cards taller.
        // ponytail: builds every card; a lazy sliver grid once lists get long (OVL-015).
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            FramixSpace.m,
            0,
            FramixSpace.m,
            FramixSpace.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: FramixSpace.m),
                child: Text(
                  l10n.recentProjects(projects.length),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.textMuted),
                ),
              ),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final p in projects)
                    SizedBox(
                      width: width,
                      child: _ProjectCard(
                        project: p,
                        opening: p.id == opening,
                        onTap: () => onOpen(p.id),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One project: a thumbnail panel with its length, then when it was edited and its clips.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.opening = false,
  });

  /// The engine is loading this project for the editor.
  final bool opening;

  final ProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = FramixColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final length = timecode(
      project.duration.toInt(),
      project.ticksPerSecond.toInt(),
    );
    final edited = editedLabel(
      l10n,
      locale,
      DateTime.now(),
      DateTime.fromMillisecondsSinceEpoch(project.modifiedMs.toInt()),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(FramixSpace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ponytail: a placeholder until projects carry a cover frame.
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.elevated,
                        borderRadius: BorderRadius.circular(
                          _cardRadius - FramixSpace.s,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: opening
                                ? IconTheme(
                                    data: IconThemeData(
                                      size: 36,
                                      color: colors.textMuted,
                                    ),
                                    child: _progress(context),
                                  )
                                : Icon(
                                    Icons.movie_outlined,
                                    size: 36,
                                    color: colors.textMuted,
                                  ),
                          ),
                          Positioned(
                            right: FramixSpace.s,
                            top: FramixSpace.s,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: BorderRadius.circular(
                                  FramixSpace.s,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: FramixSpace.s,
                                ),
                                child: Text(
                                  length,
                                  style: text.labelSmall?.copyWith(
                                    color: colors.text,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FramixSpace.s),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edited,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.clipCount(project.clips),
                        style: text.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The spinner in an icon's place while the engine saves and loads a project; the icon
/// color keeps it visible on the accent New project button.
Widget _progress(BuildContext context) => SmallSpinner(
  label: AppLocalizations.of(context).openingProject,
  iconColor: true,
);
