import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/audio_service.dart';
import '../services/data_service.dart';
import '../services/progress_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'daily_review_screen.dart';
import 'flashcard_screen.dart';

/// What's due today, broken down by type, before committing to it -- the
/// "Daily Review" home-screen card opens here rather than dropping
/// straight into a review with no context.
///
/// "Start Review" launches the existing [DailyReviewScreen] flow
/// unchanged; this screen only reads progress, it never rates or
/// schedules anything itself, so there's exactly one review engine.
class ReviewOverviewScreen extends StatelessWidget {
  const ReviewOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = context.watch<ProgressService>();

    // Built once so the hero total, the breakdown and the time estimate
    // all agree with each other -- calling buildDailyQueue() more than
    // once would sample a different random subset of "new" items each
    // time.
    final queue = progress.buildDailyQueue();
    final total = queue.length;
    var dueNow = 0;
    for (final id in queue) {
      if (progress.hasBeenStudied(id)) dueNow += 1;
    }
    final newToday = total - dueNow;
    final completedToday = progress.todayCompletedCount;
    final breakdown = _breakdownByType(queue);
    final estMinutes = estimatedReviewMinutes(total);
    final weak = progress.weakCategories;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: total == 0
                    ? _buildEmptyState(context, completedToday)
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          t.spacing.gutter,
                          t.spacing.xs,
                          t.spacing.gutter,
                          t.spacing.lg,
                        ),
                        children: [
                          _buildHeroStat(
                              context, total, dueNow, newToday, estMinutes),
                          SizedBox(height: t.spacing.lg),
                          const ThemedSectionLabel('Breakdown'),
                          _buildBreakdown(context, breakdown),
                          SizedBox(height: t.spacing.lg),
                          const ThemedSectionLabel('Today'),
                          _buildTodayRow(context, completedToday),
                          if (weak.isNotEmpty) ...[
                            SizedBox(height: t.spacing.lg),
                            const ThemedSectionLabel('Worth extra attention'),
                            _buildWeakTip(context, weak.first),
                          ],
                        ],
                      ),
              ),
              if (total > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    0,
                    t.spacing.gutter,
                    t.spacing.md,
                  ),
                  child: ThemedButton(
                    label: 'Start Review',
                    icon: Icons.bolt_rounded,
                    onPressed: () {
                      context.read<AudioService>().playMenuClick();
                      Navigator.of(context).push(
                        themedRoute(
                            context, (_) => const DailyReviewScreen()),
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

  Map<String, int> _breakdownByType(List<String> queue) {
    final ds = DataService.instance;
    final counts = <String, int>{
      'Vocabulary': 0,
      'Kanji': 0,
      'Hiragana': 0,
      'Katakana': 0,
    };
    for (final id in queue) {
      if (id.startsWith('vocab:')) {
        counts['Vocabulary'] = counts['Vocabulary']! + 1;
      } else if (id.startsWith('kanji:')) {
        counts['Kanji'] = counts['Kanji']! + 1;
      } else if (id.startsWith('kana:')) {
        final ch = id.substring('kana:'.length);
        final entry = ds.kanaByCharacter(ch);
        if (entry != null) {
          final key = entry.isHiragana ? 'Hiragana' : 'Katakana';
          counts[key] = counts[key]! + 1;
        }
      }
    }
    return counts;
  }

  Widget _buildHeroStat(
    BuildContext context,
    int total,
    int dueNow,
    int newToday,
    int estMinutes,
  ) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.lg),
      child: Column(
        children: [
          Icon(Icons.bolt_rounded, color: t.colors.accent, size: 32),
          SizedBox(height: t.spacing.xs),
          Text(
            '$total',
            style: t.text.display.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: t.colors.accent,
            ),
          ),
          Text('review${total == 1 ? '' : 's'} due today', style: t.text.secondary),
          SizedBox(height: t.spacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: t.spacing.sm,
            children: [
              ThemedStatPill(text: '$dueNow due', icon: Icons.history_rounded),
              ThemedStatPill(
                  text: '$newToday new', icon: Icons.fiber_new_rounded),
              ThemedStatPill(
                  text: '~$estMinutes min', icon: Icons.schedule_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(BuildContext context, Map<String, int> counts) {
    final t = context.tokens;
    final entries = counts.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) {
      return ThemedSurface(
        level: SurfaceLevel.standard,
        radius: t.radii.md,
        width: double.infinity,
        padding: EdgeInsets.all(t.spacing.md),
        child: Text(
          'Nothing due in any category right now.',
          style: t.text.secondary,
        ),
      );
    }
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xs,
      ),
      child: Column(
        children: entries
            .map((e) => Padding(
                  padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: t.text.body)),
                      ThemedStatPill(text: '${e.value}'),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTodayRow(BuildContext context, int completed) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: t.colors.good, size: 20),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              completed == 0
                  ? 'No reviews completed yet today'
                  : '$completed review${completed == 1 ? '' : 's'} completed today',
              style: t.text.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakTip(BuildContext context, CategoryProgress c) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      tint: t.colors.warn,
      tintStrength: 0.5,
      padding: EdgeInsets.all(t.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_down_rounded, color: t.colors.warn, size: 20),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Text(
              '${c.label} has been tripping you up lately — extra reps '
              'here go a long way.',
              style: t.text.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int completedToday) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
        child: ThemedSurface(
          level: SurfaceLevel.elevated,
          radius: t.radii.xl,
          padding: EdgeInsets.all(t.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedIconPlate(
                icon: Icons.check_rounded,
                color: t.colors.good,
                size: 60,
                iconSize: 30,
              ),
              SizedBox(height: t.spacing.md),
              Text(
                "You're all caught up!",
                textAlign: TextAlign.center,
                style: t.text.title,
              ),
              SizedBox(height: t.spacing.xs),
              Text(
                completedToday > 0
                    ? 'Nice work — $completedToday review'
                        '${completedToday == 1 ? '' : 's'} done today. '
                        'Check back later for more.'
                    : 'No reviews due right now. Check back later, or '
                        'browse Flashcards to get ahead.',
                textAlign: TextAlign.center,
                style: t.text.secondary,
              ),
              SizedBox(height: t.spacing.lg),
              ThemedButton(
                label: 'Browse Flashcards',
                icon: Icons.style_outlined,
                variant: ThemedButtonVariant.secondary,
                onPressed: () {
                  context.read<AudioService>().playMenuClick();
                  Navigator.of(context).push(
                    themedRoute(context, (_) => const FlashcardScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Daily Review',
      subtitle: '復習',
      leadingIcon: Icons.close_rounded,
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
