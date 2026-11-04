# P1-089 plan: Home screen (Projects) with a project library

Status: accepted (2026-11-04), from the user's "Homepage ta add kore dio". Defaults chosen under
the "decide yourself" rule. Scope is the Phase 1 core of "Home: Projects tab" (docs/plan.md,
screen list): New project, project list, open; rename/duplicate/delete, folders, search, sort,
thumbnails, Learn, Settings gear and the light theme stay with their own tasks.

## Today
- The app starts in the editor with an empty project; EnableAutosave exists but the app never
  sends it, so nothing persists between launches.

## Engine contract (protocol 38 -> 39)
```proto
OpenLibrary open_library = 36;   // Command.oneof
ListProjects list_projects = 37; // Command.oneof
ProjectList project_list = 11;   // Event.oneof
message OpenLibrary { string dir = 1; }
message ListProjects {}
message ProjectList { repeated ProjectSummary projects = 1; }
message ProjectSummary { string id = 1; int64 duration = 2; int64 ticks_per_second = 3;
  int64 modified_ms = 4; uint32 clips = 5; }
message OpenProject { string path = 1; string id = 2; }  // id: a library project
```
- OpenLibrary(dir): once at startup; again with the same dir changes nothing, another dir or a
  dir after EnableAutosave is refused. Answers CommandAccepted.
- ListProjects: autosaves the current project first (so its row is fresh), then lists
  `<dir>/<id>.framix`, newest first, as ProjectList. Unreadable files are skipped (logged as
  nothing; never shown). Refused without a library.
- NewProject with a library: autosaves the current project, starts an empty one with a new id;
  it autosaves to `<dir>/<id>.framix` once it differs from empty (no file for untouched
  projects).
- OpenProject{id}: autosaves the current project, opens `<dir>/<id>.framix` and autosaves
  there. Ids are engine-made `[0-9a-z]{1,32}`; anything else is refused (no path traversal).
- Storage port: `ProjectStore::list(dir) -> io::Result<Vec<(PathBuf, SystemTime)>>`.
  ponytail: ListProjects decodes every file for its duration; a summary cache when lists get
  long (OVL-015).

## Platform
- `framix/media` channel gets `projectsDir`: iOS Application Support/projects, Android
  filesDir/projects (created if missing). Same channel as exportDir.

## Dart
- features/home/{bloc/home_cubit.dart, view/home_page.dart}: HomeCubit sends OpenLibrary then
  ListProjects; renders ProjectList; New project / tap open push the editor (TimelinePage)
  with Navigator; on return it lists again.
- FramixApp gets `home` (default HomePage); the editor blocs move above MaterialApp so the
  pushed editor route sees them. Editor tests pass `home: const TimelinePage()`.
- Row: duration and "edited <relative time>" via AppLocalizations (en, bn); empty state text.
- Navigator, not go_router: two screens; go_router comes with deep links.
