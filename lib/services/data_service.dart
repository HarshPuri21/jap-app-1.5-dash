import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../models/sentence.dart';
import '../models/kanji_question.dart';
import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../models/radical_entry.dart';
import '../models/radical_question.dart';
import '../models/kana_entry.dart';

/// Loads the precomputed data files (bundled as Flutter assets, built from
/// the exact same tested Python pipeline as the desktop app) once at app
/// startup, and hands out shuffled/filtered views of them.
class DataService {
  static final DataService instance = DataService._internal();
  DataService._internal();

  List<Sentence> sentences = [];
  List<KanjiQuestion> kanjiQuestions = [];
  List<VocabEntry> vocab = [];
  List<KanjiEntry> kanjiEntries = [];
  List<RadicalEntry> radicals = [];
  List<RadicalQuestion> radicalQuestions = [];
  List<KanaEntry> kana = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final sentencesRaw =
        await rootBundle.loadString('assets/data/sentences.json');
    sentences = (jsonDecode(sentencesRaw) as List<dynamic>)
        .map((e) => Sentence.fromJson(e as Map<String, dynamic>))
        .toList();

    final kanjiQRaw =
        await rootBundle.loadString('assets/data/kanji_questions.json');
    kanjiQuestions = (jsonDecode(kanjiQRaw) as List<dynamic>)
        .map((e) => KanjiQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    final vocabRaw = await rootBundle.loadString('assets/data/vocab.json');
    vocab = (jsonDecode(vocabRaw) as List<dynamic>)
        .map((e) => VocabEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final kanjiRaw = await rootBundle.loadString('assets/data/kanji.json');
    kanjiEntries = (jsonDecode(kanjiRaw) as List<dynamic>)
        .map((e) => KanjiEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final radicalsRaw =
        await rootBundle.loadString('assets/data/radicals.json');
    radicals = (jsonDecode(radicalsRaw) as List<dynamic>)
        .map((e) => RadicalEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final radicalQRaw =
        await rootBundle.loadString('assets/data/radical_questions.json');
    radicalQuestions = (jsonDecode(radicalQRaw) as List<dynamic>)
        .map((e) => RadicalQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    final kanaRaw = await rootBundle.loadString('assets/data/kana.json');
    kana = (jsonDecode(kanaRaw) as List<dynamic>)
        .map((e) => KanaEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    _loaded = true;
  }

  List<Sentence> sentencesByDifficulty(String difficulty) {
    if (difficulty == 'all') return sentences;
    return sentences.where((s) => s.difficulty == difficulty).toList();
  }

  List<KanjiQuestion> kanjiByDifficulty(String difficulty) {
    if (difficulty == 'all') return kanjiQuestions;
    return kanjiQuestions.where((k) => k.difficulty == difficulty).toList();
  }

  List<RadicalQuestion> radicalsByDifficulty(String difficulty) {
    if (difficulty == 'all') return radicalQuestions;
    return radicalQuestions.where((r) => r.difficulty == difficulty).toList();
  }

  /// Returns `count` shuffled sentences at the given difficulty (or all
  /// difficulties mixed if `difficulty == 'all'`). `count <= 0` returns the
  /// whole (shuffled) pool.
  List<Sentence> drawSentences(String difficulty, int count) {
    final pool = List<Sentence>.from(sentencesByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  List<KanjiQuestion> drawKanji(String difficulty, int count) {
    final pool = List<KanjiQuestion>.from(kanjiByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  List<RadicalQuestion> drawRadicals(String difficulty, int count) {
    final pool = List<RadicalQuestion>.from(radicalsByDifficulty(difficulty));
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }

  List<KanaEntry> kanaByType(String type) =>
      kana.where((k) => k.type == type).toList();

  /// Looks up a single kana entry by its character. Used to classify a
  /// `kana:<char>` progress-item ID as Hiragana or Katakana.
  KanaEntry? kanaByCharacter(String character) {
    for (final k in kana) {
      if (k.character == character) return k;
    }
    return null;
  }

  /// Kana grouped by [KanaEntry.group], in the app's stage order, for a
  /// given script. Empty groups are omitted.
  List<MapEntry<String, List<KanaEntry>>> kanaGroupedByType(String type) {
    final byType = kanaByType(type);
    final seen = <String>{};
    final result = <MapEntry<String, List<KanaEntry>>>[];
    for (final g in kKanaGroupOrder) {
      if (!seen.add(g.id)) continue; // 'small' and 'special' share a label
      final items = byType.where((k) => k.group == g.id).toList();
      if (items.isNotEmpty) result.add(MapEntry(g.id, items));
    }
    return result;
  }

  /// The pool used by the Kana quiz: every character with an unambiguous,
  /// standalone romaji reading. Pure combining marks (small kana, the
  /// small tsu) are excluded since they don't have a sound of their own to
  /// be quizzed on -- they're still fully browsable in the Kana section.
  List<KanaEntry> kanaQuizPool(String type) {
    final base = type == 'mixed' ? kana : kanaByType(type);
    return base.where((k) => k.group != 'small').toList();
  }

  /// A mixed test pulls from sentences, kanji, and radical questions,
  /// tagging each item by its runtime type so the UI can render any of them.
  List<dynamic> drawMixed(String difficulty, int count) {
    final pool = <dynamic>[
      ...sentencesByDifficulty(difficulty),
      ...kanjiByDifficulty(difficulty),
      ...radicalsByDifficulty(difficulty),
    ];
    pool.shuffle(Random());
    if (count <= 0 || count >= pool.length) return pool;
    return pool.sublist(0, count);
  }
}
