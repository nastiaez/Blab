import 'package:blab/features/onboarding/learning_dialogue_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the approved 7.05 second HTML sequence', () {
    expect(learningDialogueCycle, const Duration(milliseconds: 7050));

    const cases = <(int, LearningDialoguePhase)>[
      (0, LearningDialoguePhase.blankStart),
      (249, LearningDialoguePhase.blankStart),
      (250, LearningDialoguePhase.outgoingArrival),
      (410, LearningDialoguePhase.outgoingAuthored),
      (760, LearningDialoguePhase.shimmer),
      (1960, LearningDialoguePhase.clearing),
      (2080, LearningDialoguePhase.reshaping),
      (2230, LearningDialoguePhase.landing),
      (2450, LearningDialoguePhase.waitingForIncoming),
      (3250, LearningDialoguePhase.incomingArrival),
      (3410, LearningDialoguePhase.waitingForPopup),
      (3910, LearningDialoguePhase.popupOpen),
      (5710, LearningDialoguePhase.popupClosing),
      (6310, LearningDialoguePhase.incomingExit),
      (6430, LearningDialoguePhase.outgoingExit),
      (6550, LearningDialoguePhase.blankEnd),
      (7049, LearningDialoguePhase.blankEnd),
    ];

    for (final scenario in cases) {
      expect(
        learningDialoguePhaseAt(Duration(milliseconds: scenario.$1)),
        scenario.$2,
        reason: '${scenario.$1}ms',
      );
    }
  });

  test('reduced motion always renders the complete teaching state', () {
    expect(
      learningDialoguePhaseAt(Duration.zero, reducedMotion: true),
      LearningDialoguePhase.reducedMotionFinal,
    );
  });

  test('matches the prototype message arrival and exit easing', () {
    expect(learningDialogueArrivalProgress(0), 0);
    expect(learningDialogueArrivalProgress(0.5), closeTo(0.9717, 0.0001));
    expect(learningDialogueArrivalProgress(1), 1);

    expect(learningDialogueExitProgress(0), 1);
    expect(learningDialogueExitProgress(0.5), closeTo(0.0283, 0.0001));
    expect(learningDialogueExitProgress(1), 0);
  });

  test('moves the correction shimmer from right to left', () {
    expect(
      learningDialogueShimmerProgress(const Duration(milliseconds: 760)),
      1,
    );
    expect(
      learningDialogueShimmerProgress(const Duration(milliseconds: 1610)),
      closeTo(0.5, 0.0001),
    );
    expect(
      learningDialogueShimmerProgress(const Duration(milliseconds: 1960)),
      closeTo(0.2941, 0.0001),
    );
  });
}
