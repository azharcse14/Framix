import 'package:flutter_bloc/flutter_bloc.dart';

/// The clip the user tapped on the timeline, by engine clip id; 0 = none. View state only:
/// the clip actions act on it, and an id the timeline no longer has counts as none.
class ClipSelectionCubit extends Cubit<int> {
  ClipSelectionCubit() : super(0);

  /// Selects [clip], or clears the selection if it is already selected.
  void toggle(int clip) => emit(state == clip ? 0 : clip);

  void clear() => emit(0);
}
