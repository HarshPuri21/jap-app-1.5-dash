import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/audio_service.dart';
import '../services/data_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'kana_detail_screen.dart';

/// Browses one script (Hiragana or Katakana), grouped into the same stages
/// used throughout the Kana section: Basic 46, Dakuten, Handakuten, Yōon,
/// Small & Special, and (Katakana only) Extended Katakana.
class KanaListScreen extends StatefulWidget {
  final String type; // 'hiragana' | 'katakana'
  const KanaListScreen({super.key, required this.type});

  @override
  State<KanaListScreen> createState() => _KanaListScreenState();
}

class _KanaListScreenState extends State<KanaListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  void _openDetail(KanaEntry k) {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context)
        .push(themedRoute(context, (_) => KanaDetailScreen(kana: k)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final grouped = DataService.instance.kanaGroupedByType(widget.type);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final section = grouped[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: t.spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ThemedSectionLabel(kanaGroupLabel(section.key)),
                          Wrap(
                            spacing: t.spacing.xs,
                            runSpacing: t.spacing.xs,
                            children: section.value
                                .map((k) => _KanaTile(
                                      kana: k,
                                      onTap: () => _openDetail(k),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isHiragana = widget.type == 'hiragana';
    return ThemedAppBar(
      title: isHiragana ? 'Hiragana' : 'Katakana',
      subtitle: isHiragana ? 'ひらがな' : 'カタカナ',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

/// One character in the browse grid: big glyph, small romaji underneath.
class _KanaTile extends StatelessWidget {
  final KanaEntry kana;
  final VoidCallback onTap;

  const _KanaTile({required this.kana, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedCard(
      onTap: onTap,
      level: SurfaceLevel.standard,
      radius: t.radii.sm,
      // Many of these render on one screen, so keep the cheap path.
      allowHeavyEffects: false,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs + 2,
      ),
      semanticLabel: '${kana.character}, ${kana.romaji}',
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kana.character,
              textAlign: TextAlign.center,
              style: t.text.jp(24, weight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              kana.romaji,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.text.caption.copyWith(color: t.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
