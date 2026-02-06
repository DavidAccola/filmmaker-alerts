import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/episode_status_entry.dart';
import '../../data/models/season_status_entry.dart';
import '../../data/models/status_record.dart';
import '../../data/models/tv_detail.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/streaming_options_widget.dart';
import '../common/expand_poster_button.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/notification_prefs_chips.dart';
import 'tv_show_detail_screen.dart';

class ShowConfigurationScreen extends ConsumerStatefulWidget {
  final int showId;
  final String showTitle;

  const ShowConfigurationScreen({
    super.key,
    required this.showId,
    required this.showTitle,
  });

  @override
  ConsumerState<ShowConfigurationScreen> createState() =>
      _ShowConfigurationScreenState();
}

class _ShowConfigurationScreenState
    extends ConsumerState<ShowConfigurationScreen> {
  // Track pending changes: Map<seasonNumber, Map<episodeNumber, Set<WatchStatus>>>
  // Empty set means "clear all statuses", non-empty set means "these statuses are active"
  final Map<int, Map<int, Set<WatchStatus>>> _pendingChanges = {};

  // Track which seasons are expanded in the UI
  final Set<int> _expandedSeasons = {};

  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  bool _isDirty = false;
  bool _isPosterHovered = false;
  
  // Track if we've already checked for auto-expand (to avoid re-expanding after user collapses)
  bool _hasCheckedAutoExpand = false;

  // Undo/Redo history stacks
  final List<Map<int, Map<int, Set<WatchStatus>>>> _undoStack = [];
  final List<Map<int, Map<int, Set<WatchStatus>>>> _redoStack = [];
  
  /// Creates a deep copy of the pending changes map for history tracking.
  Map<int, Map<int, Set<WatchStatus>>> _copyPendingChanges() {
    final copy = <int, Map<int, Set<WatchStatus>>>{};
    for (final entry in _pendingChanges.entries) {
      copy[entry.key] = <int, Set<WatchStatus>>{};
      for (final epEntry in entry.value.entries) {
        copy[entry.key]![epEntry.key] = Set<WatchStatus>.from(epEntry.value);
      }
    }
    return copy;
  }
  
  /// Saves the current state to the undo stack before making changes.
  void _saveToUndoStack() {
    _undoStack.add(_copyPendingChanges());
    _redoStack.clear(); // Clear redo stack when new action is performed
  }
  
  /// Undoes the last change.
  void _undo() {
    if (_undoStack.isEmpty) return;
    
    setState(() {
      // Save current state to redo stack
      _redoStack.add(_copyPendingChanges());
      
      // Restore previous state
      final previousState = _undoStack.removeLast();
      _pendingChanges.clear();
      for (final entry in previousState.entries) {
        _pendingChanges[entry.key] = entry.value;
      }
      
      _isDirty = _undoStack.isNotEmpty;
    });
  }
  
  /// Redoes the last undone change.
  void _redo() {
    if (_redoStack.isEmpty) return;
    
    setState(() {
      // Save current state to undo stack
      _undoStack.add(_copyPendingChanges());
      
      // Restore next state
      final nextState = _redoStack.removeLast();
      _pendingChanges.clear();
      for (final entry in nextState.entries) {
        _pendingChanges[entry.key] = entry.value;
      }
      
      _isDirty = true;
    });
  }

  // ============================================================
  // Tri-State Checkbox Helper Functions
  // ============================================================
  // These helpers compute checkbox states for hierarchical selection:
  // - true = all items checked
  // - false = no items checked  
  // - null = indeterminate (some items checked)
  // ============================================================

  /// Gets the effective statuses for an episode, checking pending changes first,
  /// then falling back to the existing persisted statuses.
  /// 
  /// Returns empty set if no statuses exist (neither pending nor persisted).
  Set<WatchStatus> _getEffectiveEpisodeStatuses(int seasonNumber, int episodeNumber) {
    // Check pending changes first
    if (_pendingChanges.containsKey(seasonNumber) &&
        _pendingChanges[seasonNumber]!.containsKey(episodeNumber)) {
      return _pendingChanges[seasonNumber]![episodeNumber]!;
    }
    
    // Fall back to existing persisted statuses
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);
    final episode = episodeRepo.getEpisode(widget.showId, seasonNumber, episodeNumber);
    if (episode != null && episode.statusRecords.isNotEmpty) {
      return episode.statusRecords.map((r) => r.status).toSet();
    }
    
    return {};
  }

  /// Gets the count of each status type for episodes in a season.
  /// Returns a map of WatchStatus to count, only including statuses with count > 0.
  Map<WatchStatus, int> _getSeasonStatusCounts(int seasonNumber, List<EpisodeStatusEntry> episodes) {
    final counts = <WatchStatus, int>{};
    
    for (final episode in episodes) {
      final statuses = _getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber);
      for (final status in statuses) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  /// Computes the checkbox state for the entire show based on all episodes.
  /// 
  /// Returns:
  /// - true if ALL episodes across all seasons have a status
  /// - false if NO episodes have a status
  /// - null if SOME episodes have a status (indeterminate)
  bool? _computeShowCheckboxState(Map<int, List<EpisodeStatusEntry>> episodesBySeason) {
    int totalEpisodes = 0;
    int markedEpisodes = 0;
    for (final entry in episodesBySeason.entries) {
      final seasonNumber = entry.key;
      final episodes = entry.value;
      
      for (final episode in episodes) {
        totalEpisodes++;
        if (_getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber).isNotEmpty) {
          markedEpisodes++;
        }
      }
    }
    
    if (totalEpisodes == 0) return false;
    if (markedEpisodes == 0) return false;
    if (markedEpisodes == totalEpisodes) return true;
    return null; // indeterminate - some but not all are marked
  }

  @override
  void initState() {
    super.initState();
    _initializeLocalChanges();
    _fetchShowEpisodes();
  }

  Future<void> _fetchShowEpisodes() async {
    try {
      final workLogic = ref.read(workLogicProvider);
      
      // Fetch show details which includes seasons
      final showDetail = await workLogic.fetchAndCacheTvShowDetail(widget.showId);
      
      if (showDetail != null) {
        // Fetch all episodes for all seasons
        for (final season in showDetail.seasons) {
          await workLogic.fetchAndCacheTvSeasonDetail(
            showId: widget.showId,
            seasonNumber: season.seasonNumber,
          );
        }
      }
      
      // Refresh the UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[ShowConfigurationScreen] Error fetching episodes: $e');
    }
  }

  void _initializeLocalChanges() {
    // Load existing statuses from repositories
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);

    final episodes = episodeRepo.getEpisodesByShow(widget.showId);

    // Initialize pending changes from existing data
    for (final episode in episodes) {
      if (!_pendingChanges.containsKey(episode.seasonNumber)) {
        _pendingChanges[episode.seasonNumber] = {};
      }

      // Get all statuses from the episode
      if (episode.statusRecords.isNotEmpty) {
        _pendingChanges[episode.seasonNumber]![episode.episodeNumber] =
            episode.statusRecords.map((r) => r.status).toSet();
      }
    }
  }

  /// Auto-expands seasons based on marked episodes:
  /// - If no episodes are marked anywhere, expand Season 1
  /// - If only one season has marked episodes, expand that season
  /// Only runs once on initial load to avoid overriding user's collapse action.
  void _autoExpandSeason1IfEmpty(Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap) {
    if (_hasCheckedAutoExpand) return;
    _hasCheckedAutoExpand = true;
    
    // Find which seasons have any marked episodes
    final seasonsWithMarks = <int>{};
    for (final entry in episodesBySeasonMap.entries) {
      final seasonNumber = entry.key;
      final episodes = entry.value;
      
      for (final episode in episodes) {
        if (_getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber).isNotEmpty) {
          seasonsWithMarks.add(seasonNumber);
          break; // Found a mark in this season, move to next
        }
      }
    }
    
    if (seasonsWithMarks.isEmpty) {
      // Nothing is marked - expand Season 1 if it exists
      if (episodesBySeasonMap.containsKey(1)) {
        _expandedSeasons.add(1);
      }
    } else if (seasonsWithMarks.length == 1) {
      // Only one season has marks - expand that season
      _expandedSeasons.add(seasonsWithMarks.first);
    }
    // If multiple seasons have marks, don't auto-expand any
  }

  @override
  Widget build(BuildContext context) {
    final tvDetailRepo = ref.watch(tvDetailRepositoryProvider);
    final episodeRepo = ref.watch(episodeStatusRepositoryProvider);
    final seasonRepo = ref.watch(seasonStatusRepositoryProvider);

    // Get the cached show details
    final showDetail = tvDetailRepo.getTvShowDetail(widget.showId);
    
    if (showDetail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.showTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get marked episodes from status repository
    final markedEpisodes = episodeRepo.getEpisodesByShow(widget.showId);
    final markedSeasons = seasonRepo.getSeasonsByShow(widget.showId);

    // Group marked episodes by season for quick lookup
    final markedEpisodesBySeasonAndNumber = <int, Map<int, EpisodeStatusEntry>>{};
    for (final episode in markedEpisodes) {
      if (!markedEpisodesBySeasonAndNumber.containsKey(episode.seasonNumber)) {
        markedEpisodesBySeasonAndNumber[episode.seasonNumber] = {};
      }
      markedEpisodesBySeasonAndNumber[episode.seasonNumber]![episode.episodeNumber] = episode;
    }

    // Convert cached show detail seasons to SeasonStatusEntry for display
    final seasons = showDetail.seasons
        .map((season) => SeasonStatusEntry(
          showId: widget.showId,
          seasonNumber: season.seasonNumber,
          statusRecords: markedSeasons
              .where((s) => s.seasonNumber == season.seasonNumber)
              .expand((s) => s.statusRecords)
              .toList(),
        ))
        .toList();

    // Convert cached episodes to EpisodeStatusEntry for display
    final episodesBySeasonMap = <int, List<EpisodeStatusEntry>>{};
    for (final season in showDetail.seasons) {
      // Get the season detail which contains episodes
      final seasonDetail = tvDetailRepo.getTvSeasonDetail(widget.showId, season.seasonNumber);
      
      if (seasonDetail != null) {
        episodesBySeasonMap[season.seasonNumber] = seasonDetail.episodes
            .map((episode) {
              final markedEpisode = markedEpisodesBySeasonAndNumber[season.seasonNumber]?[episode.episodeNumber];
              return EpisodeStatusEntry(
                showId: widget.showId,
                seasonNumber: season.seasonNumber,
                episodeNumber: episode.episodeNumber,
                episodeTitle: episode.name,
                statusRecords: markedEpisode?.statusRecords ?? [],
              );
            })
            .toList();
      } else {
        episodesBySeasonMap[season.seasonNumber] = [];
      }
    }

    // Sort seasons: numbered seasons first (1, 2, 3...), then Specials (season 0) at the end
    final sortedSeasons = seasons.toList()
      ..sort((a, b) {
        // Season 0 (Specials) goes to the end
        if (a.seasonNumber == 0 && b.seasonNumber != 0) return 1;
        if (b.seasonNumber == 0 && a.seasonNumber != 0) return -1;
        return a.seasonNumber.compareTo(b.seasonNumber);
      });
    
    // Auto-expand Season 1 if nothing is marked in any season
    _autoExpandSeason1IfEmpty(episodesBySeasonMap);

    // Compute show-level checkbox state
    final showCheckboxState = _computeShowCheckboxState(episodesBySeasonMap);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isDirty && mounted) {
          await _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.showTitle),
          actions: [
            // Undo button
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.isNotEmpty ? _undo : null,
              tooltip: 'Undo',
            ),
            // Redo button
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: 'Redo',
            ),
            if (_selectedFilters.length < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Chip(
                    label: const Text('Filtered'),
                    onDeleted: () {
                      setState(() {
                        _selectedFilters = {
                          WatchStatus.wantToWatch,
                          WatchStatus.inProgress,
                          WatchStatus.watched,
                          WatchStatus.dnf,
                        };
                      });
                    },
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter',
            ),
          ],
        ),
        body: Column(
          children: [
            // Show metadata header (like TV detail screen)
            _buildMetadataHeader(showDetail),
            // Show-level "Mark All" row
            _buildMarkAllRow(showCheckboxState, episodesBySeasonMap),
            // Expandable list content
            Expanded(
              child: _buildExpandableList(sortedSeasons, episodesBySeasonMap),
            ),
          ],
        ),
        floatingActionButton: _isDirty
            ? FloatingActionButton(
                onPressed: _handleSave,
                tooltip: 'Save',
                child: const Icon(Icons.check),
              )
            : null,
      ),
    );
  }

  /// Builds the metadata header with poster, title, year, status, and streaming options.
  Widget _buildMetadataHeader(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(preferencesProvider);
    final prefs = prefsAsync.whenOrNull(data: (p) => p);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 600;
          
          if (isWideScreen) {
            // Wide screen: poster + info on left, streaming on right
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Poster and basic info
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPoster(showDetail),
                      const SizedBox(width: 16),
                      Expanded(child: _buildShowInfo(showDetail)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Right side: Streaming options
                SizedBox(
                  width: 350,
                  child: StreamingOptionsWidget(
                    streamingOptions: showDetail.streamingOptions,
                    tmdbId: showDetail.tmdbId,
                    isTV: true,
                    isCompact: true,
                    locale: prefs?.streamingCountry ?? 'US',
                    title: showDetail.name,
                    releaseDate: showDetail.firstAirDate,
                  ),
                ),
              ],
            );
          } else {
            // Narrow screen: stacked layout with streaming below
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPoster(showDetail),
                    const SizedBox(width: 16),
                    Expanded(child: _buildShowInfo(showDetail)),
                  ],
                ),
                const SizedBox(height: 12),
                // Streaming options below on narrow screens
                StreamingOptionsWidget(
                  streamingOptions: showDetail.streamingOptions,
                  tmdbId: showDetail.tmdbId,
                  isTV: true,
                  isCompact: true,
                  locale: prefs?.streamingCountry ?? 'US',
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

  void _navigateToShowDetails(TvShowDetail showDetail) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TvShowDetailScreen(
          showId: showDetail.tmdbId,
          showTitle: showDetail.name,
        ),
      ),
    );
  }

  Widget _buildPoster(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isPosterHovered = true),
      onExit: (_) => setState(() => _isPosterHovered = false),
      child: GestureDetector(
        onTap: () => _navigateToShowDetails(showDetail),
        child: SizedBox(
          width: 100,
          height: 150,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
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
    );
  }

  Widget _buildShowInfo(TvShowDetail showDetail) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(preferencesProvider);
    final prefs = prefsAsync.whenOrNull(data: (p) => p);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title - clickable to navigate to show details
        GestureDetector(
          onTap: () => _navigateToShowDetails(showDetail),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AdaptiveTooltipText(
              showDetail.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Years and Status
        Row(
          children: [
            Text(
              _formatYearRange(showDetail),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (showDetail.status != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
              Text(
                showDetail.status!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        
        // Seasons and Episodes count - clickable to navigate to show details
        if (showDetail.numberOfSeasons != null)
          GestureDetector(
            onTap: () => _navigateToShowDetails(showDetail),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${showDetail.numberOfSeasons} Season${showDetail.numberOfSeasons == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (showDetail.numberOfEpisodes != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('•', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    Text(
                      '${showDetail.numberOfEpisodes} Episodes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 8),
        
        // Rating
        if (showDetail.tmdbRating != null && 
            (showDetail.voteCount ?? 0) > 0 && 
            !(prefs?.hideRatingsInDetails ?? false))
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                showDetail.tmdbRating!.toStringAsFixed(1),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        
        // Notification preferences chips
        const SizedBox(height: 8),
        NotificationPrefsChips(
          tmdbId: showDetail.tmdbId,
          workType: WorkType.tvShow,
        ),
      ],
    );
  }

  String _formatYearRange(TvShowDetail showDetail) {
    if (showDetail.firstAirDate == null) return 'Unknown';
    final startYear = showDetail.firstAirDate!.year.toString();
    
    if (showDetail.status?.toLowerCase() == 'ended' || 
        showDetail.status?.toLowerCase() == 'canceled') {
      final endYear = showDetail.lastAirDate?.year.toString() ?? '?';
      return '$startYear–$endYear';
    }
    return '$startYear–Present';
  }

  /// Builds the show-level "Mark All" row with status buttons.
  Widget _buildMarkAllRow(
    bool? showCheckboxState,
    Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap,
  ) {
    final theme = Theme.of(context);
    
    return _HoverableRow(
      child: (isHovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isHovered 
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            // Status buttons for marking all episodes
            _buildMarkAllStatusButtons(episodesBySeasonMap, isHovered),
            const SizedBox(width: 12),
            Text(
              'Mark All Episodes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds status buttons for the "Mark All" row.
  Widget _buildMarkAllStatusButtons(Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap, bool isRowHovered) {
    // Count how many episodes have each status (episodes can have multiple statuses)
    final statusCounts = <WatchStatus, int>{};
    int totalEpisodes = 0;
    
    for (final entry in episodesBySeasonMap.entries) {
      for (final episode in entry.value) {
        totalEpisodes++;
        final statuses = _getEffectiveEpisodeStatuses(entry.key, episode.episodeNumber);
        for (final status in statuses) {
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
      }
    }
    
    // Helper to generate tooltip based on whether all episodes have the status
    String tooltipFor(WatchStatus status, String statusName) {
      final allHaveStatus = statusCounts[status] == totalEpisodes;
      return allHaveStatus ? 'Unmark all as $statusName' : 'Mark all as $statusName';
    }
    
    // Use fixedWidth: 28 to align with episode buttons (20px icon + 8px padding = 28px per button)
    return SizedBox(
      width: 112, // 4 buttons * 28px = 112px (same as episode row)
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EpisodeStatusButton(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            isActive: statusCounts[WatchStatus.wantToWatch] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.wantToWatch, 'Want to watch'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleMarkAllStatus(WatchStatus.wantToWatch, episodesBySeasonMap),
          ),
          _EpisodeStatusButton(
            icon: Icons.play_circle_outline,
            activeIcon: Icons.play_circle,
            isActive: statusCounts[WatchStatus.inProgress] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.inProgress, 'In progress'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleMarkAllStatus(WatchStatus.inProgress, episodesBySeasonMap),
          ),
          _EpisodeStatusButton(
            icon: Icons.check_circle_outline,
            activeIcon: Icons.check_circle,
            isActive: statusCounts[WatchStatus.watched] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.watched, 'Watched'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleMarkAllStatus(WatchStatus.watched, episodesBySeasonMap),
          ),
          _EpisodeStatusButton(
            icon: Icons.cancel_outlined,
            activeIcon: Icons.cancel,
            isActive: statusCounts[WatchStatus.dnf] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.dnf, 'Did not finish'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleMarkAllStatus(WatchStatus.dnf, episodesBySeasonMap),
          ),
        ],
      ),
    );
  }

  /// Handles marking all episodes with a specific status.
  /// Applies status transition rules:
  /// - In Progress → unmarks Want to Watch
  /// - Watched → unmarks Want to Watch and In Progress
  /// - Want to Watch → only unmarks DNF
  /// - DNF → unmarks everything
  void _handleMarkAllStatus(WatchStatus status, Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap) {
    _saveToUndoStack();
    
    setState(() {
      // Check if all episodes already have this status
      bool allHaveStatus = true;
      for (final entry in episodesBySeasonMap.entries) {
        for (final episode in entry.value) {
          final statuses = _getEffectiveEpisodeStatuses(entry.key, episode.episodeNumber);
          if (!statuses.contains(status)) {
            allHaveStatus = false;
            break;
          }
        }
        if (!allHaveStatus) break;
      }
      
      // If all have this status, remove it. Otherwise, add it (with conflict clearing).
      for (final entry in episodesBySeasonMap.entries) {
        final seasonNumber = entry.key;
        final episodes = entry.value;
        
        if (!_pendingChanges.containsKey(seasonNumber)) {
          _pendingChanges[seasonNumber] = {};
        }
        
        for (final episode in episodes) {
          // Get current statuses or initialize from persisted
          var currentStatuses = _pendingChanges[seasonNumber]![episode.episodeNumber];
          if (currentStatuses == null) {
            currentStatuses = Set<WatchStatus>.from(
              _getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber)
            );
          } else {
            currentStatuses = Set<WatchStatus>.from(currentStatuses);
          }
          
          if (allHaveStatus) {
            // Remove this status
            currentStatuses.remove(status);
          } else {
            // Add this status with conflict clearing
            _applyStatusTransitionRules(currentStatuses, status);
            currentStatuses.add(status);
          }
          
          _pendingChanges[seasonNumber]![episode.episodeNumber] = currentStatuses;
        }
      }
      _isDirty = true;
    });
  }

  /// Applies status transition rules to a set of statuses when adding a new status.
  void _applyStatusTransitionRules(Set<WatchStatus> statuses, WatchStatus newStatus) {
    switch (newStatus) {
      case WatchStatus.watched:
        // Watched clears In progress & Want to watch
        statuses.remove(WatchStatus.inProgress);
        statuses.remove(WatchStatus.wantToWatch);
        break;
      case WatchStatus.inProgress:
        // In progress clears Want to watch
        statuses.remove(WatchStatus.wantToWatch);
        break;
      case WatchStatus.wantToWatch:
        // Want to watch only clears DNF
        statuses.remove(WatchStatus.dnf);
        break;
      case WatchStatus.dnf:
        // DNF clears everything
        statuses.clear();
        break;
    }
  }  /// Builds the expandable list of seasons and episodes.
  Widget _buildExpandableList(
    List<SeasonStatusEntry> seasons,
    Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        final episodes = episodesBySeasonMap[season.seasonNumber] ?? [];
        final isExpanded = _expandedSeasons.contains(season.seasonNumber);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeasonItem(season, episodes, isExpanded),
            if (isExpanded)
              ...episodes.map((episode) => _buildEpisodeItem(episode)),
          ],
        );
      },
    );
  }

  /// Builds a season item row with status buttons, name, episode count, summary, and expand icon.
  Widget _buildSeasonItem(
    SeasonStatusEntry season,
    List<EpisodeStatusEntry> episodes,
    bool isExpanded,
  ) {
    final theme = Theme.of(context);
    final statusCounts = _getSeasonStatusCounts(season.seasonNumber, episodes);
    
    // Build status summary only if:
    // - Some episodes are marked (statusCounts not empty)
    // - AND not all episodes have the same single status
    final totalMarked = statusCounts.values.fold(0, (a, b) => a + b);
    final shouldShowSummary = statusCounts.isNotEmpty && 
        !(totalMarked == episodes.length && statusCounts.length == 1);
    
    return _HoverableRow(
      child: (isHovered) => Container(
        margin: const EdgeInsets.only(top: 2.0),
        decoration: BoxDecoration(
          color: isHovered 
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSeasons.remove(season.seasonNumber);
                } else {
                  _expandedSeasons.add(season.seasonNumber);
                }
              });
            },
            child: Padding(
              // Left padding is 13px (16 - 3px border) to align with Mark All and episode rows
              padding: const EdgeInsets.only(left: 13.0, right: 16.0, top: 6.0, bottom: 6.0),
              child: Row(
                children: [
                  // Status buttons for season
                  _buildSeasonStatusButtons(season.seasonNumber, episodes, isHovered),
                  const SizedBox(width: 8),
                  // Season name, episode count, and status summary - wraps if needed
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              season.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${episodes.length} episodes)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        // Status summary (icons with counts) - wraps to next line if needed
                        if (shouldShowSummary)
                          _buildStatusSummary(statusCounts),
                      ],
                    ),
                  ),
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds status buttons for a season row.
  Widget _buildSeasonStatusButtons(int seasonNumber, List<EpisodeStatusEntry> episodes, bool isRowHovered) {
    // Count how many episodes have each status
    final statusCounts = _getSeasonStatusCounts(seasonNumber, episodes);
    final totalEpisodes = episodes.length;
    
    // Helper to generate tooltip based on whether all episodes have the status
    String tooltipFor(WatchStatus status, String statusName) {
      final allHaveStatus = statusCounts[status] == totalEpisodes;
      return allHaveStatus ? 'Unmark season as $statusName' : 'Mark season as $statusName';
    }
    
    // Use fixedWidth: 28 to align with episode buttons (20px icon + 8px padding = 28px per button)
    return SizedBox(
      width: 112, // 4 buttons * 28px = 112px (same as episode row)
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EpisodeStatusButton(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            isActive: statusCounts[WatchStatus.wantToWatch] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.wantToWatch, 'Want to watch'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleSeasonStatusTap(seasonNumber, episodes, WatchStatus.wantToWatch),
          ),
          _EpisodeStatusButton(
            icon: Icons.play_circle_outline,
            activeIcon: Icons.play_circle,
            isActive: statusCounts[WatchStatus.inProgress] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.inProgress, 'In progress'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleSeasonStatusTap(seasonNumber, episodes, WatchStatus.inProgress),
          ),
          _EpisodeStatusButton(
            icon: Icons.check_circle_outline,
            activeIcon: Icons.check_circle,
            isActive: statusCounts[WatchStatus.watched] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.watched, 'Watched'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleSeasonStatusTap(seasonNumber, episodes, WatchStatus.watched),
          ),
          _EpisodeStatusButton(
            icon: Icons.cancel_outlined,
            activeIcon: Icons.cancel,
            isActive: statusCounts[WatchStatus.dnf] == totalEpisodes,
            isRowHovered: isRowHovered,
            tooltip: tooltipFor(WatchStatus.dnf, 'Did not finish'),
            size: 26,
            fixedWidth: 28,
            onTap: () => _handleSeasonStatusTap(seasonNumber, episodes, WatchStatus.dnf),
          ),
        ],
      ),
    );
  }

  /// Handles tapping a status button for a season.
  void _handleSeasonStatusTap(int seasonNumber, List<EpisodeStatusEntry> episodes, WatchStatus status) {
    _saveToUndoStack();
    
    setState(() {
      // Check if all episodes already have this status
      bool allHaveStatus = true;
      for (final episode in episodes) {
        final statuses = _getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber);
        if (!statuses.contains(status)) {
          allHaveStatus = false;
          break;
        }
      }
      
      if (!_pendingChanges.containsKey(seasonNumber)) {
        _pendingChanges[seasonNumber] = {};
      }
      
      // If all have this status, remove it. Otherwise, add it (with conflict clearing).
      for (final episode in episodes) {
        // Get current statuses or initialize from persisted
        var currentStatuses = _pendingChanges[seasonNumber]![episode.episodeNumber];
        if (currentStatuses == null) {
          currentStatuses = Set<WatchStatus>.from(
            _getEffectiveEpisodeStatuses(seasonNumber, episode.episodeNumber)
          );
        } else {
          currentStatuses = Set<WatchStatus>.from(currentStatuses);
        }
        
        if (allHaveStatus) {
          // Remove this status
          currentStatuses.remove(status);
        } else {
          // Add this status with conflict clearing
          _applyStatusTransitionRules(currentStatuses, status);
          currentStatuses.add(status);
        }
        
        _pendingChanges[seasonNumber]![episode.episodeNumber] = currentStatuses;
      }
      _isDirty = true;
    });
  }

  /// Builds an episode item row with status buttons (shown on hover) and title.
  Widget _buildEpisodeItem(EpisodeStatusEntry episode) {
    final effectiveStatuses = _getEffectiveEpisodeStatuses(episode.seasonNumber, episode.episodeNumber);
    
    return _EpisodeRow(
      episode: episode,
      effectiveStatuses: effectiveStatuses,
      onStatusTap: _handleStatusButtonTap,
    );
  }

  /// Handles tapping a status button for an episode.
  /// If the episode already has this status, remove it. Otherwise, add it (with conflict clearing).
  void _handleStatusButtonTap(int seasonNumber, int episodeNumber, WatchStatus status) {
    _saveToUndoStack();
    
    setState(() {
      if (!_pendingChanges.containsKey(seasonNumber)) {
        _pendingChanges[seasonNumber] = {};
      }
      
      // Get current statuses or initialize from persisted
      var currentStatuses = _pendingChanges[seasonNumber]![episodeNumber];
      if (currentStatuses == null) {
        currentStatuses = Set<WatchStatus>.from(
          _getEffectiveEpisodeStatuses(seasonNumber, episodeNumber)
        );
      } else {
        currentStatuses = Set<WatchStatus>.from(currentStatuses);
      }
      
      if (currentStatuses.contains(status)) {
        // Already has this status - remove it
        currentStatuses.remove(status);
      } else {
        // Doesn't have this status - add it with conflict clearing
        _applyStatusTransitionRules(currentStatuses, status);
        currentStatuses.add(status);
      }
      
      _pendingChanges[seasonNumber]![episodeNumber] = currentStatuses;
      _isDirty = true;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Want to watch'),
                    value: _selectedFilters.contains(WatchStatus.wantToWatch),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFilters.add(WatchStatus.wantToWatch);
                        } else if (_selectedFilters.length > 1) {
                          _selectedFilters.remove(WatchStatus.wantToWatch);
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('In progress'),
                    value: _selectedFilters.contains(WatchStatus.inProgress),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFilters.add(WatchStatus.inProgress);
                        } else if (_selectedFilters.length > 1) {
                          _selectedFilters.remove(WatchStatus.inProgress);
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Watched'),
                    value: _selectedFilters.contains(WatchStatus.watched),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFilters.add(WatchStatus.watched);
                        } else if (_selectedFilters.length > 1) {
                          _selectedFilters.remove(WatchStatus.watched);
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Did not finish'),
                    value: _selectedFilters.contains(WatchStatus.dnf),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedFilters.add(WatchStatus.dnf);
                        } else if (_selectedFilters.length > 1) {
                          _selectedFilters.remove(WatchStatus.dnf);
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () {
                    this.setState(() {
                      // Update outer state
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final logic = ref.read(watchlistLogicProvider);
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);

    // Check for unreleased content
    bool hasUnreleased = false;

    // Save all pending changes
    for (final seasonEntry in _pendingChanges.entries) {
      final seasonNumber = seasonEntry.key;
      final episodes = seasonEntry.value;

      for (final episodeEntry in episodes.entries) {
        final episodeNumber = episodeEntry.key;
        final statuses = episodeEntry.value;

        // Check if unreleased
        final episode =
            episodeRepo.getEpisode(widget.showId, seasonNumber, episodeNumber);
        if (episode != null && !episode.isReleased && statuses.isNotEmpty) {
          hasUnreleased = true;
        }

        // First, clear all existing statuses for this episode
        await logic.removeStatusFromEpisode(
          widget.showId,
          seasonNumber,
          episodeNumber,
        );

        // Then add each status in the set
        for (final status in statuses) {
          await logic.addStatusToEpisode(
            widget.showId,
            seasonNumber,
            episodeNumber,
            status,
          );
        }
      }
    }

    // Show confirmation snackbar
    if (mounted) {
      showSimpleSnackBar(
        context,
        'Changes saved',
        duration: const Duration(seconds: 3),
      );

      if (hasUnreleased) {
        showUnreleasedWarningSnackBar(context, widget.showTitle);
      }
    }

    // Reset dirty flag
    setState(() {
      _isDirty = false;
    });

    // Invalidate providers to refresh data
    ref.invalidate(episodeStatusRepositoryProvider);
    ref.invalidate(seasonStatusRepositoryProvider);
  }

  /// Returns the icon for a given [WatchStatus].
  /// Uses the same icons as WatchlistCard for consistency.
  IconData _getStatusIcon(WatchStatus status) {
    switch (status) {
      case WatchStatus.wantToWatch:
        return Icons.bookmark;
      case WatchStatus.inProgress:
        return Icons.play_circle;
      case WatchStatus.watched:
        return Icons.check_circle;
      case WatchStatus.dnf:
        return Icons.cancel;
    }
  }

  /// Builds a compact status summary showing icons with counts.
  /// Example: "✓3 ▶2" for 3 watched and 2 in progress.
  Widget _buildStatusSummary(Map<WatchStatus, int> statusCounts) {
    final theme = Theme.of(context);
    
    // Sort by a consistent order: wantToWatch, inProgress, watched, dnf
    final orderedStatuses = [
      WatchStatus.wantToWatch,
      WatchStatus.inProgress,
      WatchStatus.watched,
      WatchStatus.dnf,
    ];
    
    final widgets = <Widget>[];
    for (final status in orderedStatuses) {
      final count = statusCounts[status];
      if (count != null && count > 0) {
        widgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status),
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 2),
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < widgets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          widgets[i],
        ],
      ],
    );
  }

  Future<void> _showUnsavedChangesDialog() async {
    if (!mounted) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('leave'),
            child: const Text('LEAVE WITHOUT SAVING'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('SAVE AND LEAVE'),
          ),
        ],
      ),
    );
    
    if (result == 'save') {
      await _handleSave();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (result == 'leave') {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    // 'cancel' or null - do nothing, stay on screen
  }
}

/// Episode row widget that shows status buttons (always visible, subtly faded when not active).
/// Has a hover highlight to make it easier to see which row you're on.
class _EpisodeRow extends StatefulWidget {
  final EpisodeStatusEntry episode;
  final Set<WatchStatus> effectiveStatuses;
  final void Function(int seasonNumber, int episodeNumber, WatchStatus status) onStatusTap;

  const _EpisodeRow({
    required this.episode,
    required this.effectiveStatuses,
    required this.onStatusTap,
  });

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episode = widget.episode;
    final effectiveStatuses = widget.effectiveStatuses;
    
    // Calculate the width of the status buttons area for consistent spacing
    // 4 buttons * (20px icon + 8px padding) = 112px
    const statusButtonsWidth = 112.0;
    // Fixed height to prevent layout shift on hover
    const rowHeight = 28.0;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: _isHovered 
            ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 2.0, bottom: 2.0),
        child: Row(
          children: [
            // Status buttons row - always visible (subtly when not hovered)
            SizedBox(
              width: statusButtonsWidth,
              height: rowHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EpisodeStatusButton(
                    icon: Icons.bookmark_border,
                    activeIcon: Icons.bookmark,
                    isActive: effectiveStatuses.contains(WatchStatus.wantToWatch),
                    isRowHovered: _isHovered,
                    tooltip: 'Want to watch',
                    onTap: () => widget.onStatusTap(episode.seasonNumber, episode.episodeNumber, WatchStatus.wantToWatch),
                  ),
                  _EpisodeStatusButton(
                    icon: Icons.play_circle_outline,
                    activeIcon: Icons.play_circle,
                    isActive: effectiveStatuses.contains(WatchStatus.inProgress),
                    isRowHovered: _isHovered,
                    tooltip: 'In progress',
                    onTap: () => widget.onStatusTap(episode.seasonNumber, episode.episodeNumber, WatchStatus.inProgress),
                  ),
                  _EpisodeStatusButton(
                    icon: Icons.check_circle_outline,
                    activeIcon: Icons.check_circle,
                    isActive: effectiveStatuses.contains(WatchStatus.watched),
                    isRowHovered: _isHovered,
                    tooltip: 'Watched',
                    onTap: () => widget.onStatusTap(episode.seasonNumber, episode.episodeNumber, WatchStatus.watched),
                  ),
                  _EpisodeStatusButton(
                    icon: Icons.cancel_outlined,
                    activeIcon: Icons.cancel,
                    isActive: effectiveStatuses.contains(WatchStatus.dnf),
                    isRowHovered: _isHovered,
                    tooltip: 'Did not finish',
                    onTap: () => widget.onStatusTap(episode.seasonNumber, episode.episodeNumber, WatchStatus.dnf),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Episode number and title
            Expanded(
              child: Text(
                'E${episode.episodeNumber.toString().padLeft(2, '0')} - ${episode.episodeTitle}',
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact status button for episode rows.
/// Shows unfocused/unselected until hovered, then highlights.
class _EpisodeStatusButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final bool isRowHovered;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double? fixedWidth; // If set, button will be centered in this fixed width

  const _EpisodeStatusButton({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.tooltip,
    this.isRowHovered = false,
    this.onTap,
    this.size = 20,
    this.fixedWidth,
  });

  @override
  State<_EpisodeStatusButton> createState() => _EpisodeStatusButtonState();
}

class _EpisodeStatusButtonState extends State<_EpisodeStatusButton> {
  bool _isHovered = false;

  // Base size for calculating consistent spacing
  static const double _baseSize = 20;
  static const double _basePadding = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine icon and color based on state:
    // - Active: filled icon, full primary color
    // - Hovered (not active): filled icon, lighter primary color
    // - Row hovered (not icon hovered, not active): outline icon, visible but not highlighted
    // - Default: outline icon, subtle/faded color
    final IconData icon;
    final Color color;
    
    if (widget.isActive) {
      // Active - filled icon, full primary color
      icon = widget.activeIcon;
      color = theme.colorScheme.primary;
    } else if (_isHovered) {
      // Hovered - filled icon, lighter primary color
      icon = widget.activeIcon;
      color = theme.colorScheme.primary.withValues(alpha: 0.6);
    } else if (widget.isRowHovered) {
      // Row is hovered but not this specific icon - show outline but not faded
      icon = widget.icon;
      color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    } else {
      // Default - outline icon, very subtle/faded
      icon = widget.icon;
      color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15);
    }
    
    // Build the icon with appropriate padding
    Widget iconWidget = GestureDetector(
      onTap: widget.onTap,
      child: Icon(
        icon,
        size: widget.size,
        color: color,
      ),
    );
    
    // If fixedWidth is set, center the icon in that width
    if (widget.fixedWidth != null) {
      iconWidget = SizedBox(
        width: widget.fixedWidth,
        child: Center(child: iconWidget),
      );
    } else {
      // Use padding-based sizing for episode buttons (default behavior)
      final sizeDiff = widget.size - _baseSize;
      final adjustedPadding = _basePadding - (sizeDiff / 2);
      iconWidget = Padding(
        padding: EdgeInsets.all(adjustedPadding.clamp(0, _basePadding)),
        child: iconWidget,
      );
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        child: iconWidget,
      ),
    );
  }
}

/// A simple wrapper widget that tracks hover state and passes it to a builder.
class _HoverableRow extends StatefulWidget {
  final Widget Function(bool isHovered) child;

  const _HoverableRow({required this.child});

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.child(_isHovered),
    );
  }
}
