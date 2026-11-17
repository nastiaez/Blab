import 'package:flutter/foundation.dart';

/// BLA-23: lower content is one mutually exclusive selection, never a stack.
enum DeepDiveLowerSlot { none, translation, mistake }

class DeepDiveSelection extends ChangeNotifier {
  DeepDiveLowerSlot _slot = DeepDiveLowerSlot.none;
  DeepDiveLowerSlot get slot => _slot;
  int? _mistakeIndex;
  int? get mistakeIndex => _mistakeIndex;
  int _generation = 0;
  bool _closed = false;

  int beginWordSelection() => ++_generation;
  bool accepts(int generation) => !_closed && generation == _generation;

  void toggleTranslation() {
    _slot = _slot == DeepDiveLowerSlot.translation
        ? DeepDiveLowerSlot.none
        : DeepDiveLowerSlot.translation;
    _mistakeIndex = null;
    notifyListeners();
  }

  void selectMistake(int index) {
    ++_generation;
    _slot = DeepDiveLowerSlot.mistake;
    _mistakeIndex = index;
    notifyListeners();
  }

  void clear() {
    ++_generation;
    _slot = DeepDiveLowerSlot.none;
    _mistakeIndex = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    super.dispose();
  }
}
