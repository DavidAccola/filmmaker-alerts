import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../providers/providers.dart';
import 'release_preferences_dialog.dart';
import 'tv_preferences_dialog.dart';

/// Displays tappable notification preference chips for [company] and [franchise]
/// contributor types. Shows:
///   - Movie notifications row (all types)
///   - TV notifications row (franchise only)
///
/// Tapping a row opens the appropriate dialog. Changes are saved directly to
/// the contributor repository and [contributorsProvider] is invalidated.
class ContributorNotificationPrefsWidget extends ConsumerWidget {
  final Contributor contributor;

  const ContributorNotificationPrefsWidget({
    super.key,
    required this.contributor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFranchise = contributor.type == ContributorType.franchise;
    final releasePrefs =
        contributor.releaseNotificationPrefs ?? ReleaseNotificationPreferences();
    final tvPrefs = contributor.tvNotificationPrefs ??
        TvNotificationPreferences(
          seriesPremiere: true,
          seasonPremieres: false,
          seasonFinales: false,
          newEpisodes: false,
          specials: false,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Movie notifications row
        _buildPrefsRow(
          context: context,
          label: 'Movie notifications:',
          chips: releasePrefs.selectedTypes,
          onTap: () => _editMoviePrefs(context, ref, releasePrefs),
        ),

        // TV notifications row — franchise only
        if (isFranchise) ...[
          const SizedBox(height: 6),
          _buildPrefsRow(
            context: context,
            label: 'TV notifications:',
            chips: tvPrefs.selectedTypes,
            onTap: () => _editTvPrefs(context, ref, tvPrefs),
          ),
        ],
      ],
    );
  }

  Widget _buildPrefsRow({
    required BuildContext context,
    required String label,
    required List<String> chips,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: color),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: chips
                    .map((chip) => _buildChip(context, chip, color))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text(
                'None — tap to configure',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _editMoviePrefs(
    BuildContext context,
    WidgetRef ref,
    ReleaseNotificationPreferences currentPrefs,
  ) async {
    final result = await showDialog<ReleasePreferencesResult>(
      context: context,
      builder: (ctx) => ReleasePreferencesDialog(
        workTitle: contributor.name,
        initialPreferences: currentPrefs,
        initialNotificationsPaused: contributor.notificationsSnoozed,
      ),
    );

    if (result == null || !context.mounted) return;

    final repo = ref.read(contributorRepositoryProvider);
    final stored = repo.getContributor(contributor.tmdbId);
    if (stored == null) return;

    final updated = Contributor(
      tmdbId: stored.tmdbId,
      name: stored.name,
      type: stored.type,
      profilePath: stored.profilePath,
      notifyForDepartments: stored.notifyForDepartments,
      availableDepartments: stored.availableDepartments,
      knownFor: stored.knownFor,
      latestWork: stored.latestWork,
      followedAt: stored.followedAt,
      allRolesSelected: stored.allRolesSelected,
      tvNotificationPrefs: stored.tvNotificationPrefs,
      notifyTvEpisodeWork: stored.notifyTvEpisodeWork,
      showStatus: stored.showStatus,
      totalSeasons: stored.totalSeasons,
      nextEpisodeDate: stored.nextEpisodeDate,
      imdbId: stored.imdbId,
      notificationsSnoozed: result.notificationsPaused,
      isHidden: stored.isHidden,
      releaseNotificationPrefs: result.preferences,
    );

    await repo.updateContributor(updated);
    ref.invalidate(contributorsProvider);
  }

  Future<void> _editTvPrefs(
    BuildContext context,
    WidgetRef ref,
    TvNotificationPreferences currentPrefs,
  ) async {
    final result = await showDialog<TvPreferencesResult>(
      context: context,
      builder: (ctx) => TvPreferencesDialog(
        workTitle: contributor.name,
        initialPreferences: currentPrefs,
        initialNotificationsPaused: contributor.notificationsSnoozed,
        showHighVolumeWarning: true,
      ),
    );

    if (result == null || !context.mounted) return;

    final repo = ref.read(contributorRepositoryProvider);
    final stored = repo.getContributor(contributor.tmdbId);
    if (stored == null) return;

    final updated = Contributor(
      tmdbId: stored.tmdbId,
      name: stored.name,
      type: stored.type,
      profilePath: stored.profilePath,
      notifyForDepartments: stored.notifyForDepartments,
      availableDepartments: stored.availableDepartments,
      knownFor: stored.knownFor,
      latestWork: stored.latestWork,
      followedAt: stored.followedAt,
      allRolesSelected: stored.allRolesSelected,
      tvNotificationPrefs: result.preferences,
      notifyTvEpisodeWork: stored.notifyTvEpisodeWork,
      showStatus: stored.showStatus,
      totalSeasons: stored.totalSeasons,
      nextEpisodeDate: stored.nextEpisodeDate,
      imdbId: stored.imdbId,
      notificationsSnoozed: result.notificationsPaused,
      isHidden: stored.isHidden,
      releaseNotificationPrefs: stored.releaseNotificationPrefs,
    );

    await repo.updateContributor(updated);
    ref.invalidate(contributorsProvider);
  }
}
