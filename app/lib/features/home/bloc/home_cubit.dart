import 'dart:async';

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

/// The library's projects, most recently saved first (the engine's order).
final class HomeProjects extends HomeState {
  const HomeProjects(this.projects);

  final List<ProjectSummary> projects;
}

/// Mirrors the engine's project library (P1-089); sends commands only.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._engine, Future<String?> Function() projectsDir)
    : super(const HomeLoading()) {
    _events = _engine.events.listen((e) {
      if (e.hasProjectList()) emit(HomeProjects(e.projectList.projects));
      // A refused OpenLibrary or ListProjects: the folder can't be used.
      if (e.hasCommandFailed() &&
          _mine.remove(e.commandFailed.commandId.toInt())) {
        emit(const HomeUnavailable());
      }
    });
    _open(projectsDir);
  }

  final FramixEngine _engine;
  late final StreamSubscription<Event> _events;

  /// Ids of library commands whose failure this cubit shows itself.
  final Set<int> _mine = {};
  bool _opened = false;

  Future<void> _open(Future<String?> Function() projectsDir) async {
    final dir = await projectsDir();
    if (isClosed) return;
    if (dir == null) return emit(const HomeUnavailable());
    _sendOwn(Command(openLibrary: OpenLibrary(dir: dir)));
    _opened = true;
    refresh();
  }

  /// Lists the projects again (after the editor closes); the engine saves the open one first.
  void refresh() {
    if (_opened) _sendOwn(Command(listProjects: ListProjects()));
  }

  /// Starts an empty project for the editor.
  void newProject() => _engine.send(Command(newProject: NewProject()));

  /// Opens project [id] for the editor. A refusal shows the generic failure message.
  // ponytail: the editor opens at once, showing the previous project if the open fails;
  // wait for the reply once the engine tags TimelineChanged with its command id.
  void open(String id) =>
      _engine.send(Command(openProject: OpenProject(id: id)));

  void _sendOwn(Command command) =>
      _mine.add(_engine.send(command, reportsFailure: true));

  @override
  Future<void> close() {
    _events.cancel();
    return super.close();
  }
}
