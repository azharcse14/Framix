import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter_bloc/flutter_bloc.dart';

/// The clips the user picked on the timeline, by engine clip id. View state only: the clip
/// actions act on them, and ids the timeline no longer has are ignored.
@immutable
class ClipSelection {
  const ClipSelection({this.ids = const {}, this.more = false});

  final Set<int> ids;

  /// "Select more" is on: a tap adds or drops a clip instead of picking only it.
  final bool more;

  bool contains(int clip) => ids.contains(clip);

  @override
  bool operator ==(Object other) =>
      other is ClipSelection && other.more == more && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(more, Object.hashAllUnordered(ids));
}

class ClipSelectionCubit extends Cubit<ClipSelection> {
  ClipSelectionCubit() : super(const ClipSelection());

  /// In select-more mode adds or drops [clip]; otherwise selects only it, or clears the
  /// selection if it is the only one selected.
  void tap(int clip) {
    final ids = state.ids;
    final next = switch (state.more) {
      true when ids.contains(clip) => {...ids}..remove(clip),
      true => {...ids, clip},
      false when ids.length == 1 && ids.contains(clip) => <int>{},
      false => {clip},
    };
    emit(ClipSelection(ids: next, more: state.more));
  }

  /// Turns select-more mode on or off, keeping what is selected.
  void toggleMore() => emit(ClipSelection(ids: state.ids, more: !state.more));

  void clear() => emit(const ClipSelection());
}
