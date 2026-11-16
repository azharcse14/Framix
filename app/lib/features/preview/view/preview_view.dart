import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/preview_cubit.dart';
import 'canvas_gestures.dart';

/// The engine's preview in a Flutter Texture; frames never pass through Dart. Shows nothing
/// until the engine reports the texture.
class PreviewView extends StatelessWidget {
  const PreviewView({super.key, this.editable = true});

  /// Whether gestures on the canvas move and scale clips; false where it is only watched
  /// (the export Result screen).
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreviewCubit, PreviewState>(
      builder: (context, state) => switch (state) {
        PreviewShown(:final textureId) => AspectRatio(
          aspectRatio: PreviewCubit.width / PreviewCubit.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Texture(textureId: textureId),
              if (editable) const CanvasGestures(),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
