import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../services/data_service.dart';
import '../services/progress_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/mode_card.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import 'kana_list_screen.dart';
import 'kana_quiz_screen.dart';

/// Entry point for the Kana section: browse Hiragana or Katakana (grouped
/// by stage -- basic, dakuten, handakuten, yōon, small/special, and
/// extended katakana for loanwords), or jump straight into the quiz.
class KanaHubScreen extends StatelessWidget {
  const KanaHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    context.read<AudioService>().playMenuClick();
    Navigator.of(context).push(themedRoute(context, (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ds = DataService.instance;
    final progress = context.watch<ProgressService>();
    final byId = {for (final c in progress.categoryBreakdown) c.id: c};

    final hiraganaCount = ds.kanaByType('hiragana').length;
    final katakanaCount = ds.kanaByType('katakana').length;
    final hiraganaStudied = byId['hiragana']?.studied ?? 0;
    final katakanaStudied = byId['katakana']?.studied ?? 0;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  children: [
                    const ThemedSectionLabel('Browse'),
                    ModeCard(
                      icon: Icons.text_fields_rounded,
                      title: 'Hiragana',
                      subtitle:
                          '$hiraganaCount characters — basic, dakuten, yōon & more',
                      trailingLabel:
                          hiraganaStudied > 0 ? '$hiraganaStudied learned' : null,
                      accentColor: t.colors.accent,
                      onTap: () =>
                          _open(context, const KanaListScreen(type: 'hiragana')),
                    ),
                    SizedBox(height: t.spacing.sm),
                    ModeCard(
                      icon: Icons.text_fields_rounded,
                      title: 'Katakana',
                      subtitle:
                          '$katakanaCount characters — basic, dakuten, extended & more',
                      trailingLabel:
                          katakanaStudied > 0 ? '$katakanaStudied learned' : null,
                      accentColor: Color.lerp(t.colors.accent, t.colors.good, 0.5)!,
                      onTap: () =>
                          _open(context, const KanaListScreen(type: 'katakana')),
                    ),
                    SizedBox(height: t.spacing.xl),
                    const ThemedSectionLabel('Practice'),
                    ModeCard(
                      icon: Icons.quiz_outlined,
                      title: 'Kana Quiz',
                      subtitle: 'Kana → Romaji and Romaji → Kana, multiple choice',
                      accentColor: t.colors.warn,
                      onTap: () => _open(context, const KanaQuizScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Hiragana & Katakana',
      subtitle: '仮名',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
