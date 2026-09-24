import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

class KanaDetailScreen extends StatelessWidget {
  final KanaEntry kana;
  const KanaDetailScreen({super.key, required this.kana});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final headline = (kana.romaji.isEmpty || kana.romaji == '—')
        ? kana.sound
        : kana.romaji;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The character is the lesson, so it gets the forward
                      // surface and the theme's own reveal -- same treatment
                      // Radical detail gives its character.
                      ThemedReveal(
                        moment: ThemeMoment.radicalReveal,
                        child: ThemedSurface(
                          level: SurfaceLevel.elevated,
                          radius: t.radii.lg,
                          padding: EdgeInsets.all(t.spacing.lg),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  kana.character,
                                  style: t.text.jp(96, weight: FontWeight.w700),
                                ),
                              ),
                              SizedBox(height: t.spacing.md),
                              Text(
                                headline,
                                textAlign: TextAlign.center,
                                style: t.text.display.copyWith(
                                  fontSize: 22,
                                  color: t.colors.accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${kana.isHiragana ? 'Hiragana' : 'Katakana'} · ${kanaGroupLabel(kana.group)}',
                                textAlign: TextAlign.center,
                                style: t.text
                                    .jp(14, color: t.colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: t.spacing.md),
                      if (kana.sound != kana.romaji) ...[
                        _infoCard(
                          context,
                          title: 'PRONUNCIATION',
                          child: Text(kana.sound, style: t.text.body),
                        ),
                        SizedBox(height: t.spacing.sm),
                      ],
                      if (kana.pairedKana != null) ...[
                        _infoCard(
                          context,
                          title: kana.isHiragana
                              ? 'KATAKANA COUNTERPART'
                              : 'HIRAGANA COUNTERPART',
                          child: Row(
                            children: [
                              Text(
                                kana.pairedKana!,
                                style: t.text.jp(34, weight: FontWeight.w700),
                              ),
                              SizedBox(width: t.spacing.sm),
                              Expanded(
                                child: Text(
                                  'Same sound, other script.',
                                  style: t.text.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: t.spacing.sm),
                      ],
                      if (kana.notes != null)
                        _infoCard(
                          context,
                          title: 'NOTE',
                          child: Text(kana.notes!, style: t.text.body),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.text.overline),
          SizedBox(height: t.spacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: kana.character,
      subtitle: kanaGroupLabel(kana.group),
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
