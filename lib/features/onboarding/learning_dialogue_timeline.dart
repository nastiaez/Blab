import 'package:flutter/animation.dart';

const learningDialogueCycle = Duration(milliseconds: 7750);
const learningDialoguePlaybackCycle = Duration(milliseconds: 13750);

// Extend reading holds without slowing the existing message/shimmer motion.
Duration learningDialoguePlaybackElapsed(Duration playback) {
  var time =
      playback.inMilliseconds % learningDialoguePlaybackCycle.inMilliseconds;
  var added = 0;
  for (final hold in const [
    (410, 760, 1500),
    (2450, 3250, 1500),
    (3410, 4610, 1000),
    (4610, 6410, 2000),
  ]) {
    final start = hold.$1 + added;
    final length = hold.$2 - hold.$1 + hold.$3;
    if (time < start) break;
    if (time < start + length) {
      return Duration(
        milliseconds:
            hold.$1 + ((time - start) * (hold.$2 - hold.$1) / length).floor(),
      );
    }
    added += hold.$3;
  }
  return Duration(milliseconds: time - added);
}

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
  if (milliseconds < 4610) return LearningDialoguePhase.waitingForPopup;
  if (milliseconds < 6410) return LearningDialoguePhase.popupOpen;
  if (milliseconds < 7010) return LearningDialoguePhase.popupClosing;
  if (milliseconds < 7130) return LearningDialoguePhase.incomingExit;
  if (milliseconds < 7250) return LearningDialoguePhase.outgoingExit;
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
