import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import '../common/streaming_options_widget.dart';
import '../common/external_navigation_utils.dart';
import '../common/snackbar_utils.dart';
import '../common/watchlist_button.dart';
import '../common/expand_poster_button.dart';
import 'contributor_detail_screen.dart';
import 'tv_season_detail_screen.dart';
import '../../data/models/contributor.dart';
import '../../data/models/movie_detail.dart';
import '../../logic/work_sorting_logic.dart';
import '../common/shelf_with_arrows.dart';
import '../common/expandable_synopsis.dart';
import '../common/runtime_display.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/contributor_hover_card.dart';
import '../common/department_selection_dialog.dart';

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
  bool _isPosterHovered = false;

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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
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
                      // Poster with watchlist button
                      MouseRegion(
                        onEnter: (_) {
                          debugPrint('[TvShowDetailScreen] Poster hovered: true');
                          setState(() => _isPosterHovered = true);
                        },
                        onExit: (_) {
                          debugPrint('[TvShowDetailScreen] Poster hovered: false');
                          setState(() => _isPosterHovered = false);
                        },
                        child: SizedBox(
                          width: 100,
                          height: 150,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: showDetail.posterPath != null
                                      ? CachedNetworkImage(
                                          imageUrl: 'https://image.tmdb.org/t/p/w300${showDetail.posterPath}',
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Icon(Icons.tv, size: 40),
                                          errorWidget: (context, url, error) => const Icon(Icons.tv, size: 40),
                                        )
                                      : const Icon(Icons.tv, size: 40),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: WatchlistButton(
                                  tmdbId: showDetail.tmdbId,
                                  workType: WorkType.tvShow,
                                  workTitle: showDetail.name,
                                  posterPath: showDetail.posterPath,
                                  releaseDate: showDetail.firstAirDate,
                                  position: WatchlistButtonStyle.topRight,
                                  showOnHoverOnly: true,
                                  iconSize: 20,
                                  isHovered: _isPosterHovered,
                                  applyPositioning: false,
                                ),
                              ),
                              // Expand poster button
                              Positioned(
                                top: 4,
                                left: 4,
                                child: ExpandPosterButton(
                                  posterPath: showDetail.posterPath,
                                  title: showDetail.name,
                                  isCardHovered: _isPosterHovered,
                                  iconSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Basic Info
                      Expanded(
                        child: _buildShowInfo(showDetail, prefs),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Right side: Streaming options (always show, even when empty)
                SizedBox(
                  width: 350,
                  child: StreamingOptionsWidget(
                    streamingOptions: showDetail.streamingOptions,
                    tmdbId: showDetail.tmdbId,
                    isTV: true,
                    isCompact: true,
                    locale: prefs.streamingCountry,
                    title: showDetail.name,
                    releaseDate: showDetail.firstAirDate,
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
                    // Poster with watchlist button
                    MouseRegion(
                      onEnter: (_) {
                        debugPrint('[TvShowDetailScreen] Poster hovered: true');
                        setState(() => _isPosterHovered = true);
                      },
                      onExit: (_) {
                        debugPrint('[TvShowDetailScreen] Poster hovered: false');
                        setState(() => _isPosterHovered = false);
                      },
                      child: SizedBox(
                        width: 100,
                        height: 150,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: showDetail.posterPath != null
                                    ? CachedNetworkImage(
                                        imageUrl: 'https://image.tmdb.org/t/p/w300${showDetail.posterPath}',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Icon(Icons.tv, size: 40),
                                        errorWidget: (context, url, error) => const Icon(Icons.tv, size: 40),
                                      )
                                    : const Icon(Icons.tv, size: 40),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: WatchlistButton(
                                tmdbId: showDetail.tmdbId,
                                workType: WorkType.tvShow,
                                workTitle: showDetail.name,
                                posterPath: showDetail.posterPath,
                                releaseDate: showDetail.firstAirDate,
                                position: WatchlistButtonStyle.topRight,
                                showOnHoverOnly: true,
                                iconSize: 20,
                                isHovered: _isPosterHovered,
                                applyPositioning: false,
                              ),
                            ),
                            // Expand poster button
                            Positioned(
                              top: 4,
                              left: 4,
                              child: ExpandPosterButton(
                                posterPath: showDetail.posterPath,
                                title: showDetail.name,
                                isCardHovered: _isPosterHovered,
                                iconSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Basic Info
                    Expanded(
                      child: _buildShowInfo(showDetail, prefs),
                    ),
                  ],
                ),
                
                // Streaming options below on small screens (always show, even when empty)
                const SizedBox(height: 16),
                StreamingOptionsWidget(
                  streamingOptions: showDetail.streamingOptions,
                  tmdbId: showDetail.tmdbId,
                  isTV: true,
                  isCompact: true,
                  locale: prefs.streamingCountry,
                  title: showDetail.name,
                  releaseDate: showDetail.firstAirDate,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildShowInfo(TvShowDetail showDetail, Preferences prefs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveTooltipText(
          showDetail.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (showDetail.status != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              Text(
                showDetail.status!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        
        if (showDetail.numberOfSeasons != null)
          Row(
            children: [
              Text(
                '${showDetail.numberOfSeasons} Seasons',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (showDetail.numberOfEpisodes != null) ...[
                Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
                   child: Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                Text(
                  '${showDetail.numberOfEpisodes} Episodes',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              if (showDetail.episodeRunTime.isNotEmpty) ...[
                Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4.0),
                   child: Text('•', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                RuntimeDisplay(
                  runtime: showDetail.episodeRunTime.first,
                  isUpcoming: showDetail.status?.toLowerCase() != 'ended',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        
        const SizedBox(height: 12),
        
        // Rating
        if (showDetail.tmdbRating != null && (showDetail.voteCount ?? 0) > 0 && !(prefs.hideRatingsInDetails ?? false))
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                showDetail.tmdbRating!.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
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
          height: 175,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: sortedCast.length,
            itemBuilder: (context, index) {
              final member = sortedCast[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ContributorHoverCard(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.character,
                  isFollowed: member.isFollowed,
                  // radius: 35, // Removed
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
                  onFollow: () async {
                    await _handleFollowPerson(member, ref);
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
          height: 175,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: sortedCrew.length,
            itemBuilder: (context, index) {
              final member = sortedCrew[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ContributorHoverCard(
                  tmdbId: member.tmdbId,
                  name: member.name,
                  profilePath: member.profilePath,
                  subtitle: member.job,
                  isFollowed: member.isFollowed,
                  // radius: 35, // Removed
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
                  onFollow: () async {
                    await _handleFollowPerson(member, ref);
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
            final hasImdbId = showDetail.imdbId != null && showDetail.imdbId!.isNotEmpty;
            
            if (!showTmdb && !showImdb) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          message: 'View ${showDetail.name} on TMDB',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchTmdbTitle(
                                context,
                                tmdbId: showDetail.tmdbId,
                                isTV: true,
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
                          message: 'View ${showDetail.name} on IMDb',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchImdbTitle(
                                context,
                                imdbId: showDetail.imdbId!,
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

  Future<void> _handleFollowPerson(dynamic member, WidgetRef ref) async {
    try {
      final contributorLogic = ref.read(contributorLogicProvider);
      final repo = ref.read(contributorRepositoryProvider);
      
      // Determine knownFor based on member type (CastMember vs CrewMember)
      String knownFor = '';
      if (member is CastMember) {
        knownFor = 'Actor';
      } else if (member is CrewMember) {
        // For crew, use their primary department as knownFor
        knownFor = member.department;
      }
      
      final sparseContributor = Contributor(
        tmdbId: member.tmdbId,
        name: member.name,
        type: ContributorType.person,
        profilePath: member.profilePath,
        notifyForDepartments: [],
        availableDepartments: [],
        knownFor: knownFor,
      );

      final availableDepts = await contributorLogic.getAvailableDepartments(sparseContributor);
      
      if (!mounted) return;

      final success = await contributorLogic.addEnrichedContributor(
        sparseContributor,
        overrideAvailableDepts: availableDepts,
      );

      // Always invalidate TV show detail to refresh isFollowed status
      if (mounted) {
        ref.invalidate(tvShowDetailProvider(widget.showId));
      }

      if (success && mounted) {
        ref.invalidate(contributorsProvider);
        
        final prefs = ref.read(preferencesRepositoryProvider).getPreferences();
        final selectedDepts = availableDepts
            .where((d) => prefs.effectiveDefaultDepartments.contains(d) || d == knownFor)
            .toList();

        showSuccessSnackBar(
          context,
          contributor: sparseContributor,
          roles: selectedDepts,
          availableRoles: availableDepts,
          onChange: () async {
            // Show the department selection dialog
            if (mounted) {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => DepartmentSelectionDialog(
                  name: sparseContributor.name,
                  availableDepartments: availableDepts,
                  initialSelectedDepartments: selectedDepts,
                  defaultDepartments: prefs.effectiveDefaultDepartments,
                  initialAllRolesSelected: false,
                  allowTrueAll: prefs.autoFollowNewRoles ?? true,
                ),
              );

              if (result != null && mounted) {
                final newRoles = result['roles'] as List<String>;
                
                // Fetch the actual contributor from the repository to preserve followedAt
                final existingContributor = ref.read(contributorRepositoryProvider).getContributor(sparseContributor.tmdbId);
                
                if (existingContributor != null) {
                  await contributorLogic.updateContributorRoles(existingContributor, newRoles);
                  ref.invalidate(contributorsProvider);
                  ref.invalidate(tvShowDetailProvider(widget.showId));
                  
                  if (mounted) {
                    showSimpleSnackBar(context, 'Updated ${sparseContributor.name} to follow ${newRoles.join(", ")}', duration: const Duration(seconds: 3));
                  }
                }
              }
            }
          },
        );
      } else if (mounted) {
        // Person already followed - show new snackbar with unfollow option
        showAlreadyFollowedSnackBar(
          context,
          contributorName: member.name,
          onUnfollow: () async {
            await repo.removeContributor(member.tmdbId);
            ref.invalidate(contributorsProvider);
            ref.invalidate(tvShowDetailProvider(widget.showId));
            
            if (mounted) {
              showRemovalSnackBar(
                context,
                message: 'Unfollowed ${member.name}',
                onUndo: () async {
                  final existingContributor = repo.getContributor(member.tmdbId);
                  if (existingContributor != null) {
                    await repo.addContributor(existingContributor);
                    ref.invalidate(contributorsProvider);
                    ref.invalidate(tvShowDetailProvider(widget.showId));
                  }
                },
              );
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error following person: $e');
      if (mounted) {
        showSimpleSnackBar(context, 'Error: $e');
      }
    }
  }
}

// Local _ContributorHoverCircle removed. Using common/contributor_hover_card.dart
