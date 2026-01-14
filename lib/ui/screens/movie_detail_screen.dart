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
import 'contributor_detail_screen.dart';
import '../../data/models/contributor.dart';
import '../../logic/work_sorting_logic.dart';
import '../common/shelf_with_arrows.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/contributor_hover_card.dart';
import '../../core/tmdb_mapping.dart';

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
    final movieDetailAsync = ref.watch(movieDetailProvider(widget.movieId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movieTitle ?? 'Movie Details'),
      ),
      body: prefsAsync.when(
        data: (prefs) => movieDetailAsync.when(
          data: (movieDetail) => movieDetail != null 
              ? _buildContent(prefs, movieDetail)
              : _buildErrorState('Movie details not available'),
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
          const Icon(Icons.movie, size: 64, color: Colors.grey),
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

  Widget _buildContent(Preferences prefs, MovieDetail movieDetail) {

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
                    AdaptiveTooltipText(
                      movieDetail.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    if (movieDetail.releaseDate != null || movieDetail.runtime != null)
                      Row(
                        children: [
                          if (movieDetail.releaseDate != null)
                            Text(
                              DateFormat('MMM d, yyyy').format(movieDetail.releaseDate!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (movieDetail.releaseDate != null && movieDetail.runtime != null && movieDetail.runtime! > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                          if (movieDetail.runtime != null && movieDetail.runtime! > 0)
                            RuntimeDisplay(
                              runtime: movieDetail.runtime!,
                              isUpcoming: movieDetail.releaseDate?.isAfter(DateTime.now()) ?? true,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Rating and popularity
                    Row(
                      children: [
                        if (!(prefs.hideRatingsInDetails ?? false) && movieDetail.tmdbRating != null && movieDetail.voteCount != null && movieDetail.voteCount! > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
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
          ExpandableSynopsis(
            synopsis: movieDetail.synopsis,
            isUpcoming: movieDetail.releaseDate?.isAfter(DateTime.now()) ?? true,
          ),
        ],
      ),
    );
  }
  Widget _buildCastSection(MovieDetail movieDetail, Preferences prefs) {
    final sortedCast = WorkSortingLogic.sortCast(movieDetail.cast);

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
          ShelfWithArrows(
            height: 175,
            builder: (context, controller) => ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: sortedCast.length,
              itemBuilder: (context, index) {
                final castMember = sortedCast[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < sortedCast.length - 1 ? 12 : 0),
                  child: ContributorHoverCard(
                    tmdbId: castMember.tmdbId,
                    name: castMember.name,
                    profilePath: castMember.profilePath,
                    subtitle: castMember.character,
                    isFollowed: castMember.isFollowed,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContributorDetailScreen(
                            contributor: Contributor(
                              tmdbId: castMember.tmdbId,
                              name: castMember.name,
                              type: ContributorType.person,
                              profilePath: castMember.profilePath,
                              notifyForDepartments: [],
                              availableDepartments: [],
                              knownFor: '',
                            ),
                          ),
                        ),
                      );
                    },
                    onFollow: () {
                       // TODO: Implement follow logic
                       debugPrint('Follow cast: ${castMember.name}');
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCrewSection(MovieDetail movieDetail, Preferences prefs) {
    final sortedCrew = WorkSortingLogic.groupAndSortCrew(movieDetail.crew);

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
          ShelfWithArrows(
            height: 175,
            builder: (context, controller) => ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: sortedCrew.length,
              itemBuilder: (context, index) {
                final crewMember = sortedCrew[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < sortedCrew.length - 1 ? 12 : 0),
                  child: ContributorHoverCard(
                    tmdbId: crewMember.tmdbId,
                    name: crewMember.name,
                    profilePath: crewMember.profilePath,
                    subtitle: crewMember.job,
                    isFollowed: crewMember.isFollowed,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContributorDetailScreen(
                            contributor: Contributor(
                              tmdbId: crewMember.tmdbId,
                              name: crewMember.name,
                              type: ContributorType.person,
                              profilePath: crewMember.profilePath,
                              notifyForDepartments: [],
                              availableDepartments: [],
                              knownFor: '',
                            ),
                          ),
                        ),
                      );
                    },
                    onFollow: () {
                       // TODO: Implement follow logic
                       debugPrint('Follow crew: ${crewMember.name}');
                    },
                  ),
                );
              },
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

// Local _ContributorHoverCard removed. Using common/contributor_hover_card.dart
