import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import '../common/streaming_options_widget.dart';
import '../common/external_navigation_utils.dart';
import '../common/snackbar_utils.dart';
import 'contributor_detail_screen.dart';
import 'tv_episode_detail_screen.dart';
import 'tv_season_detail_screen.dart';
import '../../data/models/contributor.dart';
import '../../data/models/movie_detail.dart';
import '../../logic/work_sorting_logic.dart';
import '../common/shelf_with_arrows.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/adaptive_tooltip_text.dart';

class TvShowDetailScreen extends ConsumerStatefulWidget {
  final int showId;
  final String? showTitle;

  const TvShowDetailScreen({
    super.key,
    required this.showId,
    this.showTitle,
  });

  @override
  ConsumerState<TvShowDetailScreen> createState() => _TvShowDetailScreenState();
}

class _TvShowDetailScreenState extends ConsumerState<TvShowDetailScreen> {
  bool _synopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);
    final showDetailAsync = ref.watch(tvShowDetailProvider(widget.showId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showTitle ?? 'TV Show Details'),
      ),
      body: prefsAsync.when(
        data: (prefs) => showDetailAsync.when(
          data: (showDetail) => showDetail != null 
              ? _buildContent(prefs, showDetail)
              : _buildErrorState('TV show details not available'),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState('Error: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState('Error: $error'),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Preferences prefs, TvShowDetail showDetail) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataHeader(showDetail, prefs),
          const SizedBox(height: 24),
          _buildSynopsisSection(showDetail),
          const SizedBox(height: 24),
          if (showDetail.streamingOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamingOptionsWidget(
                streamingOptions: showDetail.streamingOptions,
              ),
            ),
          if (showDetail.streamingOptions.isNotEmpty)
            const SizedBox(height: 24),
          
          if (showDetail.seasons.isNotEmpty)
            _buildSeasonsSection(showDetail),
          
          if (showDetail.seasons.isNotEmpty)
            const SizedBox(height: 24),

          if (showDetail.cast.isNotEmpty)
            _buildCastSection(showDetail),
          
          if (showDetail.cast.isNotEmpty)
            const SizedBox(height: 24),

          if (showDetail.crew.isNotEmpty)
            _buildCrewSection(showDetail),
          
          if (showDetail.crew.isNotEmpty)
            const SizedBox(height: 24),
          
          _buildExternalLinks(showDetail),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetadataHeader(TvShowDetail showDetail, Preferences prefs) {
    final theme = Theme.of(context);
    final shadowColor = theme.brightness == Brightness.dark ? Colors.black54 : Colors.grey.withOpacity(0.3);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          Hero(
            tag: 'work_poster_${showDetail.tmdbId}',
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: showDetail.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w500${showDetail.posterPath}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.tv, size: 50),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // Basic Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdaptiveTooltipText(
                  showDetail.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                
                // Years and Status
                Row(
                  children: [
                    Text(
                      _formatYearRange(showDetail),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (showDetail.status != null) ...[
                      const SizedBox(width: 8),
                      _buildStatusChip(showDetail.status!),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                // Seasons and Episodes count
                if (showDetail.numberOfSeasons != null)
                  Row(
                    children: [
                      Text(
                        '${showDetail.numberOfSeasons} Seasons • ${showDetail.numberOfEpisodes ?? "?"} Episodes',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (showDetail.episodeRunTime.isNotEmpty) ...[
                        const Text(' • ', style: TextStyle(fontSize: 12)),
                        RuntimeDisplay(
                          runtime: showDetail.episodeRunTime.first,
                          isUpcoming: showDetail.status?.toLowerCase() != 'ended',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                
                const SizedBox(height: 12),
                
                // Rating
                if (showDetail.tmdbRating != null && (showDetail.voteCount ?? 0) > 0 && !(prefs.hideRatingsInDetails ?? false))
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        showDetail.tmdbRating!.toStringAsFixed(1),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${_formatVoteCount(showDetail.voteCount!)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatYearRange(TvShowDetail showDetail) {
    if (showDetail.firstAirDate == null) return 'Unknown';
    final startYear = showDetail.firstAirDate!.year.toString();
    
    if (showDetail.status?.toLowerCase() == 'ended' || showDetail.status?.toLowerCase() == 'canceled') {
      final endYear = showDetail.lastAirDate?.year.toString() ?? '?';
      return '$startYear–$endYear';
    }
    return '$startYear–Present';
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    Color color = Colors.grey;
    if (status.toLowerCase() == 'returning series' || status.toLowerCase() == 'in production') {
      color = Colors.green;
    } else if (status.toLowerCase() == 'ended' || status.toLowerCase() == 'canceled') {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSynopsisSection(TvShowDetail showDetail) {
    if (showDetail.synopsis.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synopsis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ExpandableSynopsis(
            synopsis: showDetail.synopsis,
            isUpcoming: showDetail.status?.toLowerCase() != 'ended',
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonsSection(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    final sortedSeasons = List<TvSeason>.from(showDetail.seasons)
      ..sort((a, b) => b.seasonNumber.compareTo(a.seasonNumber)); // Show newest first

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            'Seasons',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: sortedSeasons.length,
            itemBuilder: (context, index) {
              final season = sortedSeasons[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TvSeasonDetailScreen(
                        showId: showDetail.tmdbId,
                        seasonNumber: season.seasonNumber,
                        showName: showDetail.name,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: _buildSeasonCard(season),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonCard(TvSeason season) {
    final theme = Theme.of(context);
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: season.posterPath != null
                ? CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w200${season.posterPath}',
                    height: 120,
                    width: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 120,
                    width: 100,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.tv),
                  ),
          ),
          const SizedBox(height: 4),
          AdaptiveTooltipText(
            season.name,
            maxLines: 1,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            '${season.episodeCount} episodes',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCastSection(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    final sortedCast = WorkSortingLogic.sortCast(showDetail.cast);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            'Series Cast',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ShelfWithArrows(
          height: 140,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: sortedCast.length,
            itemBuilder: (context, index) {
              final member = sortedCast[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _ContributorHoverCircle(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.character,
                  isFollowed: member.isFollowed,
                  radius: 35,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContributorDetailScreen(
                          contributor: Contributor(
                            tmdbId: member.tmdbId,
                            name: member.name,
                            type: ContributorType.person,
                            profilePath: member.profilePath,
                            notifyForDepartments: [],
                            availableDepartments: [],
                            knownFor: '',
                          ),
                        ),
                      ),
                    );
                  },
                  onFollow: () {
                    debugPrint('Follow cast: ${member.name}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildCrewSection(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    final sortedCrew = WorkSortingLogic.groupAndSortCrew(showDetail.crew);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            'Crew',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ShelfWithArrows(
          height: 140,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: sortedCrew.length,
            itemBuilder: (context, index) {
              final member = sortedCrew[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _ContributorHoverCircle(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.job,
                  isFollowed: member.isFollowed,
                  radius: 35,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContributorDetailScreen(
                          contributor: Contributor(
                            tmdbId: member.tmdbId,
                            name: member.name,
                            type: ContributorType.person,
                            profilePath: member.profilePath,
                            notifyForDepartments: [],
                            availableDepartments: [],
                            knownFor: '',
                          ),
                        ),
                      ),
                    );
                  },
                  onFollow: () {
                    debugPrint('Follow crew: ${member.name}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildExternalLinks(TvShowDetail showDetail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ExternalNavigationUtils.launchTmdbTitle(
                  context,
                  tmdbId: showDetail.tmdbId,
                  isTV: true,
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('View on TMDB'),
            ),
          ),
          if (showDetail.imdbId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ExternalNavigationUtils.launchImdbTitle(
                    context,
                    imdbId: showDetail.imdbId!,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View on IMDb'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatVoteCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _ContributorHoverCircle extends StatefulWidget {
  final int tmdbId;
  final String name;
  final String? profilePath;
  final String subtitle;
  final bool isFollowed;
  final double radius;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  const _ContributorHoverCircle({
    required this.tmdbId,
    required this.name,
    this.profilePath,
    required this.subtitle,
    required this.isFollowed,
    required this.radius,
    required this.onTap,
    required this.onFollow,
  });

  @override
  State<_ContributorHoverCircle> createState() => _ContributorHoverCircleState();
}

class _ContributorHoverCircleState extends State<_ContributorHoverCircle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.radius + 10),
        child: SizedBox(
          width: widget.radius * 2 + 20,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: widget.radius,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: widget.profilePath != null
                        ? CachedNetworkImageProvider('https://image.tmdb.org/t/p/w200${widget.profilePath}')
                        : null,
                    child: widget.profilePath == null ? const Icon(Icons.person) : null,
                  ),
                  
                  // Hover Mask + Center Follow Button
                  AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: widget.radius * 2,
                      height: widget.radius * 2,
                      decoration: BoxDecoration(
                         color: Colors.blue.withOpacity(0.4),
                         shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            widget.isFollowed ? Icons.remove_circle : Icons.add_circle,
                            size: 28,
                            color: Colors.white,
                          ),
                          onPressed: widget.onFollow,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: widget.isFollowed ? 'Unfollow' : 'Follow',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AdaptiveTooltipText(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: widget.isFollowed ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              AdaptiveTooltipText(
                widget.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
