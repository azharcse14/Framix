import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/engine/framix_engine.dart';
import '../../../core/engine/proto/framix/v1/engine.pb.dart';

/// What Home shows.
sealed class HomeState {
  const HomeState();
}

/// The projects folder or the first list is on its way.
final class HomeLoading extends HomeState {
  const HomeLoading();
}

/// There is no projects folder, or the engine refused it.
final class HomeUnavailable extends HomeState {
  const HomeUnavailable();
}

/// The library's projects that the search and folder pick, in the engine's order.
final class HomeProjects extends HomeState {
  const HomeProjects(
    this.projects, {
    this.opening,
    this.recovered = false,
    this.folders = const [],
    this.folder = '',
    this.sort = ProjectSort.PROJECT_SORT_UNSPECIFIED,
    this.filtered = false,
  });

  final List<ProjectSummary> projects;

  /// Every folder that holds a project (ProjectList.folders).
  final List<String> folders;

  /// The folder shown; empty: every project.
  final String folder;

  final ProjectSort sort;

  /// A search or folder narrows [projects], so an empty list means no match.
  final bool filtered;

  /// The engine recovered a project left open by a crash (ProjectList.recovered); set on
  /// that one list only, so Home says once that the work is saved.
  final bool recovered;

  /// What the engine is saving and loading for the editor: [newProjectKey] or a project id.
  final String? opening;

  /// [opening] while a new project is being started (no project id is empty).
  static const newProjectKey = '';
}

/// Mirrors the engine's project library (P1-089); sends commands only.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._engine, this._projectsDir) : super(const HomeLoading()) {
    _events = _engine.events.listen(_onEvent);
    _open();
  }

  final FramixEngine _engine;
  final Future<String?> Function() _projectsDir;
  late final StreamSubscription<Event> _events;

  /// Id of OpenLibrary, whose refusal this cubit shows itself, until its reply.
  int? _library;

  /// Ids of ListProjects not answered yet. ProjectList carries no id, but replies come in
  /// command order, so a ProjectList answers the oldest.
  final List<int> _lists = [];
  bool _opened = false;

  /// The project of the latest TimelineChanged; the engine changes it on every New or Open.
  Int64? _project;

  /// Id of the New or Open whose editor is waiting for the engine, and its answer.
  int? _switching;
  Completer<bool>? _switched;

  /// True from a tap on New or Open until the editor closes ([refresh]).
  bool _busy = false;

  void _onEvent(Event e) {
    if (e.hasTimelineChanged()) {
      final project = e.timelineChanged.project;
      // ponytail: replies come in command order, so the first other project after the
      // command is its own; before any TimelineChanged was seen, the first one counts.
      if (_switching != null && project != _project) _answer(true);
      _project = project;
    }
    if (e.hasProjectList()) {
      if (_lists.isNotEmpty) _lists.removeAt(0);
      _list = e.projectList;
      _emitList(recovered: e.projectList.recovered.isNotEmpty);
    }
    if (e.hasCommandAccepted() &&
        e.commandAccepted.commandId.toInt() == _library) {
      _library = null;
    }
    if (e.hasCommandFailed()) _onFailed(e.commandFailed.commandId.toInt());
  }

  void _onFailed(int id) {
    if (id == _switching) return _answer(false);
    // A refused OpenLibrary or ListProjects: the folder can't be used.
    if (id == _library || _lists.remove(id)) {
      if (id == _library) _library = null;
      emit(const HomeUnavailable());
    }
  }

  void _answer(bool ok) {
    _switched?.complete(ok);
    _switching = null;
    _switched = null;
    _showOpening(null);
    if (!ok) _busy = false;
  }

  /// Asks for the projects folder again after Home showed it unavailable.
  void retry() {
    if (state is! HomeUnavailable) return;
    emit(const HomeLoading());
    _open();
  }

  Future<void> _open() async {
    final dir = await _projectsDir();
    if (isClosed) return;
    if (dir == null) return emit(const HomeUnavailable());
    _library = _engine.send(
      Command(openLibrary: OpenLibrary(dir: dir)),
      reportsFailure: true,
    );
    _opened = true;
    refresh();
  }

  /// Lists the projects again once the editor closed; the engine saves the open one first.
  /// A refused list also shows the generic failure message.
  void refresh() {
    _busy = false;
    _listProjects();
  }

  // ponytail: one ListProjects per keystroke, each decoding every project; debounce once
  // lists grow long (OVL-015).
  void _listProjects() {
    if (!_opened) return;
    final op = ListProjects(sort: _sort, query: _query, folder: _folder);
    _lists.add(_engine.send(Command(listProjects: op)));
  }

  String _query = '';
  String _folder = '';
  ProjectSort _sort = ProjectSort.PROJECT_SORT_UNSPECIFIED;

  /// Lists only projects whose name holds [query] (the engine matches).
  void search(String query) {
    _query = query;
    _listProjects();
  }

  /// Lists the projects in [sort] order.
  void sortBy(ProjectSort sort) {
    _sort = sort;
    _listProjects();
  }

  /// Lists only the projects in [folder]; empty: every project.
  void showFolder(String folder) {
    _folder = folder;
    _listProjects();
  }

  /// Names project [id]; the list follows. A refusal shows the generic failure message.
  void rename(String id, String name) {
    _engine.send(
      Command(
        renameProject: RenameProject(id: id, name: name),
      ),
    );
    _listProjects();
  }

  /// Puts project [id] in [folder] (empty: none), like [rename].
  void moveTo(String id, String folder) {
    _engine.send(
      Command(
        moveProject: MoveProject(id: id, folder: folder),
      ),
    );
    _listProjects();
  }

  /// Starts an empty project; true once the engine switched to it, false if it refused
  /// (the generic failure message shows why) or another tap is still being handled.
  Future<bool> newProject() =>
      _switchTo(Command(newProject: NewProject()), HomeProjects.newProjectKey);

  /// Opens project [id], like [newProject].
  Future<bool> open(String id) =>
      _switchTo(Command(openProject: OpenProject(id: id)), id);

  Future<bool> _switchTo(Command command, String opening) async {
    if (_busy) return false;
    // Send first: if it throws, nothing is left waiting and the next tap still works.
    _switching = _engine.send(command);
    _busy = true;
    _switched = Completer<bool>();
    _showOpening(opening);
    return _switched!.future;
  }

  String? _opening;

  /// The latest ProjectList.
  ProjectList? _list;

  void _showOpening(String? opening) {
    _opening = opening;
    if (state is HomeProjects && !isClosed) _emitList();
  }

  void _emitList({bool recovered = false}) {
    final list = _list;
    if (list == null) return;
    emit(
      HomeProjects(
        list.projects,
        opening: _opening,
        recovered: recovered,
        folders: list.folders,
        // The folder's last project may have left it.
        folder: list.folders.contains(_folder) ? _folder : '',
        sort: _sort,
        filtered: _query.trim().isNotEmpty || _folder.isNotEmpty,
      ),
    );
  }

  @override
  Future<void> close() {
    _events.cancel();
    if (_switched != null) _answer(false);
    return super.close();
  }
}
