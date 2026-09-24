import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../models/kana_entry.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

/// The detailed view behind the home screen's "Daily Progress" card.
/// Everything here reads from [ProgressService] and [SettingsService] --
/// there is no separate/fake statistics source, so a brand-new install
/// shows honest zeros and empty states rather than placeholder numbers.
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final progress = context.watch<ProgressService>();
    final settings = context.watch<SettingsService>();

    final answered = settings.statsAnsweredTotal;
    final correct = settings.statsCorrectTotal;
    final accuracyPct = answered == 0 ? null : (100 * correct / answered).round();

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
                    _buildStreakRow(context, progress),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel("Today's goal"),
                    _buildGoalCard(context, progress),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('This week'),
                    _buildWeeklyChart(context, progress),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Learning progress'),
                    _buildCategoryList(context, progress),
                    if (accuracyPct != null) ...[
                      SizedBox(height: t.spacing.lg),
                      const ThemedSectionLabel('Overall accuracy'),
                      _buildAccuracyCard(context, correct, answered, accuracyPct),
                    ],
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Weak areas'),
                    _buildWeakAreas(context, progress),
                    SizedBox(height: t.spacing.lg),
                    const ThemedSectionLabel('Recent activity'),
                    _buildRecentActivity(context, progress),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Streak -------------------------------------------------------------

  Widget _buildStreakRow(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            iconColor: progress.currentStreak > 0 ? t.colors.warn : t.colors.textTertiary,
            value: '${progress.currentStreak}',
            label: 'day streak',
          ),
        ),
        SizedBox(width: t.spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_outlined,
            iconColor: t.colors.accent,
            value: '${progress.longestStreak}',
            label: 'best streak',
          ),
        ),
      ],
    );
  }

  // -- Today's goal ---------------------------------------------------------

  Widget _buildGoalCard(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final done = progress.todayCompletedCount;
    final goal = progress.dailyGoal;
    final fraction = goal == 0 ? 0.0 : done / goal;
    final reached = done >= goal;

    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reached
                      ? "Goal reached — nice work! 🎉"
                      : '$done of $goal reviews today',
                  style: t.text.cardTitle,
                ),
              ),
              _GoalStepper(
                goal: goal,
                onChanged: (v) {
                  context.read<AudioService>().playMenuClick();
                  progress.setDailyGoal(v);
                },
              ),
            ],
          ),
          SizedBox(height: t.spacing.sm),
          ThemedProgressBar(
            value: fraction,
            color: reached ? t.colors.good : t.colors.accent,
            height: 8,
          ),
        ],
      ),
    );
  }

  // -- Weekly chart ---------------------------------------------------------

  Widget _buildWeeklyChart(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final days = progress.last7DaysActivity;
    final maxVal = days.fold<int>(1, (m, v) => v > m ? v : m);
    final labels = _last7DayLabels();

    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: days.every((v) => v == 0)
          ? Text(
              'No activity yet this week — your daily reviews will show up '
              'here.',
              style: t.text.secondary,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final v = days[i];
                final h = 8 + (v / maxVal) * 64;
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$v',
                          style: t.text.caption.copyWith(fontSize: 10.5),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: (isToday ? t.colors.accent : t.colors.accent)
                                .withOpacity(isToday ? 0.95 : 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(labels[i], style: t.text.caption.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  List<String> _last7DayLabels() {
    const names = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      // DateTime.weekday is 1=Mon..7=Sun; index into the Sun-first list.
      return names[d.weekday % 7];
    });
  }

  // -- Category breakdown ---------------------------------------------------

  Widget _buildCategoryList(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final categories = progress.categoryBreakdown;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      child: Column(
        children: [
          for (final c in categories) ...[
            _buildCategoryRow(context, c),
            if (c != categories.last) SizedBox(height: t.spacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, CategoryProgress c) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.label,
                style: t.text.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${c.studied} / ${c.total}',
              style: t.text.caption,
            ),
            if (c.dueNow > 0) ...[
              SizedBox(width: t.spacing.xs),
              Text(
                '· ${c.dueNow} due',
                style: t.text.caption.copyWith(color: t.colors.accent),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        ThemedProgressBar(value: c.fraction, height: 5),
      ],
    );
  }

  // -- Accuracy ---------------------------------------------------------

  Widget _buildAccuracyCard(
      BuildContext context, int correct, int answered, int pct) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: t.colors.accent, size: 18),
          SizedBox(width: t.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Across every quiz & test',
                  style: t.text.caption.copyWith(letterSpacing: 0.4),
                ),
                const SizedBox(height: 5),
                ThemedProgressBar(value: pct / 100, height: 5),
              ],
            ),
          ),
          SizedBox(width: t.spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: t.text.title.copyWith(
                  color: t.colors.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('$correct / $answered', style: t.text.caption),
            ],
          ),
        ],
      ),
    );
  }

  // -- Weak areas ---------------------------------------------------------

  Widget _buildWeakAreas(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final weak = progress.weakCategories;
    if (weak.isEmpty) {
      return ThemedSurface(
        level: SurfaceLevel.standard,
        radius: t.radii.md,
        width: double.infinity,
        padding: EdgeInsets.all(t.spacing.md),
        child: Text(
          'Keep reviewing — once you have a few reviews in each category, '
          "we'll point out where extra practice helps most.",
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
        children: weak
            .take(2)
            .map((c) => Padding(
                  padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.trending_down_rounded,
                          color: t.colors.warn, size: 18),
                      SizedBox(width: t.spacing.sm),
                      Expanded(
                        child: Text(c.label, style: t.text.body),
                      ),
                      if (c.lapses > 0)
                        Text(
                          '${c.lapses} lapse${c.lapses == 1 ? '' : 's'}',
                          style: t.text.caption.copyWith(color: t.colors.warn),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // -- Recent activity ---------------------------------------------------

  Widget _buildRecentActivity(BuildContext context, ProgressService progress) {
    final t = context.tokens;
    final recent = progress.recentActivity;
    if (recent.isEmpty) {
      return ThemedSurface(
        level: SurfaceLevel.standard,
        radius: t.radii.md,
        width: double.infinity,
        padding: EdgeInsets.all(t.spacing.md),
        child: Text(
          'No activity yet — your recent reviews will show up here.',
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
        children: recent.map((r) {
          final item = progress.resolveItem(r.itemId);
          if (item == null) return const SizedBox.shrink();
          final (glyph, meaning) = _describeItem(item);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    glyph,
                    textAlign: TextAlign.center,
                    style: t.text.jp(18, weight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: t.spacing.sm),
                Expanded(
                  child: Text(
                    meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.body,
                  ),
                ),
                Text(_relativeTime(r.when), style: t.text.caption),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  (String, String) _describeItem(dynamic item) {
    if (item is VocabEntry) return (item.jp, item.meaning);
    if (item is KanjiEntry) return (item.kanji, item.meaning);
    if (item is KanaEntry) {
      return (
        item.character,
        item.romaji.isEmpty || item.romaji == '—' ? item.sound : item.romaji,
      );
    }
    return ('?', 'Unknown item');
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Progress',
      subtitle: '進捗',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          SizedBox(height: t.spacing.xs),
          Text(
            value,
            style: t.text.display.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: t.text.caption),
        ],
      ),
    );
  }
}

/// Small +/- control for adjusting the daily goal in place.
class _GoalStepper extends StatelessWidget {
  final int goal;
  final ValueChanged<int> onChanged;
  const _GoalStepper({required this.goal, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemedIconButton(
          icon: Icons.remove_rounded,
          size: 32,
          iconSize: 16,
          tooltip: 'Lower daily goal',
          onPressed: goal > 5 ? () => onChanged(goal - 5) : null,
        ),
        SizedBox(width: t.spacing.xxs),
        ThemedIconButton(
          icon: Icons.add_rounded,
          size: 32,
          iconSize: 16,
          tooltip: 'Raise daily goal',
          onPressed: goal < 100 ? () => onChanged(goal + 5) : null,
        ),
      ],
    );
  }
}
