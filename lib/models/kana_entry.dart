/// A single Hiragana or Katakana character, with everything needed to
/// browse, display and quiz it.
///
/// Covers the full modern kana set: the basic 46, dakuten, handakuten,
/// yōon (contracted sounds), small/special kana, and the common extended
/// katakana combinations used for loanwords. Historical/obsolete kana are
/// intentionally not part of this set (see the data source notes).
class KanaEntry {
  /// The character itself, e.g. "あ" or "キャ".
  final String character;

  /// Standard Hepburn-style romaji, e.g. "a", "kya". Empty/"—" for marks
  /// that have no sound of their own (the small tsu, っ/ッ).
  final String romaji;

  /// A short pronunciation/description string. For most entries this
  /// matches [romaji]; for small kana and combining marks it explains how
  /// the character is actually used.
  final String sound;

  /// "hiragana" or "katakana".
  final String type;

  /// One of: basic, dakuten, handakuten, yoon, small, special,
  /// extended_katakana.
  final String group;

  /// True for small/combining kana (ぁぃぅぇぉゃゅょっゎ and their
  /// katakana equivalents), which usually modify an adjacent character
  /// rather than standing alone.
  final bool isSmall;

  /// The corresponding character in the *other* kana script (hiragana <->
  /// katakana), when one exists in this data set. Null for entries with no
  /// standard counterpart (e.g. most extended katakana combinations).
  final String? pairedKana;

  /// Optional usage/pronunciation note, e.g. explaining a particle reading
  /// or a historical spelling quirk.
  final String? notes;

  const KanaEntry({
    required this.character,
    required this.romaji,
    required this.sound,
    required this.type,
    required this.group,
    required this.isSmall,
    this.pairedKana,
    this.notes,
  });

  bool get isHiragana => type == 'hiragana';
  bool get isKatakana => type == 'katakana';

  factory KanaEntry.fromJson(Map<String, dynamic> json) {
    return KanaEntry(
      character: json['character'] as String,
      romaji: json['romaji'] as String,
      sound: json['sound'] as String,
      type: json['type'] as String,
      group: json['group'] as String,
      isSmall: json['isSmall'] as bool? ?? false,
      pairedKana: json['pairedKana'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'character': character,
        'romaji': romaji,
        'sound': sound,
        'type': type,
        'group': group,
        'isSmall': isSmall,
        'pairedKana': pairedKana,
        'notes': notes,
      };
}

/// Display metadata for a kana [group], shared by every screen that lists
/// or filters kana by stage so the labels/order stay in one place.
class KanaGroupInfo {
  final String id;
  final String label;
  final String jpLabel;

  const KanaGroupInfo({
    required this.id,
    required this.label,
    required this.jpLabel,
  });
}

/// Recommended learning order (Stage 1 -> Stage 7 in the source material).
const List<KanaGroupInfo> kKanaGroupOrder = [
  KanaGroupInfo(id: 'basic', label: 'Basic 46', jpLabel: '基本'),
  KanaGroupInfo(id: 'dakuten', label: 'Dakuten', jpLabel: '濁点'),
  KanaGroupInfo(id: 'handakuten', label: 'Handakuten', jpLabel: '半濁点'),
  KanaGroupInfo(id: 'yoon', label: 'Yōon', jpLabel: '拗音'),
  KanaGroupInfo(id: 'small', label: 'Small & Special', jpLabel: '特殊'),
  KanaGroupInfo(id: 'special', label: 'Small & Special', jpLabel: '特殊'),
  KanaGroupInfo(
      id: 'extended_katakana', label: 'Extended Katakana', jpLabel: '外来音'),
];

String kanaGroupLabel(String group) {
  for (final g in kKanaGroupOrder) {
    if (g.id == group) return g.label;
  }
  return group;
}
