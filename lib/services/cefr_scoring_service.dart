import 'dart:convert';
import 'package:http/http.dart' as http;

class CefrDimensionScore {
  final String level;
  final String justification;

  CefrDimensionScore({required this.level, required this.justification});

  factory CefrDimensionScore.fromJson(Map<String, dynamic> json) {
    return CefrDimensionScore(
      level: json['level'] as String? ?? '?',
      justification: json['justification'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'justification': justification,
      };
}

class CefrScoreResult {
  final String overallLevel;
  final String overallSummary;
  final CefrDimensionScore range;
  final CefrDimensionScore accuracy;
  final CefrDimensionScore fluency;
  final CefrDimensionScore coherence;
  final List<String> strengths;
  final List<String> areasToImprove;

  CefrScoreResult({
    required this.overallLevel,
    required this.overallSummary,
    required this.range,
    required this.accuracy,
    required this.fluency,
    required this.coherence,
    required this.strengths,
    required this.areasToImprove,
  });

  List<MapEntry<String, CefrDimensionScore>> get dimensionList => [
        MapEntry('Range', range),
        MapEntry('Accuracy', accuracy),
        MapEntry('Fluency', fluency),
        MapEntry('Coherence', coherence),
      ];

  /// Mirrors the shape [fromJson] expects (a nested 'dimensions' object),
  /// so this result can be cached (e.g. in SharedPreferences) and reloaded
  /// with `CefrScoreResult.fromJson` later without another Gemini call.
  Map<String, dynamic> toJson() => {
        'overallLevel': overallLevel,
        'overallSummary': overallSummary,
        'dimensions': {
          'range': range.toJson(),
          'accuracy': accuracy.toJson(),
          'fluency': fluency.toJson(),
          'coherence': coherence.toJson(),
        },
        'strengths': strengths,
        'areasToImprove': areasToImprove,
      };

  factory CefrScoreResult.fromJson(Map<String, dynamic> json) {
    final dims = json['dimensions'] as Map<String, dynamic>;
    return CefrScoreResult(
      overallLevel: json['overallLevel'] as String? ?? '?',
      overallSummary: json['overallSummary'] as String? ?? '',
      range: CefrDimensionScore.fromJson(dims['range'] as Map<String, dynamic>),
      accuracy: CefrDimensionScore.fromJson(dims['accuracy'] as Map<String, dynamic>),
      fluency: CefrDimensionScore.fromJson(dims['fluency'] as Map<String, dynamic>),
      coherence: CefrDimensionScore.fromJson(dims['coherence'] as Map<String, dynamic>),
      strengths: List<String>.from(json['strengths'] as List? ?? const []),
      areasToImprove: List<String>.from(json['areasToImprove'] as List? ?? const []),
    );
  }
}

class CefrScoringException implements Exception {
  final String message;
  CefrScoringException(this.message);
  @override
  String toString() => message;
}

/// Sends a presentation transcript to Gemini for CEFR speaking-level scoring.
///
/// Setup required (not included in this file):
/// 1. Add to pubspec.yaml:
///      http: ^1.2.0
/// 2. Get a Gemini API key from https://aistudio.google.com/apikey and enter
///    it in the app's Settings screen (stored via shared_preferences).
///
/// Note on the rubric below: it's my own paraphrase of the Council of
/// Europe's CEFR "Qualitative aspects of spoken language use" table (the
/// official speaking rubric), not a verbatim copy — the original is
/// copyrighted. For the authoritative wording, see:
/// https://www.coe.int/en/web/common-european-framework-reference-languages/table-3-cefr-3.3-common-reference-levels-qualitative-aspects-of-spoken-language-use
///
/// The official rubric also scores "Interaction," which I've deliberately
/// dropped here since a MUET Part 1 presentation is a solo monologue with
/// no interlocutor to interact with.
class CefrScoringService {
  // Bug fix: 'gemini-3.5-flash' is not a real Gemini model id (there is a
  // 'gemini-3.5-transcribe' speech-to-text model, but no matching text/JSON
  // chat model by that name) — every request was 404ing. 'gemini-2.5-flash'
  // is a real, currently-supported model that speaks the same
  // generationConfig.responseSchema JSON-mode shape already used below.
  // Model ids get deprecated over time, so if this starts 404ing again,
  // check https://ai.google.dev/gemini-api/docs/models for the current
  // recommended Flash-tier model.
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''
You are an expert CEFR (Common European Framework of Reference for Languages)
speaking examiner. You will receive the transcript of a 2-minute English oral
presentation from a MUET (Malaysian University English Test) candidate, plus
some automatically measured supporting metrics.

Score the candidate on four dimensions, each on the A1-C2 scale:

RANGE (vocabulary and expressive resources)
- A1: a handful of memorised words/phrases tied to personal facts.
- A2: basic memorised phrases and formulas for everyday needs.
- B1: enough vocabulary for familiar topics (family, work, travel), with some
  hesitation and rewording.
- B2: enough vocabulary to describe things and give opinions on general
  topics clearly, using some complex sentences.
- C1: broad enough vocabulary to express precisely on general, academic or
  professional topics without visibly searching for words.
- C2: flexible enough to rephrase for nuance, emphasis or ambiguity, plus
  natural idiomatic use.

ACCURACY (grammatical correctness)
- A1: only limited, memorised grammar patterns.
- A2: some simple structures used correctly, but frequent basic mistakes.
- B1: reasonably accurate with familiar, predictable patterns.
- B2: good grammatical control; errors rarely confuse meaning and are
  usually self-corrected.
- C1: consistently high accuracy; errors are rare and minor.
- C2: consistent grammatical control even under cognitive load (e.g. while
  planning ahead).

FLUENCY (flow and hesitation)
- A1: very short utterances, constant pausing to search for words.
- A2: understandable but with obvious pauses, false starts, reformulation.
- B1: keeps going despite clear pausing to plan grammar/vocabulary,
  especially in longer stretches.
- B2: fairly even flow; may hesitate searching for a pattern, but few long
  pauses.
- C1: fluent and almost effortless; only a conceptually hard topic disrupts
  the flow.
- C2: spontaneous, natural, colloquial flow; any difficulty is smoothed over
  almost invisibly.

COHERENCE (logical organisation and connectors)
- A1: links words with only "and" or "then".
- A2: links ideas with "and", "but", "because".
- B1: strings a series of short points into a simple linear sequence.
- B2: uses a handful of cohesive devices to connect ideas clearly, though a
  long response may feel a bit disjointed.
- C1: clear, well-structured speech with controlled use of connectors.
- C2: fully coherent discourse using a wide, appropriate range of
  organisational and cohesive devices.

Base your judgment primarily on the transcript's actual vocabulary, grammar,
connectors, and organisation. Use the pace/filler/pause metrics only as
supporting signals for fluency, not as the sole basis. Give an overall CEFR
level that best represents the four dimensions as a whole (not a simple
average) — weight Range and Accuracy more heavily if they diverge sharply
from Fluency/Coherence, the way a human examiner would.

Return only the structured JSON described by the response schema. Keep each
justification to one short sentence.
''';

  static const Map<String, dynamic> _dimensionSchema = {
    'type': 'object',
    'properties': {
      'level': {
        'type': 'string',
        'enum': ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
      },
      'justification': {'type': 'string'},
    },
    'required': ['level', 'justification'],
  };

  static final Map<String, dynamic> _responseSchema = {
    'type': 'object',
    'properties': {
      'overallLevel': {
        'type': 'string',
        'enum': ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
      },
      'overallSummary': {'type': 'string'},
      'dimensions': {
        'type': 'object',
        'properties': {
          'range': _dimensionSchema,
          'accuracy': _dimensionSchema,
          'fluency': _dimensionSchema,
          'coherence': _dimensionSchema,
        },
        'required': ['range', 'accuracy', 'fluency', 'coherence'],
      },
      'strengths': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'areasToImprove': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': [
      'overallLevel',
      'overallSummary',
      'dimensions',
      'strengths',
      'areasToImprove',
    ],
  };

  Future<CefrScoreResult> score({
    required String apiKey,
    required String transcript,
    required double wpm,
    required int fillerCount,
    required int longPauseCount,
    double? lexicalDiversity,
    double? advancedWordRatio,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw CefrScoringException('No Gemini API key set. Add one in Settings.');
    }
    if (transcript.trim().isEmpty) {
      throw CefrScoringException('Transcript is empty — nothing to score.');
    }

    final extraSignals = StringBuffer();
    if (lexicalDiversity != null) {
      extraSignals.writeln(
        '- Lexical diversity (corrected type-token ratio): ${lexicalDiversity.toStringAsFixed(1)}',
      );
    }
    if (advancedWordRatio != null) {
      extraSignals.writeln(
        '- Share of less-common/longer words: ${(advancedWordRatio * 100).toStringAsFixed(0)}%',
      );
    }

    final userText = '''
Transcript:
"""
$transcript
"""

Measured metrics (supporting signals only):
- Speaking pace: ${wpm.toStringAsFixed(0)} words per minute
- Filler words detected: $fillerCount
- Long pauses (>2s): $longPauseCount
$extraSignals''';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userText}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
        'temperature': 0.2,
      },
    });

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      throw CefrScoringException('Network error contacting Gemini: $e');
    }

    if (response.statusCode != 200) {
      throw CefrScoringException(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CefrScoringException('Could not parse Gemini response: $e');
    }

    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw CefrScoringException('Gemini returned no candidates.');
    }

    try {
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      final jsonText = parts.first['text'] as String;
      final resultJson = jsonDecode(jsonText) as Map<String, dynamic>;
      return CefrScoreResult.fromJson(resultJson);
    } catch (e) {
      throw CefrScoringException('Unexpected Gemini response shape: $e');
    }
  }
}