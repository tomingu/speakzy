import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'word_frequency_bank.dart';
import 'academic_vocabulary_bank.dart';
import 'package:flutter/foundation.dart';
/// Result of analyzing a saved practice recording[cite: 6].
class SpeechMetrics {
  final String transcript;
  final int wordCount;
  final Duration audioDuration;
  final double wpm;
  final Map<String, int> fillerCounts;
  final int totalFillers;
  final List<Duration> hesitationPauseTimestamps; // 0.7s–2s
  final List<Duration> longPauseTimestamps; // 2s+
  final List<String> vocabularyHits;

  // Lexical diversity + word-frequency-band stats[cite: 6].
  final int uniqueWordCount;
  final double typeTokenRatio; // unique / total, 0-1
  final double correctedTtr; // unique / sqrt(2*total)
  final double commonWordRatio; // Band A
  final double midWordRatio; // Band B
  final double advancedWordRatio; // Band C

  SpeechMetrics({
    required this.transcript,
    required this.wordCount,
    required this.audioDuration,
    required this.wpm,
    required this.fillerCounts,
    required this.totalFillers,
    required this.hesitationPauseTimestamps,
    required this.longPauseTimestamps,
    required this.vocabularyHits,
    required this.uniqueWordCount,
    required this.typeTokenRatio,
    required this.correctedTtr,
    required this.commonWordRatio,
    required this.midWordRatio,
    required this.advancedWordRatio,
  });

  static const int targetWpmMin = 110;
  static const int targetWpmMax = 140;

  bool get paceInRange => wpm >= targetWpmMin && wpm <= targetWpmMax;

  String get paceLabel {
    if (wpm < 90) return 'Too slow — aim for $targetWpmMin–$targetWpmMax wpm';
    if (wpm < targetWpmMin) return 'A little slow — pick up the pace slightly';
    if (wpm <= targetWpmMax) return 'Great pace!';
    if (wpm <= 160) return 'A little fast — slow down slightly';
    return 'Too fast — slow down and pause between points';
  }

  String get lexicalDiversityLabel {
    if (correctedTtr < 6) return 'Limited range — try varying your word choice more';
    if (correctedTtr < 9) return 'Moderate vocabulary variety';
    return 'Strong vocabulary variety';
  }

  /// Serializes these metrics to a plain JSON-able map so they can be cached
  /// (e.g. in SharedPreferences) and reloaded without re-running on-device
  /// transcription. Durations are stored as millisecond integers since
  /// `Duration` itself isn't directly JSON-encodable.
  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'wordCount': wordCount,
        'audioDurationMs': audioDuration.inMilliseconds,
        'wpm': wpm,
        'fillerCounts': fillerCounts,
        'totalFillers': totalFillers,
        'hesitationPauseTimestampsMs':
            hesitationPauseTimestamps.map((d) => d.inMilliseconds).toList(),
        'longPauseTimestampsMs':
            longPauseTimestamps.map((d) => d.inMilliseconds).toList(),
        'vocabularyHits': vocabularyHits,
        'uniqueWordCount': uniqueWordCount,
        'typeTokenRatio': typeTokenRatio,
        'correctedTtr': correctedTtr,
        'commonWordRatio': commonWordRatio,
        'midWordRatio': midWordRatio,
        'advancedWordRatio': advancedWordRatio,
      };

  /// Rebuilds a [SpeechMetrics] from [toJson]'s output. Throws if the map
  /// is missing required fields or has the wrong shape — callers reading
  /// from a cache should catch that and just fall back to re-analyzing.
  factory SpeechMetrics.fromJson(Map<String, dynamic> json) {
    return SpeechMetrics(
      transcript: json['transcript'] as String,
      wordCount: json['wordCount'] as int,
      audioDuration: Duration(milliseconds: json['audioDurationMs'] as int),
      wpm: (json['wpm'] as num).toDouble(),
      fillerCounts: Map<String, int>.from(json['fillerCounts'] as Map),
      totalFillers: json['totalFillers'] as int,
      hesitationPauseTimestamps: (json['hesitationPauseTimestampsMs'] as List)
          .map((ms) => Duration(milliseconds: ms as int))
          .toList(),
      longPauseTimestamps: (json['longPauseTimestampsMs'] as List)
          .map((ms) => Duration(milliseconds: ms as int))
          .toList(),
      vocabularyHits: List<String>.from(json['vocabularyHits'] as List),
      uniqueWordCount: json['uniqueWordCount'] as int,
      typeTokenRatio: (json['typeTokenRatio'] as num).toDouble(),
      correctedTtr: (json['correctedTtr'] as num).toDouble(),
      commonWordRatio: (json['commonWordRatio'] as num).toDouble(),
      midWordRatio: (json['midWordRatio'] as num).toDouble(),
      advancedWordRatio: (json['advancedWordRatio'] as num).toDouble(),
    );
  }
}

/// Transcribes a recording on-device and derives MUET-relevant speech metrics[cite: 6].
class SpeechAnalysisService {
  static const List<String> fillerWords = [
    'um',
    'uh',
    'erm',
    'uhm',
    'like',
    'you know',
  ];

  // Bug fix / improvement: this used to be a hand-typed ~29-term list
  // living directly on this class, which meant it only ever flagged a
  // narrow slice of B2-C1 language and missed anything equally advanced
  // that just didn't happen to be one of those 29 words (e.g. "albeit",
  // "notwithstanding", "meticulous"). Pulled out to its own file
  // (academic_vocabulary_bank.dart) as a ~200-term bank grouped by
  // rhetorical function (addition, contrast, cause/effect, stance,
  // emphasis, sequencing, hedging, conclusion) plus academic
  // adjectives/verbs/nouns, so "vocabulary range" actually reflects range
  // rather than luck-of-the-draw overlap with a short list.
  static const Set<String> vocabularyBank = kAcademicVocabularyBank;

  static const Duration longPauseThreshold = Duration(seconds: 2);
  static const Duration hesitationPauseThreshold = Duration(milliseconds: 700);

  Future<SpeechMetrics> analyze(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
    void Function(int percent)? onProgress,
  }) async {
    if (!await File(audioPath).exists()) {
      throw SpeechAnalysisException(
        'Recording file not found at $audioPath. It may have been deleted.',
      );
    }

    final duration = await _getAudioDuration(audioPath);

     if (duration.inMilliseconds < 500) {
      throw SpeechAnalysisException(
        'Recording is empty or too short (${duration.inMilliseconds}ms). '
        'Check that the microphone actually captured audio.',
      );
    }

    final controller = WhisperController();

    // Bug fix: transcribe() auto-downloads the model on first use, but if
    // that download fails partway (flaky connection, low battery throttling
    // network, etc.) it can come back as a plain `null` result instead of
    // throwing — which is indistinguishable from every other failure mode
    // and gives the user no actionable signal. Downloading explicitly first
    // means a failed/interrupted download surfaces here, with a real error
    // message, before we ever get to the ambiguous null-result case below.
    try {
      await controller.downloadModel(model);
    } catch (e, st) {
      debugPrint('Whisper downloadModel() threw: $e\n$st');
      throw SpeechAnalysisException(
        'Could not download the on-device speech model: $e\n\n'
        'This only needs to happen once — make sure you have an internet '
        'connection and try again.',
      );
    }

    dynamic result;
    try {
      result = await controller.transcribe(
        model: model,
        audioPath: audioPath,
        lang: 'en',
        withSegments: true,
        splitOnWord: true,
        onProgress: onProgress,
      );
    } catch (e, st) {
      // This surfaces the ACTUAL root cause (corrupt/missing audio file,
      // native crash, etc.) instead of a generic message.
      debugPrint('Whisper transcribe() threw: $e\n$st');
      throw SpeechAnalysisException(
        'Transcription failed: $e\n\n'
        'Common causes: the Whisper model file failed to download on '
        'first use (needs internet once), the audio file is missing or '
        'unreadable, or the device is low on storage.',
      );
    }

    if (result == null) {
      throw SpeechAnalysisException(
        'Transcription engine returned no result (no exception thrown). '
        'This usually means the on-device Whisper model file is missing '
        'or was only partially downloaded. Try again with an internet '
        'connection so the model can (re)download, then retry offline.',
      );
    }

    // Bug fix: `result` is `dynamic`, so `result.transcription.text` was
    // also inferred as `dynamic`. Chaining `.split(...).where((w) => ...)`
    // on a dynamic value made Dart infer the closure as `bool
    // Function(dynamic)`, which the real `Iterable<String>.where()` (which
    // needs `bool Function(String)`) rejects at runtime with:
    // "type '(dynamic) => bool' is not a subtype of type '(String) =>
    // bool' of 'test'". Casting to a real String here fixes the whole
    // downstream chain's static types.
    final Object? rawText = result.transcription.text;
    if (rawText is! String) {
      throw SpeechAnalysisException(
        'Unexpected transcription result shape: transcription.text was '
        '${rawText.runtimeType}, not a String.',
      );
    }
    final String transcript = rawText.trim();
    final words =
        transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    final minutes = duration.inMilliseconds / 60000.0;
    final wpm = minutes > 0 ? wordCount / minutes : 0.0;

    final fillerCounts = <String, int>{};
    for (final filler in fillerWords) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(filler) + r'\b', caseSensitive: false);
      final count = pattern.allMatches(transcript).length;
      if (count > 0) fillerCounts[filler] = count;
    }
    final totalFillers = fillerCounts.values.fold<int>(0, (a, b) => a + b);

    // Bug fix: this used to only populate `longPauses` (2s+) and the
    // hesitation tier (0.7-2s) was hardcoded to an empty list below despite
    // being documented on SpeechMetrics — so hesitation pauses were never
    // detected at all, and even the 2s+ tier missed a pause before the
    // speaker started talking (the loop only ever looked at gaps *between*
    // existing segments, never before the first one).
    final hesitationPauses = <Duration>[];
    final longPauses = <Duration>[];
    final segments = result?.transcription.segments ?? [];

    if (segments.isNotEmpty) {
      final Duration leadIn = segments.first.fromTs;
      if (leadIn >= longPauseThreshold) {
        longPauses.add(Duration.zero);
      } else if (leadIn >= hesitationPauseThreshold) {
        hesitationPauses.add(Duration.zero);
      }
    }

    for (int i = 0; i < segments.length - 1; i++) {
      final gap = segments[i + 1].fromTs - segments[i].toTs;
      if (gap >= longPauseThreshold) {
        longPauses.add(segments[i].toTs);
      } else if (gap >= hesitationPauseThreshold) {
        hesitationPauses.add(segments[i].toTs);
      }
    }

    final vocabHits = <String>[];
    for (final term in vocabularyBank) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(transcript)) vocabHits.add(term);
    }

    final lexicalStats = _computeLexicalStats(transcript);

    return SpeechMetrics(
      transcript: transcript,
      wordCount: wordCount,
      audioDuration: duration,
      wpm: wpm,
      fillerCounts: fillerCounts,
      totalFillers: totalFillers,
      longPauseTimestamps: longPauses,
      vocabularyHits: vocabHits,
      uniqueWordCount: lexicalStats.uniqueWordCount,
      typeTokenRatio: lexicalStats.typeTokenRatio,
      correctedTtr: lexicalStats.correctedTtr,
      commonWordRatio: lexicalStats.commonWordRatio,
      midWordRatio: lexicalStats.midWordRatio,
      advancedWordRatio: lexicalStats.advancedWordRatio,
      hesitationPauseTimestamps: hesitationPauses,
    );
  }

  _LexicalStats _computeLexicalStats(String transcript) {
    final cleaned = transcript
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z' ]"), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    final total = cleaned.length;
    if (total == 0) {
      return _LexicalStats(
        uniqueWordCount: 0,
        typeTokenRatio: 0,
        correctedTtr: 0,
        commonWordRatio: 0,
        midWordRatio: 0,
        advancedWordRatio: 0,
      );
    }

    final uniqueWords = cleaned.toSet();
    final ttr = uniqueWords.length / total;
    final cttr = uniqueWords.length / sqrt(2 * total);

    int bandA = 0;
    int bandB = 0;
    int bandC = 0;
    for (final w in cleaned) {
      if (kCommonWordBank.contains(w)) {
        bandA++;
      } else if (w.length <= 6) {
        bandB++;
      } else {
        bandC++;
      }
    }

    return _LexicalStats(
      uniqueWordCount: uniqueWords.length,
      typeTokenRatio: ttr,
      correctedTtr: cttr,
      commonWordRatio: bandA / total,
      midWordRatio: bandB / total,
      advancedWordRatio: bandC / total,
    );
  }

  Future<Duration> _getAudioDuration(String path) async {
    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(path);
      final d = await player.getDuration();
      return d ?? const Duration(seconds: 120);
    } finally {
      await player.dispose();
    }
  }
}

class SpeechAnalysisException implements Exception {
  final String message;
  SpeechAnalysisException(this.message);
  @override
  String toString() => message;
}

class _LexicalStats {
  final int uniqueWordCount;
  final double typeTokenRatio;
  final double correctedTtr;
  final double commonWordRatio;
  final double midWordRatio;
  final double advancedWordRatio;

  _LexicalStats({
    required this.uniqueWordCount,
    required this.typeTokenRatio,
    required this.correctedTtr,
    required this.commonWordRatio,
    required this.midWordRatio,
    required this.advancedWordRatio,
  });
}