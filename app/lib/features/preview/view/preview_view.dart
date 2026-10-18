import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../bloc/preview_cubit.dart';
import 'spike_preview.dart';

/// The engine's preview in a Flutter Texture; frames never pass through Dart. Shows nothing
/// until the engine reports the texture.
class PreviewView extends StatelessWidget {
  const PreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return const SpikePreview(); // SPIKE (P1-001)
    return BlocBuilder<PreviewCubit, int?>(
      builder: (context, textureId) => textureId == null
          ? const SizedBox.shrink()
          : AspectRatio(
              aspectRatio: PreviewCubit.width / PreviewCubit.height,
              child: Texture(textureId: textureId),
            ),
    );
  }
}
