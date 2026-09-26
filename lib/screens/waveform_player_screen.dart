import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../interval_stage.dart';

/// Full-screen playback view for a saved recording: shows the audio
/// waveform (tap or drag anywhere on it to seek) plus a row of bookmark
/// chips for each MUET stage (Introduction, Point 1, Point 2, Point 3,
/// Conclusion) so a student can jump straight to, say, the Conclusion to
/// check their pacing without scrubbing blind.
///
/// Setup required (not included in this file):
///   Add to pubspec.yaml:  audio_waveforms: ^1.1.0
///
/// Bookmarks are derived from the fixed [kMuetStages] timing (15/30/30/30/15s)
/// rather than from anything stored per-recording, since every practice
/// recording follows the same structure. If the recording ran into
/// "overtime" (the student kept talking past 120s, which the timer
/// intentionally allows), the Conclusion bookmark still just seeks to the
/// 105s mark — the extra time is simply available past that point.
class WaveformPlayerScreen extends StatefulWidget {
  final String audioPath;
  final String title;

  const WaveformPlayerScreen({
    super.key,
    required this.audioPath,
    required this.title,
  });

  @override
  State<WaveformPlayerScreen> createState() => _WaveformPlayerScreenState();
}

class _WaveformPlayerScreenState extends State<WaveformPlayerScreen> {
  late final PlayerController _controller;
  bool _isPlaying = false;
  bool _isReady = false;
  String? _error;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = PlayerController();
    _preparePlayer();

    _controller.onCurrentDurationChanged.listen((ms) {
      if (mounted) setState(() => _currentPosition = Duration(milliseconds: ms));
    });

    _controller.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state.isPlaying);
    });

    _controller.onCompletion.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _preparePlayer() async {
    if (!await File(widget.audioPath).exists()) {
      setState(() => _error = 'Recording file not found. It may have been deleted.');
      return;
    }
    try {
      await _controller.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
        noOfSamples: 200,
      );
      final durationMs = await _controller.getDuration(DurationType.max);
      if (!mounted) return;
      setState(() {
        _totalDuration = Duration(milliseconds: durationMs);
        _isReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this recording: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _controller.pausePlayer();
    } else {
      await _controller.startPlayer();
    }
  }

  Future<void> _seekToStage(int startSeconds) async {
    await _controller.seekTo(startSeconds * 1000);
    if (!_isPlaying) {
      await _controller.startPlayer();
    }
  }

  /// Which stage the playhead is currently inside, so its chip can be
  /// highlighted — purely a visual "you are here" cue.
  int _activeStageIndex() {
    final offsets = kMuetStageStartOffsets;
    final currentSeconds = _currentPosition.inSeconds;
    int active = 0;
    for (int i = 0; i < offsets.length; i++) {
      if (currentSeconds >= offsets[i]) active = i;
    }
    return active;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : !_isReady
              ? const Center(child: CircularProgressIndicator())
              : _buildPlayer(context),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final activeIndex = _activeStageIndex();
    final offsets = kMuetStageStartOffsets;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Waveform — tap or drag directly on it to seek.
          AudioFileWaveforms(
            size: Size(MediaQuery.of(context).size.width - 40, 100),
            playerController: _controller,
            enableSeekGesture: true,
            waveformType: WaveformType.long,
            playerWaveStyle: PlayerWaveStyle(
              fixedWaveColor: Colors.grey.shade300,
              liveWaveColor: Theme.of(context).colorScheme.primary,
              spacing: 5,
              showSeekLine: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_currentPosition), style: const TextStyle(color: Colors.grey)),
              Text(_fmt(_totalDuration), style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: IconButton(
              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
              iconSize: 64,
              color: Theme.of(context).colorScheme.primary,
              onPressed: _togglePlay,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Jump to a stage',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(kMuetStages.length, (i) {
              final stage = kMuetStages[i];
              final isActive = i == activeIndex;
              return ChoiceChip(
                label: Text('${stage.title} (${_fmt(Duration(seconds: offsets[i]))})'),
                selected: isActive,
                onSelected: (_) => _seekToStage(offsets[i]),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : Colors.black87,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}