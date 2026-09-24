import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/option_button.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

enum _Direction { kanaToRomaji, romajiToKana }

/// One generated quiz question. Unlike Kanji/Radical/Sentence questions,
/// these aren't pre-built in a data file -- there's no meaningful "wrong
/// answer" set to author by hand for 250+ kana, so they're drawn fresh
/// from `DataService.kanaQuizPool` each time the quiz (re)loads.
class _KanaQuizQuestion {
  final KanaEntry kana;
  final _Direction direction;
  final String prompt;
  final List<String> options;
  final String answer;

  _KanaQuizQuestion({
    required this.kana,
    required this.direction,
    required this.prompt,
    required this.options,
    required this.answer,
  });
}

class KanaQuizScreen extends StatefulWidget {
  const KanaQuizScreen({super.key});

  @override
  State<KanaQuizScreen> createState() => _KanaQuizScreenState();
}

class _KanaQuizScreenState extends State<KanaQuizScreen> {
  final Random _rand = Random();

  String _type = 'mixed'; // hiragana | katakana | mixed
  String _direction = 'mixed'; // kanaToRomaji | romajiToKana | mixed

  late List<_KanaQuizQuestion> _deck;
  int _index = 0;
  String? _selected;
  int _score = 0;
  int _answered = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    context.read<AudioService>().stopMenuMusic();
  }

  void _reload() {
    _deck = _buildDeck();
    _index = 0;
    _selected = null;
    _score = 0;
    _answered = 0;
  }

  List<_KanaQuizQuestion> _buildDeck() {
    final pool = DataService.instance.kanaQuizPool(_type);
    final targets = List<KanaEntry>.from(pool)..shuffle(_rand);
    return targets.map((k) => _makeQuestion(k, pool)).toList();
  }

  _KanaQuizQuestion _makeQuestion(KanaEntry target, List<KanaEntry> pool) {
    final direction = _direction == 'mixed'
        ? (_rand.nextBool() ? _Direction.kanaToRomaji : _Direction.romajiToKana)
        : (_direction == 'kanaToRomaji'
            ? _Direction.kanaToRomaji
            : _Direction.romajiToKana);

    // Distractors must not share the target's romaji reading -- otherwise
    // a "wrong" option could be a legitimately correct answer too (this
    // matters most when mixing scripts: か and カ are different answers
    // that both mean "ka").
    final candidates = pool
        .where((e) =>
            e.character != target.character &&
            e.romaji.toLowerCase() != target.romaji.toLowerCase())
        .toList()
      ..shuffle(_rand);
    final distractors = candidates.take(3).toList();
    final entries = [target, ...distractors]..shuffle(_rand);

    if (direction == _Direction.kanaToRomaji) {
      return _KanaQuizQuestion(
        kana: target,
        direction: direction,
        prompt: target.character,
        options: entries.map((e) => e.romaji).toList(),
        answer: target.romaji,
      );
    }
    return _KanaQuizQuestion(
      kana: target,
      direction: direction,
      prompt: target.romaji,
      options: entries.map((e) => e.character).toList(),
      answer: target.character,
    );
  }

  _KanaQuizQuestion get _current => _deck[_index];

  void _choose(String option) {
    if (_selected != null) return;
    final correct = option == _current.answer;
    setState(() {
      _selected = option;
      _answered += 1;
      if (correct) _score += 1;
    });
    final audio = context.read<AudioService>();
    if (correct) {
      audio.playLessonClick();
    } else {
      audio.playError();
    }
    context.read<SettingsService>().recordAnswer(correct: correct);
  }

  void _next() {
    context.read<AudioService>().playLessonClick();
    setState(() {
      if (_index < _deck.length - 1) {
        _index += 1;
      } else {
        _deck = _buildDeck();
        _index = 0;
      }
      _selected = null;
    });
  }

  void _setType(String v) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _type = v;
      _reload();
    });
  }

  void _setDirection(String v) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _direction = v;
      _reload();
    });
  }

  OptionState _stateFor(String option) {
    if (_selected == null) return OptionState.idle;
    if (option == _current.answer) return OptionState.selectedCorrect;
    if (option == _selected) return OptionState.selectedWrong;
    return OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_deck.isEmpty) {
      return Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No kana available for this combination.',
                        textAlign: TextAlign.center,
                        style: t.text.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _current;
    final showKanaGlyph = q.direction == _Direction.kanaToRomaji;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -200) _next();
            },
            child: Column(
              children: [
                _buildAppBar(context),
                _buildFilterChips(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      t.spacing.gutter,
                      t.spacing.xs,
                      t.spacing.gutter,
                      t.spacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ThemedReveal(
                          key: ValueKey<int>(_index),
                          moment: ThemeMoment.radicalReveal,
                          child: ThemedSurface(
                            level: SurfaceLevel.elevated,
                            radius: t.radii.lg,
                            padding: EdgeInsets.all(t.spacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _DirectionBadge(direction: q.direction),
                                    Text(
                                      '${_index + 1} / ${_deck.length}',
                                      style: t.text.caption,
                                    ),
                                  ],
                                ),
                                SizedBox(height: t.spacing.md),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    q.prompt,
                                    textAlign: TextAlign.center,
                                    style: showKanaGlyph
                                        ? t.text
                                            .jp(88, weight: FontWeight.w700)
                                        : t.text.display.copyWith(
                                            fontSize: 44,
                                            fontWeight: FontWeight.w800,
                                          ),
                                  ),
                                ),
                                SizedBox(height: t.spacing.xs),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: t.spacing.lg),
                        ...q.options.map(
                          (opt) => Padding(
                            padding: EdgeInsets.only(bottom: t.spacing.sm),
                            child: OptionButton(
                              text: opt,
                              state: _stateFor(opt),
                              useJpFont: !showKanaGlyph,
                              onTap: () => _choose(opt),
                            ),
                          ),
                        ),
                        if (_selected != null) ...[
                          ThemedReveal(
                            moment: _selected == q.answer
                                ? ThemeMoment.success
                                : ThemeMoment.error,
                            tint: _selected == q.answer
                                ? t.colors.good
                                : t.colors.bad,
                            child: _buildFeedback(context, q),
                          ),
                          if (q.kana.notes != null) ...[
                            SizedBox(height: t.spacing.sm),
                            ThemedReveal(
                              moment: ThemeMoment.explanationReveal,
                              child: _buildNote(context, q.kana),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, _KanaQuizQuestion q) {
    final t = context.tokens;
    final correct = _selected == q.answer;
    final color = correct ? t.colors.good : t.colors.bad;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: t.radii.sm,
      allowHeavyEffects: false,
      tint: color,
      tintStrength: 0.7,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs + 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              correct
                  ? 'Correct!'
                  : '${q.kana.character} = ${q.kana.romaji} — correct answer highlighted',
              style: t.text.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(BuildContext context, KanaEntry k) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GOOD TO KNOW', style: t.text.overline),
          SizedBox(height: t.spacing.xs),
          Text(k.notes!, style: t.text.jp(13.5)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Kana Quiz',
      subtitle: '仮名クイズ',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
      trailing: ThemedStatPill(
        text: '$_score/$_answered',
        icon: Icons.military_tech_outlined,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final t = context.tokens;
    const types = [
      ('mixed', 'Mixed'),
      ('hiragana', 'Hiragana'),
      ('katakana', 'Katakana'),
    ];
    const directions = [
      ('mixed', 'Mixed'),
      ('kanaToRomaji', 'Kana → Romaji'),
      ('romajiToKana', 'Romaji → Kana'),
    ];
    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: types.map((o) {
              return Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: o.$2,
                    selected: o.$1 == _type,
                    onTap: () => _setType(o.$1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: t.spacing.xs),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
            children: directions.map((o) {
              return Padding(
                padding: EdgeInsets.only(right: t.spacing.xs),
                child: Center(
                  child: ThemedChip(
                    label: o.$2,
                    selected: o.$1 == _direction,
                    onTap: () => _setDirection(o.$1),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: t.spacing.xs),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.gutter,
        t.spacing.xs,
        t.spacing.gutter,
        t.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: ThemedButton(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              variant: ThemedButtonVariant.secondary,
              onPressed: _next,
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: ThemedButton(
              label: 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed: _selected == null ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing which direction the current question quizzes --
/// stands in for the difficulty badge other quizzes use, since kana
/// doesn't have a difficulty rating.
class _DirectionBadge extends StatelessWidget {
  final _Direction direction;
  const _DirectionBadge({required this.direction});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = direction == _Direction.kanaToRomaji
        ? 'Kana → Romaji'
        : 'Romaji → Kana';
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: t.colors.accent,
      tintStrength: 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: t.text.caption.copyWith(
          color: t.colors.accent,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
