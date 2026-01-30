import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/movie_detail.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import '../../core/tmdb_mapping.dart';
import 'tv_episode_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/tv_breadcrumb.dart';
import '../common/streaming_options_widget.dart';
import '../common/external_navigation_utils.dart';

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
    final showAsync = ref.watch(tvShowDetailProvider(showId));
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            return TvBreadcrumb(
              items: [
                BreadcrumbItem(
                  label: showName,
                  isClickable: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TvShowDetailScreen(
                          showId: showId,
                          showTitle: showName,
                        ),
                      ),
                    );
                  },
                ),
                BreadcrumbItem(
                  label: 'Season $seasonNumber',
                  isClickable: false,
                ),
              ],
              maxWidth: constraints.maxWidth - 100,
            );
          },
        ),
      ),
      body: seasonAsync.when(
        data: (season) => season != null 
            ? showAsync.when(
                data: (show) => prefsAsync.when(
                  data: (prefs) => _buildContent(context, season, show, prefs),
                  loading: () => _buildContent(context, season, show, null),
                  error: (_, __) => _buildContent(context, season, show, null),
                ),
                loading: () => _buildContent(context, season, null, null),
                error: (_, __) => _buildContent(context, season, null, null),
              )
            : const Center(child: Text('Season details not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TvSeasonDetail season, TvShowDetail? show, Preferences? prefs) {
    final theme = Theme.of(context);
    
    return CustomScrollView(
      slivers: [
        // Header with emphasis color background
        SliverToBoxAdapter(
          child: Container(
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 800;
                
                if (isWideScreen) {
                  // Wide screen layout: poster + info on left, streaming on right
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: Poster and basic info
                      Expanded(
                        flex: 1,
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
                      
                      const SizedBox(width: 24),
                      
                      // Right side: Streaming options
                      if (show != null && show.streamingOptions.isNotEmpty)
                        SizedBox(
                          width: 350,
                          child: StreamingOptionsWidget(
                            streamingOptions: show.streamingOptions,
                            tmdbId: show.tmdbId,
                            isTV: true,
                            isCompact: true,
                            locale: prefs?.streamingCountry,
                          ),
                        ),
                    ],
                  );
                } else {
                  // Narrow screen layout: traditional stacked layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      
                      // Streaming options below on small screens
                      if (show != null && show.streamingOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        StreamingOptionsWidget(
                          streamingOptions: show.streamingOptions,
                          tmdbId: show.tmdbId,
                          isTV: true,
                          isCompact: true,
                          locale: prefs?.streamingCountry,
                        ),
                      ],
                    ],
                  );
                }
              },
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

        // External Links at bottom
        SliverToBoxAdapter(
          child: Consumer(
            builder: (context, ref, child) {
              return _buildExternalLinks(context, season, ref);
            },
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
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
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

  Widget _buildExternalLinks(BuildContext context, TvSeasonDetail season, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final prefsAsync = ref.watch(preferencesProvider);
        return prefsAsync.when(
          data: (prefs) {
            final movieDetailsPreference = prefs.movieDetailsPreference ?? 'both';
            final brightness = Theme.of(context).brightness;
            
            // Determine which links to show based on preference
            final showTmdb = movieDetailsPreference == 'tmdb' || movieDetailsPreference == 'both';
            final showImdb = movieDetailsPreference == 'imdb' || movieDetailsPreference == 'both';
            
            // Get IMDb ID from the TV show cache (seasons don't have their own IMDb IDs)
            String? imdbId;
            bool hasImdbId = false;
            if (showImdb) {
              final tvCacheRepo = ref.read(tvCacheRepositoryProvider);
              final tvShow = tvCacheRepo.getShow(showId);
              imdbId = tvShow?.imdbId;
              hasImdbId = imdbId != null && imdbId.isNotEmpty;
            }
            
            if (!showTmdb && !showImdb) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (showTmdb) ...[
                        Tooltip(
                          message: 'View $showName on TMDB',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchTmdbSeason(
                                context,
                                showId: showId,
                                seasonNumber: seasonNumber,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.asset(
                                    'assets/images/tmdb_square.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      child: const Icon(Icons.movie),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (showImdb && hasImdbId) ...[
                        Tooltip(
                          message: 'View $showName on IMDb',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchImdbTitle(
                                context,
                                imdbId: imdbId!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.asset(
                                    brightness == Brightness.light
                                        ? 'assets/images/imdb_square_gold.png'
                                        : 'assets/images/imdb_square_black.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFFF5C518),
                                      child: const Center(
                                        child: Text(
                                          'I',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
}
