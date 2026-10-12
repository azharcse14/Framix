---
paths:
  - "app/**/*.dart"
---
# Dart / Flutter
- UI only: widgets send engine commands through app/lib/core/engine and render state from engine events.
- State classes use freezed; Blocs live with their route (BlocProvider); get_it only for long-lived services (FramixEngine).
- High-frequency state (playhead) in its own Cubit with BlocSelector/buildWhen; scrub events use restartable()/droppable().
- Text via AppLocalizations only; colors, fonts, spacing via theme tokens and FramixColors (docs/design-system.md). No hex literals in widgets.
- Every interactive widget has a Semantics label; touch targets at least 48 dp / 44 pt; no fixed-height text containers (Bangla needs taller lines).
- Use material_ui / cupertino_ui packages for new code (Flutter 3.47).
