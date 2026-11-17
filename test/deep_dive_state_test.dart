import 'package:blab/features/chat/deep_dive_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translation and mistake replace one another, never stack', () {
    final state = DeepDiveSelection();
    expect(state.slot, DeepDiveLowerSlot.none);
    state.toggleTranslation();
    expect(state.slot, DeepDiveLowerSlot.translation);
    state.selectMistake(2);
    expect(state.slot, DeepDiveLowerSlot.mistake);
    expect(state.mistakeIndex, 2);
    state.toggleTranslation();
    expect(state.slot, DeepDiveLowerSlot.translation);
    expect(state.mistakeIndex, isNull);
    state.toggleTranslation();
    expect(state.slot, DeepDiveLowerSlot.none);
    state.dispose();
  });
  test('rapid selections and navigation reject stale word responses', () {
    final state = DeepDiveSelection();
    final first = state.beginWordSelection();
    final second = state.beginWordSelection();
    expect(state.accepts(first), isFalse);
    expect(state.accepts(second), isTrue);
    state.selectMistake(0);
    expect(state.accepts(second), isFalse);
    final third = state.beginWordSelection();
    state.clear();
    expect(state.accepts(third), isFalse);
    final fourth = state.beginWordSelection();
    state.dispose();
    expect(state.accepts(fourth), isFalse);
  });
}
