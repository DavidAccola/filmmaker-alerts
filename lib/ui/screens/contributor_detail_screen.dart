import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import 'tv_episode_detail_screen.dart';
import '../../logic/work_sorting_logic.dart';
import '../../logic/tv_show_display_logic.dart';
import '../../logic/work_filtering_logic.dart';
import '../common/work_widget.dart';
import '../common/tv_show_credits_widget.dart';
import '../common/credit_expansion_section.dart';
import '../common/external_navigation_utils.dart';
import '../common/grouped_tv_show_widget.dart';
import '../common/shelf_with_arrows.dart';
import '../common/filter_toggle_widget.dart';
import 'package:collection/collection.dart';
import '../../core/tmdb_mapping.dart';

class ContributorDetailScreen extends ConsumerStatefulWidget {
  final Contributor contributor;

  const ContributorDetailScreen({
    super.key,
    required this.contributor,
  });

  @override
  ConsumerState<ContributorDetailScreen> createState() => _ContributorDetailScreenState();
}

class _ContributorDetailScreenState extends ConsumerState<ContributorDetailScreen> {
  // Track filter state for each section independently
  late bool _filterLatestReleases;
  late bool _filterBiggestHits;
  late String _lastFollowedRoles;

  @override
  void initState() {
    super.initState();
    // Initialize filter states to true (filtering enabled by default)
    _filterLatestReleases = true;
    _filterBiggestHits = true;
    _lastFollowedRoles = widget.contributor.notifyForDepartments.join(',');
    
    // Force a fresh check on screen load to ensure categorization is up to date
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(contributorLogicProvider).refreshContributorDetail(widget.contributor);
      if (mounted) {
        ref.invalidate(contributorDetailProvider(widget.contributor.tmdbId));
      }
    });
  }

  @override
  void didUpdateWidget(ContributorDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if followed roles have changed
    final currentRoles = widget.contributor.notifyForDepartments.join(',');
    if (currentRoles != _lastFollowedRoles) {
      _lastFollowedRoles = currentRoles;
      // Invalidate the provider to refresh the display
      ref.invalidate(contributorDetailProvider(widget.contributor.tmdbId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);
    final detailAsync = ref.watch(contributorDetailProvider(widget.contributor.tmdbId));
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contributor.name),
        actions: [
          prefsAsync.when(
            data: (prefs) => PopupMenuButton<String>(
              icon: const Icon(Icons.display_settings),
              tooltip: 'Display Settings',
              onSelected: (value) {
                if (value == 'toggle_ratings') {
                  _updatePreference('hideRatingsInDetails', !(prefs.hideRatingsInDetails ?? false));
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'toggle_ratings',
                  checked: !(prefs.hideRatingsInDetails ?? false),
                  child: const Text('Show Ratings'),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: prefsAsync.when(
        data: (prefs) => detailAsync.when(
          data: (detail) => _buildContent(prefs, detail),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading details: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildContent(Preferences prefs, ContributorDetail? detail) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          ui.PointerDeviceKind.mouse,
        },
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
             // Header with contributor info (now scrolls)
            _buildHeader(prefs),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Upcoming Works Section
                  _buildSection(
                    title: 'Upcoming',
                    icon: Icons.schedule,
                    child: (detail?.upcomingWorks?.isEmpty ?? true) && (detail?.allWorks?.isEmpty ?? true)
                        ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("Loading upcoming works...")))
                        : _buildUpcomingWorksSection(prefs, detail),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Latest Releases Section (includes filter toggle)
                  _buildLatestReleasesSection(prefs, detail),
                  
                  const SizedBox(height: 16),
                  
                  // Biggest Hits Section (includes filter toggle)
                  _buildBiggestHitsSection(prefs, detail),

                  const SizedBox(height: 16),

                  // Television Credits Section (integrates Shows Created)
                  _buildTvCreditsSection(prefs, detail),

                  const SizedBox(height: 16),

                  // Movie Credits Section
                  _buildMovieCreditsSection(prefs, detail),
                  
                  
                  const SizedBox(height: 24),
                  
                  // External Links
                  _buildExternalLinks(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(prefs) {
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
        children: [
          // Contributor info
          Row(
            children: [
              // Profile image
              Container(
                width: 60,
                height: 90,
                decoration: BoxDecoration(
                  color: widget.contributor.type == ContributorType.company
                      ? Colors.white
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: widget.contributor.profilePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w200${widget.contributor.profilePath}',
                          fit: widget.contributor.type == ContributorType.company
                              ? BoxFit.contain
                              : BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
                        ),
                      )
                    : const Icon(Icons.person, size: 40),
              ),
              
              const SizedBox(width: 16),
              
              // Name and type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contributor.knownFor,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Followed Roles Indicator
                    _buildFollowedRolesChips(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildTvShowCreatorSection(Preferences prefs, ContributorDetail? detail) {
    if (detail == null) return const SizedBox.shrink();

    // Pool from Hits and Latest, but only where role is creator
    final List<Work> allWorks = _filterByFollowedRoles(<Work>[
      ...(detail.biggestHits),
      ...(detail.latestReleases),
    ].toSet().toList());
    
    final tvCredits = TvShowDisplayLogic.separateTvShowCredits(allWorks);
    final creatorShows = tvCredits['shows'] ?? [];
    
    if (creatorShows.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final sortedShows = List<Work>.from(creatorShows)..sort((a, b) {
      if (a.releaseDate == null && b.releaseDate == null) return 0;
      if (a.releaseDate == null) return 1;
      if (b.releaseDate == null) return -1;
      return b.releaseDate!.compareTo(a.releaseDate!);
    });
    
    final sectionHeight = 310.0;

    return Column(
      children: [
        _buildSection(
          title: 'Shows Created',
          icon: Icons.create,
          child: ShelfWithArrows(
            height: sectionHeight,
            builder: (context, controller) => ListView.builder(
              controller: controller, // Injected controller
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sortedShows.length,
              itemBuilder: (context, index) {
                final show = sortedShows[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < sortedShows.length - 1 ? 12 : 0),
                  child: SizedBox(
                    width: 150,
                    child: WorkWidget(
                      work: show,
                      hideRatings: prefs.hideRatingsInDetails ?? false,
                      onTap: () => _onWorkTapped(show),
                      onAddToWatchlist: () => _onAddToWatchlist(show),
                      watchlistButtonPosition: WatchlistButtonPosition.topLeft,
                      showWatchlistOnHover: true,
                      showDateInPoster: true,
                      showRating: false,
                      showDate: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvCreditsSection(Preferences prefs, ContributorDetail? detail) {
    if (detail == null) return const SizedBox.shrink();
    final allWorks = detail.allWorks ?? [];
    if (allWorks.isEmpty) return const SizedBox.shrink();

    final tvWorks = allWorks.where((w) => w.type == WorkType.tvShow || w.type == WorkType.tvEpisode).toList();
    if (tvWorks.isEmpty) return const SizedBox.shrink();

    return CreditExpansionSection(
      title: 'Television Credits',
      icon: Icons.tv,
      works: tvWorks,
      hideRatings: prefs.hideRatingsInDetails ?? false,
      onWorkTap: (work) => _onWorkTapped(work),
      onAddToWatchlist: (work) => _onAddToWatchlist(work),
    );
  }

  Widget _buildMovieCreditsSection(Preferences prefs, ContributorDetail? detail) {
    if (detail == null) return const SizedBox.shrink();
    final allWorks = detail.allWorks ?? [];
    debugPrint('[ContributorDetailScreen] Building Movie Credits. allWorks count: ${allWorks.length}');
    if (allWorks.isEmpty) return const SizedBox.shrink();

    final movieWorks = allWorks.where((w) => w.type == WorkType.movie).toList();
    debugPrint('[ContributorDetailScreen] Found ${movieWorks.length} Movie works');
    if (movieWorks.isEmpty) return const SizedBox.shrink();

    return CreditExpansionSection(
      title: 'Movie Credits',
      icon: Icons.movie,
      works: movieWorks,
      hideRatings: prefs.hideRatingsInDetails ?? false,
      onWorkTap: (work) => _onWorkTapped(work),
      onAddToWatchlist: (work) => _onAddToWatchlist(work),
    );
  }

  Widget _buildUpcomingWorksSection(Preferences prefs, ContributorDetail? detail) {
    // TODO: Get actual contributor detail data from repository
    // For now, return placeholder with sorting logic ready
    final List<Work> upcomingWorks = _filterByFollowedRoles(detail?.upcomingWorks ?? []); 
    
    if (upcomingWorks.isEmpty) {
      return _buildPlaceholderContent('Upcoming works will appear here');
    }
    
    final sortedWorks = List<Work>.from(upcomingWorks)..sort((a, b) {
      if (a.releaseDate == null && b.releaseDate == null) return 0;
      if (a.releaseDate == null) return 1;
      if (b.releaseDate == null) return -1;
      return a.releaseDate!.compareTo(b.releaseDate!); // Upcoming: Chronological (Soonest first)
    });
    
    final sectionHeight = 310.0;

    return ShelfWithArrows(
      height: sectionHeight,
      builder: (context, controller) => ListView.builder(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sortedWorks.length,
        itemBuilder: (context, index) {
          final work = sortedWorks[index];
          return Padding(
            padding: EdgeInsets.only(right: index < sortedWorks.length - 1 ? 12 : 0),
            child: SizedBox(
              width: 150,
              child: WorkWidget(
                work: work,
                hideRatings: prefs.hideRatingsInDetails ?? false,
                onTap: () => _onWorkTapped(work),
                onAddToWatchlist: () => _onAddToWatchlist(work),
                watchlistButtonPosition: WatchlistButtonPosition.topLeft,
                showWatchlistOnHover: true,
                showDateInPoster: true,
                showRating: false,
                showDate: false,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestReleasesSection(Preferences prefs, ContributorDetail? detail) {
    final List<Work> rawReleases = detail?.latestReleases ?? [];
    
    if (rawReleases.isEmpty) {
      return _buildPlaceholderContent('Latest releases will appear here');
    }

    // Get the stored contributor to ensure we have the latest followed roles
    final repo = ref.read(contributorRepositoryProvider);
    final storedContributor = repo.getContributor(widget.contributor.tmdbId);
    final contributorForFiltering = storedContributor ?? widget.contributor;

    // Determine if filtering should be applied
    final shouldFilter = WorkFilteringLogic.shouldApplyFiltering(rawReleases, contributorForFiltering);
    final disabledReason = WorkFilteringLogic.getFilterDisabledReason(rawReleases, contributorForFiltering);
    final followedRolesList = WorkFilteringLogic.getFollowedRolesString(contributorForFiltering);
    
    // Check if filtering would make a difference
    final filteredWorks = WorkFilteringLogic.filterWorksByFollowedRoles(rawReleases, contributorForFiltering);
    final filterMakesDifference = filteredWorks.length != rawReleases.length;
    
    // Apply filtering if applicable and enabled
    List<Work> filteredReleases = rawReleases;
    if (shouldFilter && _filterLatestReleases) {
      filteredReleases = filteredWorks;
    } else if (shouldFilter && !_filterLatestReleases) {
      // User toggled to show all works
      filteredReleases = rawReleases;
    } else if (!shouldFilter && disabledReason != null) {
      // Filtering would be empty, show all works
      filteredReleases = rawReleases;
    }

    if (filteredReleases.isEmpty) {
      return _buildPlaceholderContent('Latest releases will appear here');
    }

    // Group TV episodes by show
    final List<Work> episodes = filteredReleases.where((w) => w.type == WorkType.tvEpisode).toList();
    final Map<String, List<Work>> grouped = TvShowDisplayLogic.groupEpisodesByShow(episodes);

    // Filter out TV shows from nonEpisodes if we already have episodes for them
    final List<Work> nonEpisodes = filteredReleases.where((w) {
      if (w.type != WorkType.tvShow) return w.type != WorkType.tvEpisode;
      // If it's a TV show, check if its title is already in the grouped episodes
      return !grouped.containsKey(w.title);
    }).toList();

    // Create mixed list of items (Work or Map representing grouped show)
    final List<dynamic> displayItems = [];
    displayItems.addAll(nonEpisodes);
    
    grouped.forEach((showTitle, eps) {
      // Sort episodes within group to ensure the first one is the latest
      final sortedGroup = List<Work>.from(eps)..sort((a, b) {
        if (a.releaseDate == null || b.releaseDate == null) return 0;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });
      
      // REQUIREMENT: Only show the "legit latest" episode in Latest Releases
      // Instead of the whole group, we just add the latest episode as a Work item
      displayItems.add(sortedGroup.first);
    });

    // Sort all display items by their most recent date
    displayItems.sort((a, b) {
      final DateTime? dateA = a is Work ? a.releaseDate : (a as Map)['episodes'].first.releaseDate;
      final DateTime? dateB = b is Work ? b.releaseDate : (b as Map)['episodes'].first.releaseDate;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    
    final sectionHeight = 310.0;

    // Only show filter toggle if filtering makes a difference
    Widget? filterToggle;
    if (filterMakesDifference) {
      filterToggle = FilterToggleWidget(
        isFiltered: _filterLatestReleases && shouldFilter,
        isApplicable: shouldFilter || disabledReason != null,
        onToggle: _toggleLatestReleasesFilter,
        disabledReason: disabledReason,
        followedRolesList: followedRolesList,
      );
    }
    
    return _buildSection(
      title: 'Latest Releases',
      icon: Icons.new_releases,
      filterToggle: filterToggle,
      child: ShelfWithArrows(
        height: sectionHeight,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(), // Ensure swiping works
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            
            return Padding(
              padding: EdgeInsets.only(right: index < displayItems.length - 1 ? 12 : 0),
              child: SizedBox(
                width: 150,
                child: WorkWidget(
                  work: item,
                  hideRatings: prefs.hideRatingsInDetails ?? false,
                  onTap: () => _onWorkTapped(item),
                  onAddToWatchlist: () => _onAddToWatchlist(item),
                  applyAgeStyling: true,
                  showRating: false,
                  showDate: false,
                  showDateInPoster: true,
                  watchlistButtonPosition: WatchlistButtonPosition.topLeft,
                  showWatchlistOnHover: true,
                  titleOverride: item.type == WorkType.tvEpisode ? TvShowDisplayLogic.extractShowTitle(item.title) : null,
                  hoverTitle: item.type == WorkType.tvEpisode ? TvShowDisplayLogic.formatEpisodeInfo(item) : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBiggestHitsSection(Preferences prefs, ContributorDetail? detail) {
    final List<Work> rawBiggestHits = detail?.biggestHits ?? [];
    
    if (rawBiggestHits.isEmpty) {
      return _buildPlaceholderContent('Biggest hits will appear here');
    }

    // Get the stored contributor to ensure we have the latest followed roles
    final repo = ref.read(contributorRepositoryProvider);
    final storedContributor = repo.getContributor(widget.contributor.tmdbId);
    final contributorForFiltering = storedContributor ?? widget.contributor;

    // Determine if filtering should be applied
    final shouldFilter = WorkFilteringLogic.shouldApplyFiltering(rawBiggestHits, contributorForFiltering);
    final disabledReason = WorkFilteringLogic.getFilterDisabledReason(rawBiggestHits, contributorForFiltering);
    final followedRolesList = WorkFilteringLogic.getFollowedRolesString(contributorForFiltering);
    
    // Check if filtering would make a difference
    final filteredWorks = WorkFilteringLogic.filterWorksByFollowedRoles(rawBiggestHits, contributorForFiltering);
    final filterMakesDifference = filteredWorks.length != rawBiggestHits.length;
    
    // Apply filtering if applicable and enabled
    List<Work> filteredHits = rawBiggestHits;
    if (shouldFilter && _filterBiggestHits) {
      filteredHits = filteredWorks;
    } else if (shouldFilter && !_filterBiggestHits) {
      // User toggled to show all works
      filteredHits = rawBiggestHits;
    } else if (!shouldFilter && disabledReason != null) {
      // Filtering would be empty, show all works
      filteredHits = rawBiggestHits;
    }

    if (filteredHits.isEmpty) {
      return _buildPlaceholderContent('Biggest hits will appear here');
    }
    
    // rankBiggestHits already returns works sorted by hit score (descending)
    final rankedWorks = WorkSortingLogic.rankBiggestHits(filteredHits);
    
    final sectionHeight = 310.0;

    // Only show filter toggle if filtering makes a difference
    Widget? filterToggle;
    if (filterMakesDifference) {
      filterToggle = FilterToggleWidget(
        isFiltered: _filterBiggestHits && shouldFilter,
        isApplicable: shouldFilter || disabledReason != null,
        onToggle: _toggleBiggestHitsFilter,
        disabledReason: disabledReason,
        followedRolesList: followedRolesList,
      );
    }
    
    return _buildSection(
      title: 'Biggest Hits',
      icon: Icons.star,
      filterToggle: filterToggle,
      child: ShelfWithArrows(
        height: sectionHeight,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: rankedWorks.length,
          itemBuilder: (context, index) {
            final work = rankedWorks[index];
            return Padding(
              padding: EdgeInsets.only(right: index < rankedWorks.length - 1 ? 12 : 0),
              child: SizedBox(
                width: 150,
                child: WorkWidget(
                  work: work,
                  hideRatings: prefs.hideRatingsInDetails ?? false,
                  onTap: () => _onWorkTapped(work),
                  onAddToWatchlist: () => _onAddToWatchlist(work),
                  showDateInPoster: false,
                  showRating: true,
                  showDate: false,
                  watchlistButtonPosition: WatchlistButtonPosition.topLeft,
                  showWatchlistOnHover: true,
                  titleOverride: work.type == WorkType.tvEpisode ? TvShowDisplayLogic.extractShowTitle(work.title) : null,
                  hoverTitle: work.type == WorkType.tvEpisode ? TvShowDisplayLogic.formatEpisodeInfo(work) : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onWorkTapped(Work work) {
    if (work.type == WorkType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailScreen(
            movieId: work.tmdbId,
            movieTitle: work.title,
          ),
        ),
      );
    } else if (work.type == WorkType.tvShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvShowDetailScreen(
            showId: work.tmdbId,
            showTitle: work.title,
          ),
        ),
      );
    } else if (work.type == WorkType.tvEpisode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvEpisodeDetailScreen(
            showId: work.showId ?? work.tmdbId, // Use showId, fallback to tmdbId (legacy/quick-creation)
            seasonNumber: work.seasonNumber ?? 1,
            episodeNumber: work.episodeNumber ?? 1,
            showName: work.title, // Actually show name in this context
          ),
        ),
      );
    }
  }

  void _onAddToWatchlist(Work work) {
    // TODO: Add work to watchlist
    debugPrint('Add to watchlist: ${work.title}');
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? filterToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (filterToggle != null) ...[
              const SizedBox(width: 8),
              filterToggle,
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildPlaceholderContent(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildExternalLinks() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ExternalNavigationUtils.launchTmdbPerson(
                context,
                tmdbId: widget.contributor.tmdbId,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('See all credits on TMDB'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.contributor.imdbId != null && widget.contributor.imdbId!.isNotEmpty
                ? () {
                    ExternalNavigationUtils.launchImdbPerson(
                      context,
                      imdbId: widget.contributor.imdbId!,
                    );
                  }
                : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('See all credits on IMDB'),
          ),
        ),
      ],
    );
  }

  Future<void> _launchTmdbUrl(BuildContext context) async {
    final url = 'https://www.themoviedb.org/person/${widget.contributor.tmdbId}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open TMDB page')),
        );
      }
    }
  }

  Future<void> _launchImdbUrl(BuildContext context) async {
    final imdbId = widget.contributor.imdbId;
    if (imdbId != null && imdbId.isNotEmpty) {
      final url = 'https://www.imdb.com/name/$imdbId/';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open IMDb page')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IMDb ID not available for this contributor')),
        );
      }
    }
  }

  String _getContributorTypeLabel(ContributorType type) {
    switch (type) {
      case ContributorType.person:
        return 'Person';
      case ContributorType.company:
        return 'Company';
      case ContributorType.collection:
        return 'Collection';
      case ContributorType.movie:
        return 'Movie';
      case ContributorType.tvShow:
        return 'TV Show';
    }
  }

  Widget _buildFollowedRolesChips() {
    final roles = widget.contributor.notifyForDepartments;
    final isTrueAll = widget.contributor.allRolesSelected ?? false;

    debugPrint('[ContributorDetail] Building followed roles chips for ${widget.contributor.name}');
    debugPrint('[ContributorDetail] notifyForDepartments: $roles');
    debugPrint('[ContributorDetail] allRolesSelected: $isTrueAll');
    debugPrint('[ContributorDetail] knownFor: ${widget.contributor.knownFor}');

    if (isTrueAll) {
      return Wrap(
        spacing: 4,
        children: [
          _buildRoleChip('Following All Roles', Theme.of(context).colorScheme.primary),
        ],
      );
    }

    if (roles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Followed roles:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: roles.map((role) => _buildRoleChip(role, Theme.of(context).colorScheme.secondary)).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Work> _filterByFollowedRoles(List<Work> works) {
    if (widget.contributor.type != ContributorType.person) {
      return works; // Only filter person contributors for now
    }

    // Check if contributor is actually followed
    final repo = ref.read(contributorRepositoryProvider);
    final storedContributor = repo.getContributor(widget.contributor.tmdbId);
    final isFollowed = storedContributor != null;

    // If not followed, show all works (don't filter)
    if (!isFollowed) {
      return works;
    }

    final isTrueAll = storedContributor.allRolesSelected ?? false;
    if (isTrueAll) return works;

    final followedRoles = storedContributor.notifyForDepartments;
    
    // If followed but no roles selected...
    if (followedRoles.isEmpty) {
        return [];
    }

    return works.where((work) {
      return work.contributorRoles.any((role) {
        final mappedRole = TmdbMapping.mapTmdbDeptToRole(role.department ?? '', job: role.role);
        return followedRoles.contains(mappedRole);
      });
    }).toList();
  }

  void _updatePreference(String key, bool value) async {
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final currentPrefs = prefsRepo.getPreferences();
    
    // Create updated preferences
    final updatedPrefs = Preferences(
      notifyTheatre: currentPrefs.notifyTheatre,
      notifyStreaming: currentPrefs.notifyStreaming,
      scheduleTime: currentPrefs.scheduleTime,
      defaultDepartments: currentPrefs.defaultDepartments,
      notifyPhysical: currentPrefs.notifyPhysical,
      notifyTV: currentPrefs.notifyTV,
      pretendToday: currentPrefs.pretendToday,
      includeCollectionsInMovieSearch: currentPrefs.includeCollectionsInMovieSearch,
      useGridView: currentPrefs.useGridView,
      homeSortOrder: currentPrefs.homeSortOrder,
      groupByType: currentPrefs.groupByType,
      allRolesSelected: currentPrefs.allRolesSelected,
      allReleaseTypesSelected: currentPrefs.allReleaseTypesSelected,
      autoFollowNewRoles: currentPrefs.autoFollowNewRoles,
      lastCheckTime: currentPrefs.lastCheckTime,
      lastViewedHistoryTime: currentPrefs.lastViewedHistoryTime,
      movieDetailsPreference: currentPrefs.movieDetailsPreference,
      defaultTvNotificationPrefs: currentPrefs.defaultTvNotificationPrefs,
      notifyPersonTvEpisodes: currentPrefs.notifyPersonTvEpisodes,
      useDarkMode: currentPrefs.useDarkMode,
      hidePopularityInDetails: key == 'hidePopularityInDetails' ? value : currentPrefs.hidePopularityInDetails,
      hideRatingsInDetails: key == 'hideRatingsInDetails' ? value : currentPrefs.hideRatingsInDetails,
      streamingCountry: currentPrefs.streamingCountry,
    );
    
    await prefsRepo.savePreferences(updatedPrefs);
    
    // Refresh the provider
    ref.invalidate(preferencesProvider);
  }

  void _toggleLatestReleasesFilter() {
    setState(() {
      _filterLatestReleases = !_filterLatestReleases;
    });
  }

  void _toggleBiggestHitsFilter() {
    setState(() {
      _filterBiggestHits = !_filterBiggestHits;
    });
  }
}
