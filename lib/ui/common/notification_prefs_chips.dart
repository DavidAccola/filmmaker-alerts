import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/watchlist_entry.dart';
import '../../providers/providers.dart';
import 'release_preferences_dialog.dart';
import 'tv_preferences_dialog.dart';

/// A widget that displays notification preference chips for watchlist items.
/// 
/// For movies: Shows release notification types (Theatrical, Streaming, Physical, TV)
/// For TV shows: Shows episode notification types (Series Premiere, Season Premieres, etc.)
/// 
/// Tapping the chips opens a dialog to edit the preferences.
class NotificationPrefsChips extends ConsumerWidget {
  final int tmdbId;
  final WorkType workType;
  
  const NotificationPrefsChips({
    super.key,
    required this.tmdbId,
    required this.workType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistRepo = ref.watch(watchlistRepositoryProvider);
    final entry = watchlistRepo.getWork(tmdbId, workType);
    
    // Only show if the item is in the watchlist
    if (entry == null) {
      return const SizedBox.shrink();
    }
    
    if (workType == WorkType.movie) {
      return _buildMoviePrefsChips(context, ref, entry);
    } else if (workType == WorkType.tvShow) {
      return _buildTvPrefsChips(context, ref, entry);
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildMoviePrefsChips(BuildContext context, WidgetRef ref, WatchlistEntry entry) {
    final prefs = entry.releaseNotificationPrefs ?? ReleaseNotificationPreferences();
    final selectedTypes = <String>[];
    
    if (prefs.theatrical) selectedTypes.add('Theatrical');
    if (prefs.streaming) selectedTypes.add('Streaming');
    if (prefs.physical) selectedTypes.add('Physical');
    if (prefs.tv) selectedTypes.add('TV');
    
    if (selectedTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildChipsSection(
      context: context,
      label: 'Release notifications:',
      chips: selectedTypes,
      onTap: () => _showReleasePrefsDialog(context, ref, entry),
    );
  }

  Widget _buildTvPrefsChips(BuildContext context, WidgetRef ref, WatchlistEntry entry) {
    final prefs = entry.tvNotificationPrefs ?? TvNotificationPreferences();
    final selectedTypes = <String>[];
    
    if (prefs.seriesPremiere) selectedTypes.add('Series Premiere');
    if (prefs.seasonPremieres) selectedTypes.add('Season Premieres');
    if (prefs.seasonFinales) selectedTypes.add('Season Finales');
    if (prefs.newEpisodes) selectedTypes.add('New Episodes');
    if (prefs.specials) selectedTypes.add('Specials');
    
    if (selectedTypes.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildChipsSection(
      context: context,
      label: 'Episode notifications:',
      chips: selectedTypes,
      onTap: () => _showTvPrefsDialog(context, ref, entry),
    );
  }

  Widget _buildChipsSection({
    required BuildContext context,
    required String label,
    required List<String> chips,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((chip) => _buildChip(context, chip)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    
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

  Future<void> _showReleasePrefsDialog(BuildContext context, WidgetRef ref, WatchlistEntry entry) async {
    final result = await showDialog<ReleaseNotificationPreferences>(
      context: context,
      builder: (context) => ReleasePreferencesDialog(
        initialPreferences: entry.releaseNotificationPrefs ?? ReleaseNotificationPreferences(),
        workTitle: entry.title,
      ),
    );
    
    if (result != null) {
      final watchlistRepo = ref.read(watchlistRepositoryProvider);
      await watchlistRepo.updateReleaseNotificationPreferences(
        entry.tmdbId,
        entry.type,
        result,
      );
      // Invalidate to refresh UI
      ref.invalidate(watchlistRepositoryProvider);
    }
  }

  Future<void> _showTvPrefsDialog(BuildContext context, WidgetRef ref, WatchlistEntry entry) async {
    final result = await showDialog<TvNotificationPreferences>(
      context: context,
      builder: (context) => TvPreferencesDialog(
        initialPreferences: entry.tvNotificationPrefs ?? TvNotificationPreferences(),
        workTitle: entry.title,
      ),
    );
    
    if (result != null) {
      final watchlistRepo = ref.read(watchlistRepositoryProvider);
      await watchlistRepo.updateTvNotificationPreferences(
        entry.tmdbId,
        result,
      );
      // Invalidate to refresh UI
      ref.invalidate(watchlistRepositoryProvider);
    }
  }
}
