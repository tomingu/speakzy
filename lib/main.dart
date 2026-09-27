import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/analysis_result_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/waveform_player_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'interval_stage.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpeakzyApp());
}

class SpeakzyApp extends StatelessWidget {
  const SpeakzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speakzy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<File> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordingsFromDisk();
  }

  /// Rebuilds the recordings list by scanning the app's documents directory
  /// instead of trusting whatever in-memory File objects were appended
  /// during this session.
  ///
  /// Bug fix: the old version only ever grew this list via _addRecording()
  /// at save time, and never re-read the folder. That meant (a) the entire
  /// list silently reset to empty on every app restart, and (b) if a
  /// recording was renamed outside the app (e.g. in a file manager), the
  /// stale in-memory File object still pointed at the old, now-nonexistent
  /// path — so Analyze/Play/Share all failed with "file not found" even
  /// though the audio itself was fine under its new name.
  Future<void> _loadRecordingsFromDisk() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(appDir.path);
      if (!await dir.exists()) return;

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.m4a'))
          .cast<File>()
          .toList();

      // Most recently modified first, matching the old "insert(0, ...)" order.
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (mounted) {
        setState(() {
          _recordings
            ..clear()
            ..addAll(files);
        });
      }
    } catch (_) {
      // Best-effort — if the scan fails, keep whatever list we already have
      // rather than wiping it out.
    }
  }

  void _addRecording(File file) {
    setState(() {
      _recordings.insert(0, file);
    });
  }

  Future<void> _deleteRecording(File file) async {
    setState(() {
      _recordings.removeWhere((f) => f.path == file.path);
    });
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup — the recording is already removed from the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bug fix: this used to be a `switch (_currentIndex) { 0 => ..., }`
      // expression, which only ever builds ONE branch's widget at a time.
      // Since the unselected branches are never part of the tree, Flutter
      // disposes their State entirely when you switch away — so leaving the
      // Timer tab silently reset Silent Mode's toggle
      // (and would have cut off an in-progress recording/timer) every time
      // you checked the Recordings or Settings tab. IndexedStack keeps all
      // three screens alive underneath and just hides the inactive ones, so
      // their state survives tab switches.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TimerScreen(onRecordingSaved: _addRecording),
          RecordingsListScreen(recordings: _recordings, onDelete: _deleteRecording),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // Re-scan disk on opening Recordings so a rename/deletion made
          // outside the app (or from another tab) shows up immediately
          // instead of only on the next app cold start.
          if (index == 1) _loadRecordingsFromDisk();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Recordings',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// A bank of past-year style MUET Part 1 individual presentation prompts.
const List<String> kMuetTopicBank = [
  'Describe a time you helped someone and how it made you feel.',
  'Talk about the advantages and disadvantages of social media for teenagers.',
  'Describe your favourite place to relax and explain why.',
  'Discuss the importance of teamwork in the workplace.',
  'Talk about a skill you would like to learn and why it matters to you.',
  'Describe the impact of technology on education.',
  'Discuss the benefits of reading books compared to watching movies.',
  'Talk about your future career plans and how you intend to achieve them.',
  'Describe a memorable trip you have taken.',
  'Discuss the importance of environmental conservation.',
  'Talk about the role of family in personal development.',
  'Describe a challenge you overcame and what you learned from it.',
];

/// Synthesizes a short sine-wave beep as an in-memory 16-bit PCM WAV file,
/// so the app doesn't need to bundle a separate audio asset.
Uint8List _generateBeepWav({
  int sampleRate = 44100,
  double durationSeconds = 0.15,
  double frequency = 880,
  double amplitude = 0.5,
}) {
  final int numSamples = (sampleRate * durationSeconds).round();
  final Int16List samples = Int16List(numSamples);

  final int fadeSamples = max(1, (sampleRate * 0.005).round()); // 5ms fade
  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    double envelope = 1.0;
    if (i < fadeSamples) envelope = i / fadeSamples;
    if (i > numSamples - fadeSamples) {
      envelope = (numSamples - i) / fadeSamples;
    }
    final double sample = amplitude * envelope * sin(2 * pi * frequency * t);
    samples[i] = (sample * 32767).round();
  }

  final int dataSize = samples.lengthInBytes;
  final ByteData header = ByteData(44);
  var o = 0;
  void writeStr(String s) {
    for (final c in s.codeUnits) {
      header.setUint8(o, c);
      o++;
    }
  }

  void writeU32(int v) {
    header.setUint32(o, v, Endian.little);
    o += 4;
  }

  void writeU16(int v) {
    header.setUint16(o, v, Endian.little);
    o += 2;
  }

  writeStr('RIFF');
  writeU32(36 + dataSize);
  writeStr('WAVE');
  writeStr('fmt ');
  writeU32(16);
  writeU16(1); // PCM
  writeU16(1); // mono
  writeU32(sampleRate);
  writeU32(sampleRate * 2); // byte rate
  writeU16(2); // block align
  writeU16(16); // bits per sample
  writeStr('data');
  writeU32(dataSize);

  final Uint8List wav = Uint8List(44 + dataSize);
  wav.setRange(0, 44, header.buffer.asUint8List());
  wav.setRange(44, 44 + dataSize, samples.buffer.asUint8List());
  return wav;
}

class TimerScreen extends StatefulWidget {
  final Function(File) onRecordingSaved;

  const TimerScreen({super.key, required this.onRecordingSaved});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // 15s -> 30s -> 30s -> 30s -> 15s (Total: 120s / 2 Minutes)
  final List<IntervalStage> _stages = kMuetStages;

  static const int totalDuration = 120;
  // Bug fix: this was 60 (1 minute), but MUET Part 1 prep time is 2 minutes.
  static const int prepDuration = 120;

  Timer? _timer;
  int _totalElapsedSeconds = 0;
  bool _isRunning = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _tempAudioPath;
  bool _isRecordingActive = false;

  // --- Interval beep tones (synthesized locally — no bundled asset needed) ---
  final AudioPlayer _beepPlayer = AudioPlayer();
  Uint8List? _stageBeepBytes;
  Uint8List? _hardBeepBytes;

  // --- Silent Mode: mutes the interval beeps. Transition banners and
  // stage titles still show as normal — this only toggles sound.
  bool _silentModeEnabled = false;

  // --- Topic Generator + prep countdown ---
  final Random _random = Random();
  String? _currentTopic;
  bool _isPrepping = false;
  int _prepRemaining = prepDuration;
  Timer? _prepTimer;

  // --- Transition phrase banner ---
  String? _bannerText;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _initBeeps();
  }

  Future<void> _initBeeps() async {
    // Bug fix: these two used to be generated with identical params, so the
    // "hard" start/end buzzer and the "stage transition" cue sounded exactly
    // the same — defeating the point of having two distinct cues. The stage
    // beep is now shorter and softer so it reads as a lighter nudge.
    _stageBeepBytes = _generateBeepWav(
      frequency: 440,
      durationSeconds: 0.3,
      amplitude: 0.6,
    );
    _hardBeepBytes = _generateBeepWav(
      frequency: 660,
      durationSeconds: 0.7,
      amplitude: 1.0,
    );

    try {
      // Must stay compatible with an in-progress mic recording — using
      // .playback on iOS (or forcing speakerphone/audio focus on Android)
      // was hijacking the audio session and cutting the recording short.
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));
    } catch (_) {
      // If the platform/version rejects this context, playback still
      // works with defaults — it just may not duck cleanly.
    }
  }

  Future<void> _playBeep(Uint8List? bytes) async {
    if (bytes == null) return;
    try {
      await _beepPlayer.stop();
      await _beepPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Best-effort — haptic feedback still gives the user a cue if this fails.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _prepTimer?.cancel();
    _bannerTimer?.cancel();
    // Bug fix: if the widget is disposed mid-recording (e.g. the user
    // backgrounds/kills the screen instead of tapping Stop/Save), the mic
    // stream and wakelock were never released. dispose() can't be async, so
    // these are fire-and-forget, but they still run.
    _audioRecorder.stop();
    WakelockPlus.disable();
    _audioRecorder.dispose();
    _beepPlayer.dispose();
    super.dispose();
  }

  // Calculate which stage we are currently in
  int get _currentStageIndex {
    int accumulated = 0;
    for (int i = 0; i < _stages.length; i++) {
      accumulated += _stages[i].durationSeconds;
      if (_totalElapsedSeconds < accumulated) {
        return i;
      }
    }
    return _stages.length - 1;
  }

  // Calculate elapsed seconds inside the active stage
  int get _currentStageElapsedSeconds {
    int accumulated = 0;
    for (int i = 0; i < _stages.length; i++) {
      if (_totalElapsedSeconds < accumulated + _stages[i].durationSeconds) {
        return _totalElapsedSeconds - accumulated;
      }
      accumulated += _stages[i].durationSeconds;
    }
    return _stages.last.durationSeconds;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Returns true if recording actually started. Callers must check this —
  /// previously the timer would start counting down even when the mic
  /// permission was denied, leaving the user with a "recording" that never
  /// had any audio in it.
  Future<bool> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return false;
      if (status.isPermanentlyDenied) {
        await _showPermissionDeniedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is needed to record your presentation.'),
          ),
        );
      }
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    _tempAudioPath =
        '${tempDir.path}/muet_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _tempAudioPath!,
    );
    await WakelockPlus.enable(); // keep screen awake so Android doesn't kill the mic
    if (mounted) setState(() => _isRecordingActive = true);
    return true;
  }

  Future<void> _stopRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    // Bug fix: this was never called after _startRecording()'s
    // WakelockPlus.enable(), so the screen would stay awake forever after
    // the very first recording — even after leaving this screen.
    await WakelockPlus.disable();
    if (mounted) setState(() => _isRecordingActive = false);
  }
  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Microphone access needed'),
        content: const Text(
          'Recording is permanently blocked for this app. Enable microphone '
          'access in your device settings to record practice sessions.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // The hard start/end buzzer always plays under normal conditions — this
  // mirrors the real exam, where the invigilator's bell always sounds.
  // Muted entirely when Silent Mode is on. The haptic pulse still fires
  // either way since it isn't audible to anyone else in the room.
  void _triggerHardBeep() {
    if (!_silentModeEnabled) _playBeep(_hardBeepBytes);
    HapticFeedback.heavyImpact();
  }

  // Intermediate stage-transition beep, muted under Silent Mode.
  void _triggerStageBeep() {
    if (!_silentModeEnabled) {
      _playBeep(_stageBeepBytes);
      HapticFeedback.heavyImpact();
    }
  }

  // Transition banners (the on-screen cue text) always show, even in
  // Silent Mode — only the audio is muted, not the visual cue.
  void _showTransitionBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _bannerText = text);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  // --- Topic generator ---
  void _pickNewTopic() {
    if (_isRunning || _isPrepping) return;
    setState(() {
      _currentTopic = kMuetTopicBank[_random.nextInt(kMuetTopicBank.length)];
      _totalElapsedSeconds = 0;
    });
  }

  void _clearTopic() {
    if (_isRunning || _isPrepping) return;
    setState(() => _currentTopic = null);
  }

  void _startPrep() {
    if (_currentTopic == null || _isRunning || _isPrepping) return;
    setState(() {
      _isPrepping = true;
      _prepRemaining = prepDuration;
    });
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_prepRemaining <= 1) {
        timer.cancel();
        setState(() {
          _isPrepping = false;
          _prepRemaining = 0;
        });
        _triggerHardBeep();
        _startTimer();
      } else {
        setState(() => _prepRemaining--);
      }
    });
  }

  void _cancelPrep() {
    _prepTimer?.cancel();
    setState(() {
      _isPrepping = false;
      _prepRemaining = prepDuration;
    });
  }

  void _startTimer() async {
    if (_isRunning) return;

    if (_totalElapsedSeconds == 0) {
      final started = await _startRecording();
      if (!started) return; // don't run the countdown with no audio being captured
      _triggerHardBeep();
      _showTransitionBanner(_stages.first.transitionPhrase);
    }

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _totalElapsedSeconds++;
      });

      if (_totalElapsedSeconds == totalDuration) {
        // Time's up, but don't cut the student off — let them finish their
        // script. Sound the buzzer once as a heads-up, then keep counting
        // into overtime until they tap Stop/Save themselves.
        _triggerHardBeep();
        return;
      }

      if (_totalElapsedSeconds < totalDuration) {
        // Check if transition to next stage occurred
        int acc = 0;
        for (int i = 0; i < _stages.length; i++) {
          acc += _stages[i].durationSeconds;
          if (_totalElapsedSeconds == acc && _totalElapsedSeconds < totalDuration) {
            _triggerStageBeep();
            final nextStage = _stages[i + 1];
            _showTransitionBanner(nextStage.transitionPhrase);
            break;
          }
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _resetTimer() async {
    if (_totalElapsedSeconds > 0 || _isPrepping) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard this attempt?'),
          content: const Text(
            'This stops the timer and discards the current recording. This can\'t be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    _stopTimer();
    _cancelPrep();
    await _stopRecording();
    // Bug fix: discarding an attempt stopped the recording but left the
    // half-finished temp file sitting in the OS temp dir forever.
    if (_tempAudioPath != null) {
      try {
        final tempFile = File(_tempAudioPath!);
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
      _tempAudioPath = null;
    }
    if (!mounted) return;
    setState(() {
      _totalElapsedSeconds = 0;
      _bannerText = null;
      _currentTopic = null;
    });
  }

  /// The self-assessment checklist shown in [_showRubricThenSave].
  ///
  /// Deliberately mirrors the MUET Part 1 framework the timer itself walks
  /// students through (Introduction → Point 1 → Point 2 → Point 3 →
  /// Conclusion) rather than being a generic "how did that go" checklist —
  /// "Completed all three main points" in particular checks whether the
  /// student actually followed the structure the app just guided them
  /// through, not just whether they talked for two minutes.
  static const List<String> _selfAssessmentChecklist = [
    'Introduced the topic and stated a clear stance',
    'Developed my points with relevant examples',
    'Completed all three main points',
    'Concluded before the final buzzer',
    'Kept hesitations and fillers under control',
  ];

  /// Short verdict shown once the student has ticked their boxes, so the
  /// checklist reads as an actual result rather than a form they filled in
  /// and moved past. Tuned so "good enough to feel encouraging" (4/5) still
  /// nudges toward another attempt, per the app's practice → reflect →
  /// improve loop.
  ({IconData icon, Color color, String message}) _selfAssessmentVerdict(
    int score,
    int total,
  ) {
    if (score == total) {
      return (
        icon: Icons.check_circle,
        color: Colors.green,
        message: 'Excellent — you covered the full framework!',
      );
    }
    if (score >= total - 1) {
      return (
        icon: Icons.check_circle,
        color: Colors.green,
        message: 'Good attempt. Try again to improve your delivery.',
      );
    }
    if (score >= (total / 2).ceil()) {
      return (
        icon: Icons.info,
        color: Colors.amber[800]!,
        message: 'Fair attempt. Review the areas you missed.',
      );
    }
    return (
      icon: Icons.error_outline,
      color: Colors.redAccent,
      message: 'Needs work. Revisit the MUET speaking framework before your next attempt.',
    );
  }

  Future<void> _showRubricThenSave() async {
    _stopTimer();
    await _stopRecording();
    if (!mounted) return;
    final checklist = _selfAssessmentChecklist;
    final checked = List<bool>.filled(checklist.length, false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final score = checked.where((c) => c).length;
          final verdict = _selfAssessmentVerdict(score, checklist.length);

          return AlertDialog(
            title: const Text('Self-Assessment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick check before you save:',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                ...List.generate(checklist.length, (i) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    value: checked[i],
                    title: Text(checklist[i], style: const TextStyle(fontSize: 14)),
                    onChanged: (v) => setDialogState(() => checked[i] = v ?? false),
                  );
                }),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(verdict.icon, color: verdict.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$score/${checklist.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: verdict.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verdict.message,
                        style: TextStyle(fontSize: 13, color: verdict.color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;
    _showSaveDialog();
  }

  Future<void> _showSaveDialog() async {
    // Recording is already stopped by _showRubricThenSave() before this
    // dialog is shown — no need to stop it again here.
    final textController = TextEditingController(
      text: 'MUET_Presentation_${DateTime.now().millisecondsSinceEpoch % 10000}',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Recording'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter recording name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // The recording was already stopped before this dialog opened
              // (see _showRubricThenSave), so Cancel here means "discard
              // it" — clean up the orphaned temp file and reset state so
              // the next Start begins a real new attempt instead of
              // silently inheriting the same broken state as an unsaved
              // successful save would have.
              if (_tempAudioPath != null) {
                try {
                  final tempFile = File(_tempAudioPath!);
                  if (await tempFile.exists()) await tempFile.delete();
                } catch (_) {
                  // Best-effort cleanup.
                }
                _tempAudioPath = null;
              }
              _resetForNextAttempt();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              bool success = false;

              if (_tempAudioPath != null && File(_tempAudioPath!).existsSync()) {
                final appDir = await getApplicationDocumentsDirectory();
                final rawName = textController.text.trim();
                final safeName = rawName.isEmpty
                    ? 'MUET_Presentation_${DateTime.now().millisecondsSinceEpoch % 10000}'
                    : rawName;
                final fileName = '$safeName.m4a';
                final savedFile =
                    await File(_tempAudioPath!).copy('${appDir.path}/$fileName');
                // Bug fix: the temp copy in the OS temp dir was never
                // deleted after being copied to permanent storage, so every
                // saved recording left an orphaned duplicate file behind.
                try {
                  await File(_tempAudioPath!).delete();
                } catch (_) {
                  // Best-effort cleanup — the saved copy already succeeded.
                }
                widget.onRecordingSaved(savedFile);
                success = true;
              }

              if (ctx.mounted) {
                nav.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Recording saved successfully!'
                          : 'No audio was captured — nothing to save.',
                    ),
                  ),
                );
              }

              // Bug fix: this used to be missing entirely, so
              // _totalElapsedSeconds (and the topic/banner) were never reset
              // after a successful save. That silently broke every attempt
              // after the first: _startTimer() only calls _startRecording()
              // (and re-arms beeps/banners/stage tracking) when
              // _totalElapsedSeconds == 0, so attempt 2+ never actually
              // captured audio or replayed the 0-120s stage sequence.
              _resetForNextAttempt();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Clears per-attempt state so the next Start press begins a genuinely
  /// fresh attempt (new recording, timer back at 0, stage tracking re-armed).
  /// Called after a save completes. The recording itself is already stopped
  /// by the time this runs (see _showRubricThenSave), so this only needs to
  /// reset counters/UI state, not touch the recorder.
  void _resetForNextAttempt() {
    if (!mounted) return;
    setState(() {
      _totalElapsedSeconds = 0;
      _bannerText = null;
      _currentTopic = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _stages[_currentStageIndex];
    final stageElapsed = _currentStageElapsedSeconds;
    final remainingTime = totalDuration - _totalElapsedSeconds;
    final intervalDisplay =
        _totalElapsedSeconds == 0 ? '0/5' : '${_currentStageIndex + 1}/5';

      return SafeArea(
      child: Column(
        children: [
          // Scrollable content: Silent Mode row, header card, topic generator, metrics.
          // Wrapped in Expanded + SingleChildScrollView so a growing topic card
          // (e.g. after tapping "New Topic") scrolls instead of overflowing.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header Card with Stage & Primary Interval Clock
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 32, bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                          children: [
                            if (_isRecordingActive)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                                    SizedBox(width: 6),
                                    Text(
                                      'REC',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              _isPrepping ? 'Preparation' : currentStage.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _isPrepping ? _formatTime(_prepRemaining) : _formatTime(stageElapsed),
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                            if (_isPrepping)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'PREP TIME — read your topic',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1),
                                ),
                              ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _bannerText != null && !_isPrepping
                                  ? Padding(
                                      key: ValueKey(_bannerText),
                                      padding: const EdgeInsets.only(top: 10, left: 24, right: 24),
                                      child: Text(
                                        '"${_bannerText!}"',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _silentModeEnabled ? Icons.volume_off : Icons.volume_up,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Silent Mode',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: _silentModeEnabled,
                                        activeColor: Colors.white,
                                        onChanged: (v) => setState(() => _silentModeEnabled = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Topic Generator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('MUET Part 1 Topic', style: TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    if (_currentTopic != null && !_isRunning && !_isPrepping)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: _clearTopic,
                                        tooltip: 'Clear topic',
                                      ),
                                    TextButton.icon(
                                      onPressed: (_isRunning || _isPrepping) ? null : _pickNewTopic,
                                      icon: const Icon(Icons.shuffle, size: 16),
                                      label: const Text('New Topic'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              _currentTopic ?? 'Tap "New Topic" for a random past-year prompt.',
                              style: TextStyle(
                                color: _currentTopic == null ? Colors.grey : Colors.black87,
                              ),
                            ),
                            if (_currentTopic != null && !_isRunning && _totalElapsedSeconds == 0)
                              Align(
                                alignment: Alignment.centerRight,
                                child: _isPrepping
                                    ? TextButton(
                                        onPressed: _cancelPrep,
                                        child: const Text('Cancel Prep'),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: _startPrep,
                                        icon: const Icon(Icons.menu_book, size: 16),
                                        label: const Text('Start Prep (2 min)'),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3-Metric Display Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricColumn('ELAPSED', _formatTime(_totalElapsedSeconds)),
                        _buildMetricColumn('INTERVALS', intervalDisplay),
                        _buildMetricColumn(
                          remainingTime < 0 ? 'OVERTIME' : 'REMAINING',
                          _formatTime(remainingTime.abs()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Start/Stop and Reset Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.deepOrange : Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _isPrepping
                        ? null
                        : (_isRunning
                            ? _stopTimer
                            : (_currentTopic != null && _totalElapsedSeconds == 0
                                ? null // must use "Start Prep" when a topic is loaded
                                : _startTimer)),
                    child: Text(
                      _isRunning ? 'Stop' : 'Start',
                      style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _resetTimer,
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 20, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _totalElapsedSeconds > 0 && !_isPrepping && !_isRunning
                    ? () => _showRubricThenSave()
                    : null,
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }
}

class RecordingsListScreen extends StatefulWidget {
  final List<File> recordings;
  final void Function(File file) onDelete;

  const RecordingsListScreen({
    super.key,
    required this.recordings,
    required this.onDelete,
  });

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String path) async {
    if (_isPlaying && _currentlyPlayingPath == path) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        _currentlyPlayingPath = path;
        _isPlaying = true;
      });
    }
  }

  void _shareFile(String path, BuildContext context) {
    // iPad requires an anchor point for the share sheet (it's a popover
    // there, not a full-screen modal like on iPhone/Android) — without
    // this, sharing silently fails on iPad specifically.
    final box = context.findRenderObject() as RenderBox?;
    Share.shareXFiles(
      [XFile(path)],
      text: 'My MUET Speaking Practice Recording',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Future<void> _confirmDelete(File file, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text('"$displayName" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_currentlyPlayingPath == file.path) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      }
      widget.onDelete(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recordings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: widget.recordings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_none_rounded, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No recordings yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Record and save a presentation from the Timer tab to see it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              itemCount: widget.recordings.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = widget.recordings[index];
                final fileName = file.path.split('/').last.replaceAll('.m4a', '');
                final isCurrent = _currentlyPlayingPath == file.path && _isPlaying;

                return InkWell(
                  // Tapping anywhere on the row (other than the small action
                  // buttons below, which consume their own taps) opens the
                  // waveform player so the student can jump straight to a
                  // specific stage instead of scrubbing blind.
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WaveformPlayerScreen(
                          audioPath: file.path,
                          title: fileName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(isCurrent ? Icons.pause_circle_filled : Icons.play_circle_fill),
                          iconSize: 34,
                          color: isCurrent ? Colors.deepOrange : Theme.of(context).colorScheme.primary,
                          tooltip: isCurrent ? 'Pause' : 'Play',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _togglePlay(file.path),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bug fix: this used to truncate with an
                              // ellipsis (overflow: TextOverflow.ellipsis)
                              // even though "MUET_Pre…" tells the student
                              // nothing useful when every recording shares
                              // that prefix. Letting it wrap shows the full,
                              // distinguishing name instead.
                              Text(
                                fileName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Recorded on: ${File(file.path).lastModifiedSync().toString().substring(0, 16)}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              // Compact action row: smaller icons, tight
                              // spacing, so they read as secondary actions
                              // rather than competing with the row tap.
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _compactIconButton(
                                    icon: Icons.insights,
                                    color: Colors.deepPurple,
                                    tooltip: 'Analyze speech',
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AnalysisResultScreen(
                                            audioPath: file.path,
                                            title: fileName,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  _compactIconButton(
                                    icon: Icons.share,
                                    color: Theme.of(context).colorScheme.primary,
                                    tooltip: 'Share',
                                    onPressed: () => _shareFile(file.path, context),                                  ),
                                  _compactIconButton(
                                    icon: Icons.delete_outline,
                                    color: Colors.redAccent,
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(file, fileName),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _compactIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }
}