import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/movie_detail.dart';
import '../../data/models/preferences.dart';
import '../../data/repositories/movie_detail_repository.dart';
import '../../providers/providers.dart';
import '../common/streaming_options_widget.dart';
import '../common/external_navigation_utils.dart';
import '../common/snackbar_utils.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  final int movieId;
  final String? movieTitle;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.movieTitle,
  });

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  bool _synopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movieTitle ?? 'Movie Details'),
      ),
      body: prefsAsync.when(
        data: (prefs) => _buildContent(prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(Preferences prefs) {
    final movieDetailRepo = MovieDetailRepository();
    final movieDetail = movieDetailRepo.getMovieDetail(widget.movieId);

    if (movieDetail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Movie details not available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie metadata header
          _buildMetadataHeader(movieDetail, prefs),
          
          const SizedBox(height: 24),
          
          // Synopsis section
          _buildSynopsisSection(movieDetail),
          
          const SizedBox(height: 24),
          
          // Streaming options
          if (movieDetail.streamingOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamingOptionsWidget(
                streamingOptions: movieDetail.streamingOptions,
              ),
            ),
          
          if (movieDetail.streamingOptions.isNotEmpty)
            const SizedBox(height: 24),
          
          // Cast section
          if (movieDetail.cast.isNotEmpty)
            _buildCastSection(movieDetail, prefs),
          
          if (movieDetail.cast.isNotEmpty)
            const SizedBox(height: 24),
          
          // Crew section
          if (movieDetail.crew.isNotEmpty)
            _buildCrewSection(movieDetail, prefs),
          
          if (movieDetail.crew.isNotEmpty)
            const SizedBox(height: 24),
          
          // External links
          _buildExternalLinks(movieDetail),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetadataHeader(MovieDetail movieDetail, Preferences prefs) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster and basic info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image
              Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: movieDetail.posterPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w300${movieDetail.posterPath}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.movie, size: 40),
                        ),
                      )
                    : const Icon(Icons.movie, size: 40),
              ),
              
              const SizedBox(width: 16),
              
              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movieDetail.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Release date and runtime
                    if (movieDetail.releaseDate != null || movieDetail.runtime != null)
                      Text(
                        [
                          if (movieDetail.releaseDate != null)
                            DateFormat('MMM d, yyyy').format(movieDetail.releaseDate!),
                          if (movieDetail.runtime != null)
                            '${movieDetail.runtime} min',
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Rating and popularity
                    Row(
                      children: [
                        if (!(prefs.hideRatingsInDetails ?? false) && movieDetail.tmdbRating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                movieDetail.tmdbRating!.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        
                        if (!(prefs.hideRatingsInDetails ?? false) && movieDetail.tmdbRating != null &&
                            !(prefs.hidePopularityInDetails ?? false) && movieDetail.popularity != null)
                          const SizedBox(width: 12),
                        
                        if (!(prefs.hidePopularityInDetails ?? false) && movieDetail.popularity != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                movieDetail.popularity!.toInt().toString(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSynopsisSection(MovieDetail movieDetail) {
    if (movieDetail.synopsis.isEmpty) {
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
          GestureDetector(
            onTap: () {
              setState(() {
                _synopsisExpanded = !_synopsisExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movieDetail.synopsis,
                    maxLines: _synopsisExpanded ? null : 3,
                    overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _synopsisExpanded ? 'Show less' : 'Show more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildCastSection(MovieDetail movieDetail, Preferences prefs) {
    // Separate followed and non-followed cast members
    final followedCast = movieDetail.cast.where((c) => c.isFollowed).toList();
    final otherCast = movieDetail.cast.where((c) => !c.isFollowed).toList();
    
    // Combine with followed first
    final sortedCast = [...followedCast, ...otherCast];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cast',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedCast.length,
              itemBuilder: (context, index) {
                final castMember = sortedCast[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < sortedCast.length - 1 ? 12 : 0),
                  child: _buildCastCard(castMember),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastCard(CastMember castMember) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: castMember.isFollowed
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: castMember.profilePath != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w200${castMember.profilePath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
                      ),
                    )
                  : const Icon(Icons.person, size: 40),
            ),
          ),
          
          // Name and character
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  castMember.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: castMember.isFollowed ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  castMember.character,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewSection(MovieDetail movieDetail, Preferences prefs) {
    // Separate followed and non-followed crew members
    final followedCrew = movieDetail.crew.where((c) => c.isFollowed).toList();
    final otherCrew = movieDetail.crew.where((c) => !c.isFollowed).toList();
    
    // Combine with followed first
    final sortedCrew = [...followedCrew, ...otherCrew];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crew',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedCrew.length,
              itemBuilder: (context, index) {
                final crewMember = sortedCrew[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < sortedCrew.length - 1 ? 12 : 0),
                  child: _buildCrewCard(crewMember),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(CrewMember crewMember) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: crewMember.isFollowed
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: crewMember.profilePath != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w200${crewMember.profilePath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
                      ),
                    )
                  : const Icon(Icons.person, size: 40),
            ),
          ),
          
          // Name and job
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crewMember.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: crewMember.isFollowed ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  crewMember.job,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalLinks(MovieDetail movieDetail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'External Links',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ExternalNavigationUtils.launchTmdbTitle(
                    context,
                    tmdbId: movieDetail.tmdbId,
                    isTV: false,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('TMDB'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: movieDetail.imdbId != null && movieDetail.imdbId!.isNotEmpty
                      ? () => ExternalNavigationUtils.launchImdbTitle(
                          context,
                          imdbId: movieDetail.imdbId!,
                        )
                      : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('IMDb'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}