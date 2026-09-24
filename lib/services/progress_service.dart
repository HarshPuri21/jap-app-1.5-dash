import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_progress.dart';
import 'data_service.dart';

/// How many never-studied items to introduce per day, on top of whatever
/// is genuinely due for review. Reviews are never capped -- only new-item
/// introduction is -- otherwise day one would dump all ~1,069 items into
/// a single overwhelming queue. 20/day is the same default Anki ships with.
const int kNewItemsPerDay = 20;

/// A stable identity for a vocab word or kanji, used as the progress-map
/// key. Vocab and kanji sometimes share characters (a kanji and a vocab
/// word can both be "食"), so both are prefixed to stay unambiguous.
String vocabItemId(String jp) => 'vocab:$jp';
String kanjiItemId(String kanji) => 'kanji:$kanji';

/// Same identity scheme, extended to kana. Only characters with an
/// unambiguous standalone reading are ever assigned progress (see
/// `DataService.kanaQuizPool`) -- pure combining marks aren't reviewable
/// items on their own.
String kanaItemId(String character) => 'kana:$character';

/// The default number of reviews/day the Daily Progress card measures
/// against, until the user changes it.
const int kDefaultDailyGoal = 15;

/// Rough heuristic behind every "~N min" review-time estimate shown on the
/// Daily Review card and its overview screen. Not a tracked/persisted
/// statistic -- just a friendly approximation so the estimate is at least
/// consistent everywhere it appears.
int estimatedReviewMinutes(int itemCount) => (itemCount * 9 / 60).ceil();

/// Aggregated SRS stats for one learning category (vocab, kanji, hiragana,
/// katakana), used by the Progress Dashboard. `total` is how many items
/// exist in that category at all (studied or not); `studied` is how many
/// have at least one review.
class CategoryProgress {
  final String id;
  final String label;
  final int total;
  final int studied;
  final int dueNow;

  /// Average SM-2 ease across studied items in this category, or null if
  /// nothing has been studied yet. Lower ease roughly means "harder for
  /// this user" -- it's what [ProgressService.weakCategories] sorts by.
  final double? avgEase;
  final int lapses;

  const CategoryProgress({
    required this.id,
    required this.label,
    required this.total,
    required this.studied,
    required this.dueNow,
    required this.avgEase,
    required this.lapses,
  });

  double get fraction => total == 0 ? 0 : studied / total;
}

/// One resolved entry for the Progress Dashboard's "recent activity" list.
class RecentReview {
  final String itemId;
  final DateTime when;
  const RecentReview({required this.itemId, required this.when});
}

class ProgressService extends ChangeNotifier {
  static const _kProgressMap = 'srs_progress_v1';

  /// Per-day review counts ("yyyy-MM-dd" -> count), kept under its own key
  /// in the same SharedPreferences store the rest of the app already uses.
  /// This is what makes the streak, weekly chart and "today" count honest:
  /// [ItemProgress] only remembers the *most recent* review per item, which
  /// isn't enough to reconstruct activity across many days on its own.
  static const _kActivityLog = 'srs_activity_log_v1';
  static const _kDailyGoal = 'srs_daily_goal_v1';

  /// How many days of activity history are kept. Old entries are pruned on
  /// load so the persisted blob can't grow without bound.
  static const int _kActivityLogRetentionDays = 60;

  final Map<String, ItemProgress> _progress = {};
  final Map<String, int> _activityLog = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  int dailyGoal = kDefaultDailyGoal;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProgressMap);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _progress[entry.key] =
              ItemProgress.fromJson(entry.value as Map<String, dynamic>);
        }
      }

      final rawLog = prefs.getString(_kActivityLog);
      if (rawLog != null && rawLog.isNotEmpty) {
        final decoded = jsonDecode(rawLog) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _activityLog[entry.key] = entry.value as int;
        }
        _pruneActivityLog();
      }

      dailyGoal = prefs.getInt(_kDailyGoal) ?? kDefaultDailyGoal;
    } catch (e) {
      // A corrupted or unreadable prefs blob shouldn't take the app down --
      // worst case, progress resets, which is far better than a crash loop.
      debugPrint('ProgressService.load failed, starting fresh: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _progress.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_kProgressMap, encoded);
      await prefs.setString(_kActivityLog, jsonEncode(_activityLog));
    } catch (e) {
      debugPrint('ProgressService.save failed (progress kept in memory): $e');
    }
  }

  void _pruneActivityLog() {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _kActivityLogRetentionDays));
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    _activityLog.removeWhere((key, _) {
      final d = DateTime.tryParse(key);
      return d == null || d.isBefore(cutoffDay);
    });
  }

  String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _hasActivity(DateTime d) => (_activityLog[_dayKey(d)] ?? 0) > 0;

  ItemProgress? progressFor(String itemId) => _progress[itemId];

  bool hasBeenStudied(String itemId) => _progress.containsKey(itemId);

  /// Records a rating for an item, creating its progress record on first
  /// review. Persists immediately -- review volume is human-paced (button
  /// taps), so there's no performance reason to batch writes, and immediate
  /// persistence is what makes "is progress saved reliably" actually true.
  Future<void> rate(String itemId, Rating rating) async {
    final item = _progress[itemId] ?? ItemProgress();
    item.apply(rating);
    _progress[itemId] = item;

    final key = _dayKey(DateTime.now());
    _activityLog[key] = (_activityLog[key] ?? 0) + 1;

    notifyListeners();
    await _save();
  }

  Future<void> setDailyGoal(int value) async {
    final clamped = value.clamp(1, 200).toInt();
    if (dailyGoal == clamped) return;
    dailyGoal = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDailyGoal, dailyGoal);
    } catch (e) {
      debugPrint('ProgressService.setDailyGoal save failed: $e');
    }
  }

  /// All vocab + kanji + (quizzable) kana item IDs currently known to the
  /// app (used to find which ones are "new", i.e. absent from the progress
  /// map).
  List<String> _allItemIds() {
    final ds = DataService.instance;
    return [
      ...ds.vocab.map((v) => vocabItemId(v.jp)),
      ...ds.kanjiEntries.map((k) => kanjiItemId(k.kanji)),
      ...ds.kanaQuizPool('mixed').map((k) => kanaItemId(k.character)),
    ];
  }

  int get dueCount {
    final now = DateTime.now();
    return _progress.values.where((p) => !p.dueDate.isAfter(now)).length;
  }

  int get newAvailableCount {
    final known = _progress.keys.toSet();
    return _allItemIds().where((id) => !known.contains(id)).length;
  }

  /// How many items today's queue will contain, without actually building
  /// (and shuffling) it -- cheap enough to call from the home screen badge.
  int get todayQueueSize {
    final due = dueCount;
    final newAvail = newAvailableCount;
    return due + (newAvail < kNewItemsPerDay ? newAvail : kNewItemsPerDay);
  }

  /// Today's review queue: every item genuinely due, plus up to
  /// [kNewItemsPerDay] never-studied items, shuffled together.
  List<String> buildDailyQueue({int newItemCap = kNewItemsPerDay}) {
    final now = DateTime.now();
    final due = <String>[];
    final fresh = <String>[];

    for (final id in _allItemIds()) {
      final p = _progress[id];
      if (p == null) {
        fresh.add(id);
      } else if (!p.dueDate.isAfter(now)) {
        due.add(id);
      }
    }

    fresh.shuffle();
    final newBatch = fresh.take(newItemCap).toList();
    final queue = [...due, ...newBatch];
    queue.shuffle();
    return queue;
  }

  /// Resolves an item ID back to its displayable vocab/kanji/kana entry.
  /// Returns null if the ID doesn't match anything currently loaded
  /// (defensive -- e.g. app data changed between sessions).
  dynamic resolveItem(String itemId) {
    final ds = DataService.instance;
    if (itemId.startsWith('vocab:')) {
      final jp = itemId.substring('vocab:'.length);
      for (final v in ds.vocab) {
        if (v.jp == jp) return v;
      }
    } else if (itemId.startsWith('kanji:')) {
      final k = itemId.substring('kanji:'.length);
      for (final entry in ds.kanjiEntries) {
        if (entry.kanji == k) return entry;
      }
    } else if (itemId.startsWith('kana:')) {
      final ch = itemId.substring('kana:'.length);
      for (final entry in ds.kana) {
        if (entry.character == ch) return entry;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Daily Progress / Daily Review dashboard support
  // ---------------------------------------------------------------------
  //
  // Everything below is read-only and derived entirely from `_progress`
  // and `_activityLog`, both of which are only ever populated by real
  // reviews (via `rate`). A brand-new install has empty maps, so every
  // value below correctly comes out as zero/empty rather than a
  // placeholder -- there is no separately-invented "demo" data path.

  /// How many reviews were rated today, across every screen that calls
  /// [rate] (Daily Review, Flashcards).
  int get todayCompletedCount => _activityLog[_dayKey(DateTime.now())] ?? 0;

  /// Consecutive days (ending today or yesterday) with at least one
  /// review. A streak doesn't break until a full day passes with zero
  /// activity, so it's still "alive" (shown as yesterday's count) later
  /// today even before you've reviewed anything yet.
  int get currentStreak {
    var day = DateTime.now();
    if (!_hasActivity(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!_hasActivity(day)) return 0;
    }
    var streak = 0;
    while (_hasActivity(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest run of consecutive active days on record (within the
  /// retained activity-log window).
  int get longestStreak {
    if (_activityLog.isEmpty) return 0;
    final days = (_activityLog.entries
            .where((e) => e.value > 0)
            .map((e) => DateTime.tryParse(e.key))
            .whereType<DateTime>()
            .toList()
          ..sort())
        .toList();
    if (days.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      if (gap == 1) {
        current += 1;
      } else if (gap > 1) {
        current = 1;
      }
      if (current > longest) longest = current;
    }
    return longest;
  }

  /// Review counts for the last 7 days (oldest first, today last) -- one
  /// bar per day for a simple weekly-activity chart.
  List<int> get last7DaysActivity {
    final now = DateTime.now();
    return List<int>.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return _activityLog[_dayKey(d)] ?? 0;
    });
  }

  /// Per-category SRS stats (Vocabulary, Kanji, Hiragana, Katakana).
  /// Sentences and Radicals aren't in this list because they aren't part
  /// of the spaced-repetition system yet -- they have their own
  /// standalone quiz/test modes instead (see README).
  List<CategoryProgress> get categoryBreakdown {
    final ds = DataService.instance;
    final now = DateTime.now();

    CategoryProgress build(String id, String label, List<String> ids) {
      var studied = 0;
      var due = 0;
      var lapses = 0;
      var easeSum = 0.0;
      for (final itemId in ids) {
        final p = _progress[itemId];
        if (p == null) continue;
        studied += 1;
        lapses += p.lapses;
        easeSum += p.ease;
        if (!p.dueDate.isAfter(now)) due += 1;
      }
      return CategoryProgress(
        id: id,
        label: label,
        total: ids.length,
        studied: studied,
        dueNow: due,
        avgEase: studied == 0 ? null : easeSum / studied,
        lapses: lapses,
      );
    }

    return [
      build('vocab', 'Vocabulary',
          ds.vocab.map((v) => vocabItemId(v.jp)).toList()),
      build('kanji', 'Kanji',
          ds.kanjiEntries.map((k) => kanjiItemId(k.kanji)).toList()),
      build(
          'hiragana',
          'Hiragana',
          ds
              .kanaQuizPool('hiragana')
              .map((k) => kanaItemId(k.character))
              .toList()),
      build(
          'katakana',
          'Katakana',
          ds
              .kanaQuizPool('katakana')
              .map((k) => kanaItemId(k.character))
              .toList()),
    ];
  }

  /// Studied categories, worst-first by average ease (lower ease = this
  /// user finds it harder), restricted to categories with enough reviews
  /// for the average to mean something. Empty until there's enough data --
  /// the dashboard shows an explanatory empty state in that case rather
  /// than a guess.
  List<CategoryProgress> get weakCategories {
    final withData =
        categoryBreakdown.where((c) => c.studied >= 3).toList();
    withData.sort((a, b) => a.avgEase!.compareTo(b.avgEase!));
    return withData;
  }

  /// The most recently reviewed items, newest first.
  List<RecentReview> get recentActivity {
    final list = _progress.entries
        .where((e) => e.value.lastReviewed != null)
        .map((e) =>
            RecentReview(itemId: e.key, when: e.value.lastReviewed!))
        .toList();
    list.sort((a, b) => b.when.compareTo(a.when));
    return list.take(8).toList();
  }
}
