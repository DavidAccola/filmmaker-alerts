import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/movie_detail.dart';
import '../../providers/providers.dart';
import '../../core/tmdb_mapping.dart';
import 'tv_episode_detail_screen.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/shelf_with_arrows.dart';

class TvSeasonDetailScreen extends ConsumerWidget {
  final int showId;
  final int seasonNumber;
  final String showName;

  const TvSeasonDetailScreen({
    super.key,
    required this.showId,
    required this.seasonNumber,
    required this.showName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(tvSeasonDetailProvider((showId: showId, seasonNumber: seasonNumber)));

    return Scaffold(
      appBar: AppBar(
        title: Text('$showName - Season $seasonNumber'),
      ),
      body: seasonAsync.when(
        data: (season) => season != null ? _buildContent(context, season) : const Center(child: Text('Season details not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TvSeasonDetail season) {
    final theme = Theme.of(context);
    
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: season.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w300${season.posterPath}',
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 120,
                          height: 180,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.tv, size: 40),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        season.name,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (season.airDate != null)
                        Text(
                          DateFormat('yyyy').format(season.airDate!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '${season.episodes.length} Episodes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (season.overview != null && season.overview!.isNotEmpty)
                        ExpandableSynopsis(
                          synopsis: season.overview!,
                          isUpcoming: season.airDate?.isAfter(DateTime.now()) ?? true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Episodes List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = season.episodes[index];
                return _buildEpisodeItem(context, episode);
              },
              childCount: season.episodes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeItem(BuildContext context, SeasonEpisode episode) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TvEpisodeDetailScreen(
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episode.episodeNumber,
                showName: showName,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Still Image
                Container(
                  width: 120,
                  height: 80,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: episode.stillPath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w200${episode.stillPath}',
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.movie, size: 40),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${episode.episodeNumber}. ',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                episode.name,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (episode.airDate != null || episode.runtime != null)
                          Row(
                            children: [
                              if (episode.airDate != null)
                                Text(
                                  DateFormat('MMM d, yyyy').format(episode.airDate!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (episode.airDate != null && episode.runtime != null && episode.runtime! > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text('•', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                                ),
                              if (episode.runtime != null && episode.runtime! > 0)
                                RuntimeDisplay(
                                  runtime: episode.runtime!,
                                  isUpcoming: episode.airDate?.isAfter(DateTime.now()) ?? true,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Crew details
            if (episode.crew.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _buildCrewText(context, episode.crew),
                  ],
                ),
              ),
              
            if (episode.overview != null && episode.overview!.isNotEmpty)
               Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                child: ExpandableSynopsis(
                  synopsis: episode.overview!,
                  isEpisode: true,
                  isUpcoming: episode.airDate?.isAfter(DateTime.now()) ?? true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewText(BuildContext context, List<CrewMember> crew) {
    final theme = Theme.of(context);
    final directors = crew
        .where((c) => TmdbMapping.mapTmdbDeptToRole(c.department, job: c.job) == 'Director')
        .map((c) => c.name)
        .toList();
    final writers = crew
        .where((c) => TmdbMapping.mapTmdbDeptToRole(c.department, job: c.job) == 'Writer')
        .map((c) => c.name)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (directors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.labelSmall,
                children: [
                  TextSpan(
                    text: 'Director: ',
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: directors.join(', '),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        if (writers.isNotEmpty)
          RichText(
            text: TextSpan(
              style: theme.textTheme.labelSmall,
              children: [
                TextSpan(
                  text: 'Writer: ',
                  style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: writers.join(', '),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
