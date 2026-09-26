/// One segment of the fixed MUET Part 1 structure (e.g. "Point 2", 30s).
class IntervalStage {
  final String title;
  final int durationSeconds;
  final String transitionPhrase;

  IntervalStage({
    required this.title,
    required this.durationSeconds,
    required this.transitionPhrase,
  });
}

/// The fixed 15/30/30/30/15s MUET Part 1 structure (2 minutes total).
///
/// Pulled out to its own file (rather than living on _TimerScreenState) so
/// both the timer screen and the recordings waveform/bookmark view can
/// share one source of truth for "where does Point 2 / the Conclusion
/// start" instead of duplicating the stage list and risking it drifting
/// out of sync.
final List<IntervalStage> kMuetStages = [
  IntervalStage(
    title: 'Introduction',
    durationSeconds: 15,
    transitionPhrase: 'Good day. I would like to talk about...',
  ),
  IntervalStage(
    title: 'Point 1',
    durationSeconds: 30,
    transitionPhrase: "Let's start with my first point...",
  ),
  IntervalStage(
    title: 'Point 2',
    durationSeconds: 30,
    transitionPhrase: 'Moving on to my next point...',
  ),
  IntervalStage(
    title: 'Point 3',
    durationSeconds: 30,
    transitionPhrase: 'Another important point to consider is...',
  ),
  IntervalStage(
    title: 'Conclusion',
    durationSeconds: 15,
    transitionPhrase: 'To conclude my presentation...',
  ),
];

/// Cumulative start-time offset (in seconds, from the beginning of the
/// recording) for each stage in [kMuetStages] — i.e. bookmark positions.
List<int> get kMuetStageStartOffsets {
  final offsets = <int>[];
  int acc = 0;
  for (final stage in kMuetStages) {
    offsets.add(acc);
    acc += stage.durationSeconds;
  }
  return offsets;
}