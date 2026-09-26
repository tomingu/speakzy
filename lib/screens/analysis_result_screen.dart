import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_analysis_service.dart';
import '../services/cefr_scoring_service.dart';
import 'settings_screen.dart';

/// Caches the (expensive) on-device transcription/metrics and the
/// (paid, network) CEFR call per recording, keyed by [audioPath].
///
/// Each recording lives at its own file path, so the path itself is a
/// stable, unique cache key — no separate id needed. Entries are read on
/// first load of [AnalysisResultScreen] so revisiting the same recording
/// is instant and doesn't burn another Gemini request; [clear] lets the
/// user force a fresh re-analysis if they want one.
///
/// Setup required (not included in this file):
///   Add to pubspec.yaml:  shared_preferences: ^2.2.0  (already a
///   dependency of settings_screen.dart, so likely already present)
class _AnalysisCache {
  static String _metricsKey(String audioPath) => 'analysis_metrics::$audioPath';
  static String _cefrKey(String audioPath) => 'analysis_cefr::$audioPath';

  static Future<SpeechMetrics?> loadMetrics(String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metricsKey(audioPath));
    if (raw == null) return null;
    try {
      return SpeechMetrics.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Shape changed (app update) or the entry is otherwise corrupt —
      // treat it as a cache miss and drop the bad entry rather than
      // crashing the screen.
      await prefs.remove(_metricsKey(audioPath));
      return null;
    }
  }

  static Future<void> saveMetrics(String audioPath, SpeechMetrics metrics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metricsKey(audioPath), jsonEncode(metrics.toJson()));
  }

  static Future<CefrScoreResult?> loadCefr(String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cefrKey(audioPath));
    if (raw == null) return null;
    try {
      return CefrScoreResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_cefrKey(audioPath));
      return null;
    }
  }

  static Future<void> saveCefr(String audioPath, CefrScoreResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cefrKey(audioPath), jsonEncode(result.toJson()));
  }

  /// Wipes both cached entries for this recording (used by "Re-analyze").
  static Future<void> clear(String audioPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_metricsKey(audioPath));
    await prefs.remove(_cefrKey(audioPath));
  }
}

class AnalysisResultScreen extends StatefulWidget {
  final String audioPath;
  final String title;

  const AnalysisResultScreen({
    super.key,
    required this.audioPath,
    required this.title,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final _service = SpeechAnalysisService();
  final _cefrService = CefrScoringService();
  SpeechMetrics? _metrics;
  String? _error;
  int _progress = 0;
  bool _metricsFromCache = false;

  CefrScoreResult? _cefrResult;
  bool _cefrLoading = false;
  String? _cefrError;
  bool _cefrFromCache = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Runs (or re-runs) the analysis pipeline.
  ///
  /// By default this checks the cache first: if we've already transcribed
  /// this exact recording before, reuse those metrics instead of paying
  /// for on-device transcription again, and reuse a cached CEFR verdict
  /// too instead of another Gemini call. Pass [forceRefresh]: true (from
  /// the "Re-analyze" button) to skip the cache and redo everything from
  /// scratch — useful if a previous run looks wrong or the transcription
  /// model has since improved.
  Future<void> _run({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _AnalysisCache.clear(widget.audioPath);
      if (mounted) {
        setState(() {
          _metrics = null;
          _error = null;
          _progress = 0;
          _metricsFromCache = false;
          _cefrResult = null;
          _cefrError = null;
          _cefrFromCache = false;
        });
      }
    } else {
      final cached = await _AnalysisCache.loadMetrics(widget.audioPath);
      if (cached != null) {
        if (mounted) {
          setState(() {
            _metrics = cached;
            _metricsFromCache = true;
          });
        }
        await _loadCachedCefr();
        return;
      }
    }

    try {
      final metrics = await _service.analyze(
        widget.audioPath,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _metricsFromCache = false;
        });
      }
      await _AnalysisCache.saveMetrics(widget.audioPath, metrics);
      await _loadCachedCefr();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not analyze this recording.\n$e');
      }
    }
  }

  /// Populates [_cefrResult] from cache, if one exists for this recording,
  /// without hitting the Gemini API.
  Future<void> _loadCachedCefr() async {
    final cached = await _AnalysisCache.loadCefr(widget.audioPath);
    if (cached != null && mounted) {
      setState(() {
        _cefrResult = cached;
        _cefrFromCache = true;
      });
    }
  }

  Future<void> _runCefrScoring() async {
    if (_metrics == null) return;
    setState(() {
      _cefrLoading = true;
      _cefrError = null;
      _cefrFromCache = false;
    });
    try {
      final apiKey = await SettingsScreen.loadApiKey();
      final result = await _cefrService.score(
        apiKey: apiKey,
        transcript: _metrics!.transcript,
        wpm: _metrics!.wpm,
        fillerCount: _metrics!.totalFillers,
        longPauseCount: _metrics!.longPauseTimestamps.length,
        lexicalDiversity: _metrics!.correctedTtr,
        advancedWordRatio: _metrics!.advancedWordRatio,
      );
      if (mounted) setState(() => _cefrResult = result);
      await _AnalysisCache.saveCefr(widget.audioPath, result);
    } catch (e) {
      if (mounted) setState(() => _cefrError = e.toString());
    } finally {
      if (mounted) setState(() => _cefrLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analysis: ${widget.title}'),
        actions: [
          if (_metrics != null || _error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-analyze (ignore cached result)',
              onPressed: () => _run(forceRefresh: true),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _metrics == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Transcribing on-device… $_progress%'),
                      const SizedBox(height: 4),
                      const Text(
                        'First run may take longer while the model loads.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _buildResults(_metrics!),
    );
  }

  Widget _buildResults(SpeechMetrics m) {
    final paceColor = m.paceInRange ? Colors.green : Colors.orange;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_metricsFromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Loaded from a previous analysis of this recording.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        _summaryStrip(m, paceColor),
        const SizedBox(height: 16),
        _metricCard(
          title: 'Speaking Pace',
          color: paceColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.wpm.toStringAsFixed(0)} WPM',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: paceColor,
                ),
              ),
              Text(m.paceLabel),
              const SizedBox(height: 4),
              Text(
                'Target range: ${SpeechMetrics.targetWpmMin}–${SpeechMetrics.targetWpmMax} wpm',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        _metricCard(
          title: 'Filler Words',
          color: m.totalFillers == 0 ? Colors.green : Colors.redAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.totalFillers} total',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (m.fillerCounts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.fillerCounts.entries
                      .map((e) => Chip(label: Text('"${e.key}" ×${e.value}')))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        _metricCard(
          title: 'Long Pauses (> 2s)',
          color: m.longPauseTimestamps.isEmpty ? Colors.green : Colors.amber[800]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.longPauseTimestamps.length} detected',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (m.longPauseTimestamps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.longPauseTimestamps
                      .map((t) => Chip(label: Text(_fmt(t))))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        _metricCard(
          title: 'Hesitation Pauses (0.7–2s)',
          color: m.hesitationPauseTimestamps.isEmpty ? Colors.green : Colors.orange,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.hesitationPauseTimestamps.length} detected',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Shorter gaps while searching for a word — not as disruptive as '
                'a long pause, but worth noticing if there are a lot of them.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (m.hesitationPauseTimestamps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.hesitationPauseTimestamps
                      .map((t) => Chip(label: Text(_fmt(t))))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        _metricCard(
          title: 'Vocabulary Range',
          color: Colors.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.vocabularyHits.length} academic/B2-C1 terms used',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (m.vocabularyHits.isEmpty)
                const Text(
                  'Try weaving in transition markers like "furthermore" or "on the other hand".',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.vocabularyHits
                      .map((v) => Chip(
                            backgroundColor: Colors.blue.shade50,
                            label: Text(v),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
        _metricCard(
          title: 'Lexical Diversity & Word Frequency',
          color: Colors.teal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.uniqueWordCount} unique words out of ${m.wordCount}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(m.lexicalDiversityLabel, style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 4),
              Text(
                'Type-token ratio: ${(m.typeTokenRatio * 100).toStringAsFixed(0)}%  •  '
                'Corrected TTR: ${m.correctedTtr.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text('Word frequency bands', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              _bandBar(m),
              const SizedBox(height: 6),
              _bandLegend('Very common', Colors.teal.shade300, m.commonWordRatio),
              _bandLegend('Moderately common', Colors.teal.shade500, m.midWordRatio),
              _bandLegend('Less common / advanced', Colors.teal.shade800, m.advancedWordRatio),
              const SizedBox(height: 8),
              const Text(
                'Heuristic estimate from a short built-in word list, not a calibrated corpus lookup.',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        _metricCard(
          title: 'Transcript',
          color: Colors.grey,
          child: Text(m.transcript.isEmpty ? '(no speech detected)' : m.transcript),
        ),
        _buildCefrSection(m),
      ],
    );
  }

  Widget _buildCefrSection(SpeechMetrics m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CEFR LEVEL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_cefrResult == null && !_cefrLoading)
              ElevatedButton.icon(
                onPressed: m.transcript.trim().isEmpty ? null : _runCefrScoring,
                icon: const Icon(Icons.psychology_outlined, size: 18),
                label: const Text('Get CEFR Level (Gemini)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              ),
            if (_cefrLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Asking Gemini to score this…'),
                  ],
                ),
              ),
            if (_cefrError != null) ...[
              Text(_cefrError!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              TextButton(onPressed: _runCefrScoring, child: const Text('Retry')),
            ],
            if (_cefrResult != null) ...[
              if (_cefrFromCache)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Loaded from a previous CEFR scoring — no new Gemini call made.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              _buildCefrResultBody(_cefrResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCefrResultBody(CefrScoreResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurple),
              ),
              child: Text(
                r.overallLevel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(r.overallSummary)),
          ],
        ),
        const SizedBox(height: 12),
        ...r.dimensionList.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(entry.value.level, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Expanded(
                  child: Text(entry.value.justification, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ),
              ],
            ),
          ),
        ),
        if (r.strengths.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ...r.strengths.map((s) => Text('• $s', style: const TextStyle(fontSize: 13))),
        ],
        if (r.areasToImprove.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Areas to improve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ...r.areasToImprove.map((s) => Text('• $s', style: const TextStyle(fontSize: 13))),
        ],
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _bandBar(SpeechMetrics m) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            Expanded(flex: (m.commonWordRatio * 1000).round().clamp(0, 1000), child: Container(color: Colors.teal.shade300)),
            Expanded(flex: (m.midWordRatio * 1000).round().clamp(0, 1000), child: Container(color: Colors.teal.shade500)),
            Expanded(flex: (m.advancedWordRatio * 1000).round().clamp(1, 1000), child: Container(color: Colors.teal.shade800)),
          ],
        ),
      ),
    );
  }

  Widget _bandLegend(String label, Color color, double ratio) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('${(ratio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryStrip(SpeechMetrics m, Color paceColor) {
    return Row(
      children: [
        Expanded(
          child: _summaryStat(
            icon: Icons.speed,
            value: m.wpm.toStringAsFixed(0),
            label: 'WPM',
            color: paceColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryStat(
            icon: Icons.record_voice_over,
            value: '${m.totalFillers}',
            label: 'Fillers',
            color: m.totalFillers == 0 ? Colors.green : Colors.redAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryStat(
            icon: Icons.pause_circle_outline,
            value: '${m.longPauseTimestamps.length}',
            label: 'Pauses',
            color: m.longPauseTimestamps.isEmpty ? Colors.green : Colors.amber[800]!,
          ),
        ),
      ],
    );
  }

  Widget _summaryStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}