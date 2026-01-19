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
import '../../core/crew_constants.dart';

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
      splitByStage: false,
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
      splitByStage: false,
    );
  }

  Widget _buildUpcomingWorksSection(Preferences prefs, ContributorDetail? detail) {
    final List<Work> upcomingWorks = _filterByFollowedRoles(detail?.upcomingWorks ?? []); 
    
    if (upcomingWorks.isEmpty) {
      return _buildPlaceholderContent('Upcoming works will appear here');
    }
    
    // Sort by: 1) Poster presence (has poster first), 2) Popularity (descending)
    final sortedWorks = List<Work>.from(upcomingWorks)..sort((a, b) {
      // First: poster presence (has poster = true comes first)
      final aHasPoster = a.posterPath != null && a.posterPath!.isNotEmpty;
      final bHasPoster = b.posterPath != null && b.posterPath!.isNotEmpty;
      
      if (aHasPoster != bHasPoster) {
        return aHasPoster ? -1 : 1; // Has poster comes first
      }
      
      // Second: popularity (descending - higher popularity first)
      final aPopularity = a.popularity ?? 0.0;
      final bPopularity = b.popularity ?? 0.0;
      return bPopularity.compareTo(aPopularity);
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
    debugPrint('[ContributorDetailScreen] === _onWorkTapped CALLED ===');
    debugPrint('[ContributorDetailScreen] work.type: ${work.type}');
    debugPrint('[ContributorDetailScreen] work.title: "${work.title}"');
    debugPrint('[ContributorDetailScreen] work.showName: "${work.showName}"');
    debugPrint('[ContributorDetailScreen] work.showId: ${work.showId}');
    debugPrint('[ContributorDetailScreen] work.seasonNumber: ${work.seasonNumber}');
    debugPrint('[ContributorDetailScreen] work.episodeNumber: ${work.episodeNumber}');
    
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
      debugPrint('[ContributorDetailScreen] === EPISODE NAVIGATION DEBUG ===');
      debugPrint('[ContributorDetailScreen] work.title: "${work.title}"');
      debugPrint('[ContributorDetailScreen] work.showName: "${work.showName}"');
      debugPrint('[ContributorDetailScreen] work.showId: ${work.showId}');
      debugPrint('[ContributorDetailScreen] work.tmdbId: ${work.tmdbId}');
      debugPrint('[ContributorDetailScreen] work.seasonNumber: ${work.seasonNumber}');
      debugPrint('[ContributorDetailScreen] work.episodeNumber: ${work.episodeNumber}');
      
      final finalShowId = work.showId ?? work.tmdbId;
      
      // Extract show name: prefer work.showName, otherwise extract from episode title
      String finalShowName = work.showName ?? '';
      if (finalShowName.isEmpty) {
        // Episode title format is typically "Show Name - S##E## - Episode Name"
        // Extract just the show name (everything before the first " - ")
        final dashIndex = work.title.indexOf(' - ');
        if (dashIndex > 0) {
          finalShowName = work.title.substring(0, dashIndex).trim();
        } else {
          finalShowName = work.title;
        }
      }
      
      debugPrint('[ContributorDetailScreen] FINAL showId: $finalShowId');
      debugPrint('[ContributorDetailScreen] FINAL showName: "$finalShowName"');
      debugPrint('[ContributorDetailScreen] Navigating to TvEpisodeDetailScreen...');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvEpisodeDetailScreen(
            showId: finalShowId,
            seasonNumber: work.seasonNumber ?? 1,
            episodeNumber: work.episodeNumber ?? 1,
            showName: finalShowName,
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
            final hasImdbId = widget.contributor.imdbId != null && widget.contributor.imdbId!.isNotEmpty;
            
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
                          message: 'View ${widget.contributor.name} on TMDB',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchTmdbPerson(
                                context,
                                tmdbId: widget.contributor.tmdbId,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
                          message: 'View ${widget.contributor.name} on IMDb',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => ExternalNavigationUtils.launchImdbPerson(
                                context,
                                imdbId: widget.contributor.imdbId!,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
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

    // Organize roles by Stage 1, Stage 2, then others
    final stage1Roles = <String>[];
    final stage2Roles = <String>[];
    final otherRoles = <String>[];
    
    for (final role in roles) {
      // Check if it's a crew role (Stage 1 or Stage 2)
      bool isStage1 = false;
      bool isStage2 = false;
      
      // Check all departments for Stage 1/Stage 2
      for (final dept in ['Directing', 'Writing', 'Production', 'Sound']) {
        if (CrewConstants.isStage1(dept, role)) {
          isStage1 = true;
          break;
        }
        if (CrewConstants.isStage2(dept, role)) {
          isStage2 = true;
          break;
        }
      }
      
      if (isStage1) {
        stage1Roles.add(role);
      } else if (isStage2) {
        stage2Roles.add(role);
      } else {
        otherRoles.add(role);
      }
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
        // Stage 1 roles
        if (stage1Roles.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: stage1Roles.map((role) => _buildRoleChip(role, Theme.of(context).colorScheme.secondary)).toList(),
          ),
          const SizedBox(height: 4),
        ],
        // Stage 2 roles
        if (stage2Roles.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: stage2Roles.map((role) => _buildRoleChip(role, Theme.of(context).colorScheme.tertiary)).toList(),
          ),
          const SizedBox(height: 4),
        ],
        // Other roles (cast, etc.)
        if (otherRoles.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: otherRoles.map((role) => _buildRoleChip(role, Theme.of(context).colorScheme.outline)).toList(),
          ),
        ],
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
