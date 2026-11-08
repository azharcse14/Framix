import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart'
    show ProjectSort, ProjectSummary;

import '../../../core/media/channel_media_importer.dart' as media;
import '../../../core/ui/framix_theme.dart';
import '../../../core/ui/small_spinner.dart';
import '../../../core/ui/timecode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../timeline/view/timeline_page.dart';
import '../bloc/home_cubit.dart';
import 'edited_label.dart';
import 'file_size.dart';

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
    create: (context) => HomeCubit(
      context.read<FramixEngine>(),
      projectsDir,
      cacheDir: cacheDir,
    ),
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
        child: BlocConsumer<HomeCubit, HomeState>(
          listenWhen: (_, state) => state is HomeProjects && state.recovered,
          listener: (context, _) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.workRecovered))),
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
                  HomeProjects(
                    projects: [],
                    filtered: false,
                    deletedCount: 0,
                  ) =>
                    _Message(
                      icon: Icons.movie_creation_outlined,
                      title: l10n.projectsEmptyTitle,
                      body: l10n.projectsEmpty,
                    ),
                  HomeProjects(:final projects, :final opening) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FindBar(state: state),
                      Expanded(
                        child: projects.isEmpty
                            ? _Message(
                                icon: state.showingDeleted
                                    ? Icons.delete_outline
                                    : state.filtered
                                    ? Icons.search_off
                                    : Icons.movie_creation_outlined,
                                body: state.showingDeleted
                                    ? l10n.recentlyDeletedEmpty
                                    : state.filtered
                                    ? l10n.noMatchingProjects
                                    : l10n.projectsEmpty,
                              )
                            : _ProjectGrid(
                                projects: projects,
                                opening: opening,
                                onOpen: (id) => _editAfter(
                                  context,
                                  context.read<HomeCubit>().open(id),
                                ),
                              ),
                      ),
                    ],
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

/// Search, sort and the folder chips above the projects (P1-015).
class _FindBar extends StatelessWidget {
  const _FindBar({required this.state});

  final HomeProjects state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<HomeCubit>();
    final sorts = {
      ProjectSort.PROJECT_SORT_UNSPECIFIED: l10n.sortByDate,
      ProjectSort.PROJECT_SORT_NAME: l10n.sortByName,
      ProjectSort.PROJECT_SORT_SIZE: l10n.sortBySize,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FramixSpace.m,
        0,
        FramixSpace.s,
        FramixSpace.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.searchProjects,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: cubit.search,
                ),
              ),
              PopupMenuButton<ProjectSort>(
                icon: const Icon(Icons.sort),
                tooltip: l10n.sortProjects,
                initialValue: state.sort,
                onSelected: cubit.sortBy,
                itemBuilder: (_) => [
                  for (final MapEntry(:key, :value) in sorts.entries)
                    CheckedPopupMenuItem(
                      value: key,
                      checked: key == state.sort,
                      child: Text(value),
                    ),
                ],
              ),
            ],
          ),
          if (state.folders.isNotEmpty ||
              state.deletedCount > 0 ||
              state.showingDeleted)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: FramixSpace.s),
              child: Row(
                spacing: FramixSpace.s,
                children: [
                  for (final (folder, label) in [
                    ('', l10n.allProjects),
                    for (final f in state.folders) (f, f),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: !state.showingDeleted && state.folder == folder,
                      onSelected: (_) => cubit.showFolder(folder),
                    ),
                  if (state.deletedCount > 0 || state.showingDeleted)
                    ChoiceChip(
                      avatar: const Icon(Icons.delete_outline),
                      label: Text(l10n.recentlyDeleted),
                      selected: state.showingDeleted,
                      onSelected: (_) => cubit.showDeleted(),
                    ),
                ],
              ),
            ),
        ],
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
    final deleted = project.purgeMs != 0;
    final now = DateTime.now();
    final edited = deleted
        ? l10n.daysLeft(
            max(
              1,
              (DateTime.fromMillisecondsSinceEpoch(project.purgeMs.toInt())
                          .difference(now)
                          .inMinutes /
                      Duration.minutesPerDay)
                  .ceil(),
            ),
          )
        : editedLabel(
            l10n,
            locale,
            now,
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
            // A deleted project doesn't open; its menu offers Restore.
            onTap: deleted ? () => _projectActions(context, project) : onTap,
            onLongPress: () => _projectActions(context, project),
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
                        project.name.isEmpty
                            ? l10n.untitledProject
                            : project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        edited,
                        style: text.bodySmall?.copyWith(
                          color: colors.textMuted,
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

/// What the project menu does.
enum _Action { rename, move, storage, delete, restore }

/// The menu of [project]: rename, move to a folder or delete it; Restore once deleted.
Future<void> _projectActions(
  BuildContext context,
  ProjectSummary project,
) async {
  final l10n = AppLocalizations.of(context);
  final cubit = context.read<HomeCubit>();
  final actions = project.purgeMs != 0
      ? {_Action.restore: (Icons.restore, l10n.restoreProject)}
      : {
          _Action.rename: (Icons.edit_outlined, l10n.renameProject),
          _Action.move: (Icons.drive_file_move_outlined, l10n.moveToFolder),
          _Action.storage: (Icons.data_usage, l10n.projectStorage),
          _Action.delete: (Icons.delete_outline, l10n.deleteProject),
        };
  final action = await showModalBottomSheet<_Action>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.projectActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final MapEntry(key: action, value: (icon, label))
              in actions.entries)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, action),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _Action.delete:
      return cubit.delete(project.id);
    case _Action.restore:
      return cubit.restore(project.id);
    case _Action.storage:
      return _showStorage(context, project.id);
    case _Action.rename || _Action.move:
  }
  final rename = action == _Action.rename;
  final text = await showDialog<String>(
    context: context,
    builder: (_) => rename
        ? _TextDialog(
            title: l10n.renameProject,
            label: l10n.projectName,
            initial: project.name,
          )
        : _TextDialog(
            title: l10n.moveToFolder,
            label: l10n.folderName,
            initial: project.folder,
          ),
  );
  if (text == null) return;
  rename ? cubit.rename(project.id, text) : cubit.moveTo(project.id, text);
}

/// The sheet with project [id]'s sizes and Clear cache; follows the cubit's lists, so the
/// sizes update once the engine cleaned.
Future<void> _showStorage(BuildContext context, String id) {
  final cubit = context.read<HomeCubit>();
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _StorageSheet(id: id),
    ),
  );
}

class _StorageSheet extends StatelessWidget {
  const _StorageSheet({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = FramixColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    String size(int bytes) => fileSize(l10n, locale, bytes);
    final project = context.select<HomeCubit, ProjectSummary?>(
      (cubit) => switch (cubit.state) {
        HomeProjects(:final projects) =>
          projects.where((p) => p.id == id).firstOrNull,
        _ => null,
      },
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FramixSpace.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.projectStorage, style: text.titleMedium),
            const SizedBox(height: FramixSpace.s),
            if (project != null) ...[
              _SizeRow(l10n.storageProjectFiles, size(project.bytes.toInt())),
              _SizeRow(l10n.storageCache, size(project.cacheBytes.toInt())),
            ],
            const SizedBox(height: FramixSpace.s),
            Text(
              l10n.storageCacheNote,
              style: text.bodySmall?.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: FramixSpace.m),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: Text(l10n.clearCache),
              onPressed: project == null || project.cacheBytes == 0
                  ? null
                  : () => context.read<HomeCubit>().cleanCache(id),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label with a size at the end.
class _SizeRow extends StatelessWidget {
  const _SizeRow(this.label, this.size);

  final String label;
  final String size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FramixSpace.s / 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(size, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

/// A dialog asking for one line of text; pops it on Save, null on Cancel.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (text) => Navigator.pop(context, text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// The spinner in an icon's place while the engine saves and loads a project; the icon
/// color keeps it visible on the accent New project button.
Widget _progress(BuildContext context) => SmallSpinner(
  label: AppLocalizations.of(context).openingProject,
  iconColor: true,
);
