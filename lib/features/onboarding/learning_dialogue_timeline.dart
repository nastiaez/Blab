import 'package:flutter/animation.dart';

const learningDialogueCycle = Duration(milliseconds: 7050);

const _learningDialogueArrivalCurve = Cubic(0.16, 1, 0.3, 1);

enum LearningDialoguePhase {
  blankStart,
  outgoingArrival,
  outgoingAuthored,
  shimmer,
  clearing,
  reshaping,
  landing,
  waitingForIncoming,
  incomingArrival,
  waitingForPopup,
  popupOpen,
  popupClosing,
  incomingExit,
  outgoingExit,
  blankEnd,
  reducedMotionFinal,
}

LearningDialoguePhase learningDialoguePhaseAt(
  Duration elapsed, {
  bool reducedMotion = false,
}) {
  if (reducedMotion) return LearningDialoguePhase.reducedMotionFinal;
  final milliseconds =
      elapsed.inMilliseconds % learningDialogueCycle.inMilliseconds;
  if (milliseconds < 250) return LearningDialoguePhase.blankStart;
  if (milliseconds < 410) return LearningDialoguePhase.outgoingArrival;
  if (milliseconds < 760) return LearningDialoguePhase.outgoingAuthored;
  if (milliseconds < 1960) return LearningDialoguePhase.shimmer;
  if (milliseconds < 2080) return LearningDialoguePhase.clearing;
  if (milliseconds < 2230) return LearningDialoguePhase.reshaping;
  if (milliseconds < 2450) return LearningDialoguePhase.landing;
  if (milliseconds < 3250) return LearningDialoguePhase.waitingForIncoming;
  if (milliseconds < 3410) return LearningDialoguePhase.incomingArrival;
  if (milliseconds < 3910) return LearningDialoguePhase.waitingForPopup;
  if (milliseconds < 5710) return LearningDialoguePhase.popupOpen;
  if (milliseconds < 6310) return LearningDialoguePhase.popupClosing;
  if (milliseconds < 6430) return LearningDialoguePhase.incomingExit;
  if (milliseconds < 6550) return LearningDialoguePhase.outgoingExit;
  return LearningDialoguePhase.blankEnd;
}

double learningDialoguePhaseProgress(
  Duration elapsed,
  int startMilliseconds,
  int durationMilliseconds,
) {
  final milliseconds =
      elapsed.inMilliseconds % learningDialogueCycle.inMilliseconds;
  return ((milliseconds - startMilliseconds) / durationMilliseconds).clamp(
    0.0,
    1.0,
  );
}

double learningDialogueArrivalProgress(double progress) =>
    _learningDialogueArrivalCurve.transform(progress.clamp(0.0, 1.0));

double learningDialogueExitProgress(double progress) =>
    1 - learningDialogueArrivalProgress(progress);

double learningDialogueShimmerProgress(Duration elapsed) =>
    1 - learningDialoguePhaseProgress(elapsed, 760, 1700);
