import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/preferences.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/watchlist_card.dart';
import '../common/watchlist_rank_card.dart';
import '../common/snackbar_utils.dart';
import '../common/rewatch_dialog.dart';
import '../common/tmdb_attribution.dart';
import 'add_contributor_screen.dart';
import 'movie_detail_screen.dart';
import 'show_configuration_screen.dart';
import 'collection_configuration_screen.dart';

/// Lightweight snapshot of a single entry's rank for undo/redo.
class _RankSnapshot {
  final int tmdbId;
  final WorkType type;
  final int rank;
  const _RankSnapshot(this.tmdbId, this.type, this.rank);
}

enum WatchlistSortOption {
  addOrder,
  userRank,
  alphabetical,
  releaseDate,
}

class WatchlistScreen extends ConsumerStatefulWidget {
  final int? scrollToTmdbId;
  
  const WatchlistScreen({
    super.key,
    this.scrollToTmdbId,
  });

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _hasHiddenItems = false;
  int? _lastScrolledTmdbId; // Track which item we've already scrolled to
  
  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };
  
  // Show hidden items toggle
  bool _showHidden = false;

  // Sort state
  WatchlistSortOption _sortOption = WatchlistSortOption.userRank;
  bool _sortInitialized = false;

  // Undo/Redo stacks for rank changes
  // Each entry is a list of (tmdbId, type, rank) tuples representing the full rank order
  final List<List<_RankSnapshot>> _rankUndoStack = [];
  final List<List<_RankSnapshot>> _rankRedoStack = [];

  /// Helper to update FAB raised state via provider (shared with HomeScreen)
  void _setFabRaised(bool raised) {
    ref.read(fabRaisedProvider.notifier).setRaised(raised);
  }
  
  /// Check if we're in rank edit mode
  bool get _isRankEditMode => ref.read(rankEditModeProvider);
  
  /// Toggle rank edit mode
  void _setRankEditMode(bool editing) {
    ref.read(rankEditModeProvider.notifier).setEditMode(editing);
  }

  /// Takes a snapshot of current rank order for undo purposes.
  List<_RankSnapshot> _takeRankSnapshot(List<WatchlistEntry> entries) {
    return entries.asMap().entries.map((e) =>
      _RankSnapshot(e.value.tmdbId, e.value.type, e.key + 1),
    ).toList();
  }

  /// Saves current rank order to undo stack before making changes.
  void _saveRankToUndoStack(List<WatchlistEntry> entries) {
    _rankUndoStack.add(_takeRankSnapshot(entries));
    _rankRedoStack.clear();
  }

  /// Restores ranks from a snapshot.
  Future<void> _restoreRankSnapshot(List<_RankSnapshot> snapshot) async {
    final logic = ref.read(watchlistLogicProvider);
    for (final s in snapshot) {
      await logic.updateUserRank(s.tmdbId, s.type, s.rank);
    }
    ref.invalidate(watchlistEntriesProvider);
  }

  /// Undoes the last rank change.
  Future<void> _undoRank() async {
    if (_rankUndoStack.isEmpty) return;
    // We need current state for redo — get from provider
    final entries = await ref.read(watchlistEntriesProvider.future);
    final active = entries.where((e) => !e.isSnoozed).toList();
    final filtered = _filterEntries(active);
    final sorted = _sortEntries(filtered);
    _rankRedoStack.add(_takeRankSnapshot(sorted));
    final previous = _rankUndoStack.removeLast();
    await _restoreRankSnapshot(previous);
    if (mounted) setState(() {});
  }

  /// Redoes the last undone rank change.
  Future<void> _redoRank() async {
    if (_rankRedoStack.isEmpty) return;
    final entries = await ref.read(watchlistEntriesProvider.future);
    final active = entries.where((e) => !e.isSnoozed).toList();
    final filtered = _filterEntries(active);
    final sorted = _sortEntries(filtered);
    _rankUndoStack.add(_takeRankSnapshot(sorted));
    final next = _rankRedoStack.removeLast();
    await _restoreRankSnapshot(next);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTabController(bool hasHidden) {
    if (_hasHiddenItems != hasHidden && mounted) {
      _hasHiddenItems = hasHidden;
      try {
        _tabController.dispose();
      } catch (_) {
        // Ignore if already disposed
      }
      _tabController = TabController(
        length: hasHidden ? 2 : 1,
        vsync: this,
      );
    }
  }

  void _scrollToItem(List<WatchlistEntry> entries, int tmdbId) {
    // Find the index of the item with the given tmdbId
    final index = entries.indexWhere((e) => e.tmdbId == tmdbId);
    if (index == -1 || !_scrollController.hasClients) return;

    // Get the actual max scroll extent to better estimate positions
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Estimate the scroll position based on grid layout
    // Grid has columns with maxCrossAxisExtent: 150, childAspectRatio: 0.43
    // So each item is roughly 150 wide and 150/0.43 = ~349 tall
    const itemHeight = 349.0; // Height estimate for scroll calculation
    const spacing = 16.0;
    const padding = 16.0;
    const itemsPerRow = 2;

    final row = index ~/ itemsPerRow;
    final estimatedOffset = (row * (itemHeight + spacing)) + padding - 50; // 50px buffer from top

    // Delay the scroll to ensure the layout is complete and tab has switched
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || !_scrollController.hasClients) return;
      
      final targetOffset = estimatedOffset.clamp(0.0, maxScroll);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Convert WatchlistSortOption to String for persistence.
  String _sortOptionToString(WatchlistSortOption option) {
    switch (option) {
      case WatchlistSortOption.addOrder: return 'addOrder';
      case WatchlistSortOption.userRank: return 'userRank';
      case WatchlistSortOption.alphabetical: return 'alphabetical';
      case WatchlistSortOption.releaseDate: return 'releaseDate';
    }
  }

  /// Convert String to WatchlistSortOption for loading.
  WatchlistSortOption _sortOptionFromString(String? value) {
    switch (value) {
      case 'userRank': return WatchlistSortOption.userRank;
      case 'alphabetical': return WatchlistSortOption.alphabetical;
      case 'releaseDate': return WatchlistSortOption.releaseDate;
      case 'addOrder':
      default:
        return WatchlistSortOption.addOrder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistEntriesProvider);
    final prefsAsync = ref.watch(preferencesProvider);

    // Initialize sort option from saved preferences (once)
    if (!_sortInitialized && prefsAsync.hasValue) {
      _sortInitialized = true;
      final saved = prefsAsync.value?.watchlistSortOrder;
      if (saved != null) {
        _sortOption = _sortOptionFromString(saved);
      }
    }

    return watchlistAsync.when(
      data: (entries) {
        final hasHidden = entries.any((e) => e.isSnoozed);
        
        final activeEntries = entries.where((e) => !e.isSnoozed).toList();
        final hiddenEntries = entries.where((e) => e.isSnoozed).toList();
        
        // Update tab controller if hidden status changed (outside of build)
        if (_hasHiddenItems != hasHidden) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTabController(hasHidden);
            }
          });
        }

        // Scroll to newly added item if specified
        if (widget.scrollToTmdbId != null && widget.scrollToTmdbId != _lastScrolledTmdbId) {
          _lastScrolledTmdbId = widget.scrollToTmdbId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToItem(entries, widget.scrollToTmdbId!);
          });
        }

        // Calculate filtered count for badge
        final filteredActiveEntries = activeEntries.where((e) {
          final hasSelectedStatus = e.statusRecords.any((r) => _selectedFilters.contains(r.status));
          return hasSelectedStatus || e.statusRecords.isEmpty;
        }).toList();
        
        // Count items filtered out by status (using same logic as dialog)
        int statusFilteredCount = 0;
        for (final status in [WatchStatus.wantToWatch, WatchStatus.inProgress, WatchStatus.watched, WatchStatus.dnf]) {
          if (!_selectedFilters.contains(status)) {
            // Count items that have this status but aren't currently visible
            // because this filter is off AND they don't have any other selected status
            statusFilteredCount += activeEntries.where((entry) {
              final hasThisStatus = entry.statusRecords.any((r) => r.status == status);
              if (!hasThisStatus) return false;
              
              // Check if they have any other selected status
              final hasOtherSelectedStatus = entry.statusRecords.any((r) => 
                r.status != status && _selectedFilters.contains(r.status));
              
              return !hasOtherSelectedStatus;
            }).length;
          }
        }
        
        // Add hidden count if not showing hidden
        final hiddenCount = _showHidden ? 0 : hiddenEntries.length;
        final filteredOutCount = statusFilteredCount + hiddenCount;

        return Column(
          children: [
            // Toolbar with filter and sort options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Spacer(),
                  // Filter button with dropdown menu
                  PopupMenuButton<String>(
                    icon: Badge(
                      isLabelVisible: filteredOutCount > 0,
                      label: Text('$filteredOutCount'),
                      child: const Icon(Icons.filter_list),
                    ),
                    tooltip: 'Filter',
                    onSelected: (value) {
                      setState(() {
                        if (value == 'wantToWatch') {
                          if (_selectedFilters.contains(WatchStatus.wantToWatch)) {
                            if (_selectedFilters.length > 1) {
                              _selectedFilters.remove(WatchStatus.wantToWatch);
                            }
                          } else {
                            _selectedFilters.add(WatchStatus.wantToWatch);
                          }
                        } else if (value == 'inProgress') {
                          if (_selectedFilters.contains(WatchStatus.inProgress)) {
                            if (_selectedFilters.length > 1) {
                              _selectedFilters.remove(WatchStatus.inProgress);
                            }
                          } else {
                            _selectedFilters.add(WatchStatus.inProgress);
                          }
                        } else if (value == 'watched') {
                          if (_selectedFilters.contains(WatchStatus.watched)) {
                            if (_selectedFilters.length > 1) {
                              _selectedFilters.remove(WatchStatus.watched);
                            }
                          } else {
                            _selectedFilters.add(WatchStatus.watched);
                          }
                        } else if (value == 'dnf') {
                          if (_selectedFilters.contains(WatchStatus.dnf)) {
                            if (_selectedFilters.length > 1) {
                              _selectedFilters.remove(WatchStatus.dnf);
                            }
                          } else {
                            _selectedFilters.add(WatchStatus.dnf);
                          }
                        } else if (value == 'showHidden') {
                          _showHidden = !_showHidden;
                        }
                      });
                    },
                    itemBuilder: (context) {
                      // Calculate counts for each filter option
                      final activeEntries = entries.where((e) => !e.isSnoozed).toList();
                      final hiddenEntries = entries.where((e) => e.isSnoozed).toList();
                      
                      int countForStatus(WatchStatus status) {
                        if (_selectedFilters.contains(status)) {
                          return 0;
                        }
                        
                        // For "Want to Watch", also count items with no status records
                        if (status == WatchStatus.wantToWatch) {
                          return activeEntries.where((entry) {
                            // Items with no status are treated as "Want to Watch"
                            if (entry.statusRecords.isEmpty) {
                              return true;
                            }
                            
                            final hasThisStatus = entry.statusRecords.any((r) => r.status == status);
                            if (!hasThisStatus) return false;
                            final hasOtherSelectedStatus = entry.statusRecords.any((r) => 
                              r.status != status && _selectedFilters.contains(r.status));
                            return !hasOtherSelectedStatus;
                          }).length;
                        }
                        
                        return activeEntries.where((entry) {
                          final hasThisStatus = entry.statusRecords.any((r) => r.status == status);
                          if (!hasThisStatus) return false;
                          final hasOtherSelectedStatus = entry.statusRecords.any((r) => 
                            r.status != status && _selectedFilters.contains(r.status));
                          return !hasOtherSelectedStatus;
                        }).length;
                      }
                      
                      final wantToWatchCount = countForStatus(WatchStatus.wantToWatch);
                      final inProgressCount = countForStatus(WatchStatus.inProgress);
                      final watchedCount = countForStatus(WatchStatus.watched);
                      final dnfCount = countForStatus(WatchStatus.dnf);
                      final hiddenCount = _showHidden ? 0 : hiddenEntries.length;
                      
                      return [
                        CheckedPopupMenuItem(
                          value: 'wantToWatch',
                          checked: _selectedFilters.contains(WatchStatus.wantToWatch),
                          child: Row(
                            children: [
                              const Text('Want to watch'),
                              if (wantToWatchCount > 0) ...[
                                const Spacer(),
                                Text(
                                  '+$wantToWatchCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        CheckedPopupMenuItem(
                          value: 'inProgress',
                          checked: _selectedFilters.contains(WatchStatus.inProgress),
                          child: Row(
                            children: [
                              const Text('In progress'),
                              if (inProgressCount > 0) ...[
                                const Spacer(),
                                Text(
                                  '+$inProgressCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        CheckedPopupMenuItem(
                          value: 'watched',
                          checked: _selectedFilters.contains(WatchStatus.watched),
                          child: Row(
                            children: [
                              const Text('Watched'),
                              if (watchedCount > 0) ...[
                                const Spacer(),
                                Text(
                                  '+$watchedCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        CheckedPopupMenuItem(
                          value: 'dnf',
                          checked: _selectedFilters.contains(WatchStatus.dnf),
                          child: Row(
                            children: [
                              const Text('Did not finish'),
                              if (dnfCount > 0) ...[
                                const Spacer(),
                                Text(
                                  '+$dnfCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem(
                          value: 'showHidden',
                          checked: _showHidden,
                          child: Row(
                            children: [
                              const Text('Show Hidden'),
                              if (hiddenCount > 0) ...[
                                const Spacer(),
                                Text(
                                  '+$hiddenCount',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                  // Sort button
                  PopupMenuButton<WatchlistSortOption>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort',
                    onSelected: (option) {
                      setState(() {
                        _sortOption = option;
                      });
                      // Exit rank edit mode when changing sort
                      if (option != WatchlistSortOption.userRank) {
                        _setRankEditMode(false);
                      }
                      // Persist the sort choice
                      final repo = ref.read(preferencesRepositoryProvider);
                      final prefs = repo.getPreferences();
                      prefs.watchlistSortOrder = _sortOptionToString(option);
                      repo.savePreferences(prefs);
                      ref.invalidate(preferencesProvider);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: WatchlistSortOption.addOrder,
                        child: Text('Add Order'),
                      ),
                      const PopupMenuItem(
                        value: WatchlistSortOption.userRank,
                        child: Text('User Rank'),
                      ),
                      const PopupMenuItem(
                        value: WatchlistSortOption.alphabetical,
                        child: Text('Alphabetical'),
                      ),
                      const PopupMenuItem(
                        value: WatchlistSortOption.releaseDate,
                        child: Text('Release Date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Edit Ranking banner (shown when in User Rank sort mode and not editing)
            if (_sortOption == WatchlistSortOption.userRank && !ref.watch(rankEditModeProvider))
              _buildEditRankingBanner(),
            
            // Main content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Watchlist tab
                  watchlistAsync.when(
                    data: (entries) {
                      final theme = Theme.of(context);
                      final activeEntries = entries.where((e) => !e.isSnoozed).toList();
                      final hiddenEntries = entries.where((e) => e.isSnoozed).toList();
                      final filteredEntries = _filterEntries(activeEntries);
                      final sortedEntries = _sortEntries(filteredEntries);
                      final sortedHiddenEntries = _showHidden ? _sortEntries(hiddenEntries) : <WatchlistEntry>[];

                      if (sortedEntries.isEmpty && sortedHiddenEntries.isEmpty) {
                        // Check if there are truly no items at all (including hidden)
                        final totalItems = entries.length;
                        
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_filter_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                totalItems == 0
                                    ? 'Nothing followed yet'
                                    : 'No items match current filters',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (totalItems > 0 && _selectedFilters.length < 4) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your filters to see more items',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilters = {
                                        WatchStatus.wantToWatch,
                                        WatchStatus.inProgress,
                                        WatchStatus.watched,
                                        WatchStatus.dnf,
                                      };
                                    });
                                  },
                                  child: const Text('Show All'),
                                ),
                              ] else if (totalItems == 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Go find something!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () async {
                                    // Navigate to search screen with Movie type pre-selected
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AddContributorScreen(
                                          initialType: ContributorType.movie,
                                        ),
                                      ),
                                    );
                                    // Handle result if needed
                                    if (result != null && mounted) {
                                      ref.invalidate(watchlistEntriesProvider);
                                    }
                                  },
                                  icon: const Icon(Icons.search),
                                  label: const Text('Find Something'),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Filtered indicator
                          if (_selectedFilters.length < 4)
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filtered (${sortedEntries.length} of ${activeEntries.length})',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedFilters = {
                                          WatchStatus.wantToWatch,
                                          WatchStatus.inProgress,
                                          WatchStatus.watched,
                                          WatchStatus.dnf,
                                        };
                                      });
                                    },
                                    child: const Text('Show All'),
                                  ),
                                ],
                              ),
                            ),

                          // Grid of cards (or rank edit list when in edit mode)
                          Expanded(
                            child: (_sortOption == WatchlistSortOption.userRank && ref.watch(rankEditModeProvider))
                                ? _buildUserRankList(sortedEntries)
                                : (_sortOption == WatchlistSortOption.userRank)
                                    ? _buildUserRankGrid(sortedEntries, sortedHiddenEntries)
                                    : LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Use taller cards on small screens to prevent overflow
                                      final isSmallScreen = constraints.maxWidth < 400;
                                      final aspectRatio = isSmallScreen ? 0.38 : 0.43;
                                      
                                      return CustomScrollView(
                                        controller: _scrollController,
                                        slivers: [
                                          // Active items grid (grouped when sorting by release date)
                                          ..._buildActiveItemsSlivers(sortedEntries, aspectRatio),
                                          
                                          // Hidden section (if showing hidden items)
                                          if (sortedHiddenEntries.isNotEmpty) ...[
                                            // Hidden section header
                                            SliverToBoxAdapter(
                                              child: Padding(
                                                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Divider(
                                                        color: theme.colorScheme.outlineVariant,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                                      child: Text(
                                                        'HIDDEN',
                                                        style: theme.textTheme.labelMedium?.copyWith(
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Divider(
                                                        color: theme.colorScheme.outlineVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            
                                            // Hidden items grid
                                            SliverPadding(
                                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                              sliver: SliverGrid(
                                                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                                  maxCrossAxisExtent: 150,
                                                  childAspectRatio: aspectRatio,
                                                  crossAxisSpacing: 12,
                                                  mainAxisSpacing: 6,
                                                ),
                                                delegate: SliverChildBuilderDelegate(
                                                  (context, index) {
                                                    final entry = sortedHiddenEntries[index];
                                                    return Opacity(
                                                      opacity: 0.5,
                                                      child: AnimatedSwitcher(
                                                        duration: const Duration(milliseconds: 300),
                                                        child: WatchlistCard(
                                                          key: ValueKey(entry.uniqueKey),
                                                          entry: entry,
                                                          showDateAlways: _sortOption == WatchlistSortOption.releaseDate,
                                                          onTap: () => _navigateToDetail(entry),
                                                          onDelete: () => _handleDelete(entry),
                                                          onSnooze: () => _handleUnhide(entry),
                                                          onStatusChanged: (status) =>
                                                              _handleStatusChanged(entry, status),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  childCount: sortedHiddenEntries.length,
                                                ),
                                              ),
                                            ),
                                          ],
                                          
                                          // TMDB Attribution - pushed to bottom
                                          const SliverFillRemaining(
                                            hasScrollBody: false,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [TmdbAttribution()],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading watchlist...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load watchlist',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again later',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              ref.invalidate(watchlistEntriesProvider);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  List<WatchlistEntry> _filterEntries(List<WatchlistEntry> entries) {
    final filtered = entries.where((entry) {
      // Items with no status records are treated as "Want to Watch"
      if (entry.statusRecords.isEmpty) {
        return _selectedFilters.contains(WatchStatus.wantToWatch);
      }
      
      return entry.statusRecords.any((record) =>
          _selectedFilters.contains(record.status));
    }).toList();
    
    return filtered;
  }

  /// Builds the Edit Ranking banner shown when in User Rank view mode.
  Widget _buildEditRankingBanner() {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => _setRankEditMode(true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sorted by User Rank',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              // Undo button
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _rankUndoStack.isNotEmpty ? _undoRank : null,
                tooltip: 'Undo',
              ),
              // Redo button
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _rankRedoStack.isNotEmpty ? _redoRank : null,
                tooltip: 'Redo',
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _setRankEditMode(true),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Ranking'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the User Rank mode list with drag-to-reorder functionality.
  Widget _buildUserRankList(List<WatchlistEntry> entries) {
    final theme = Theme.of(context);
    
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_list_numbered,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No items to rank',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to your watchlist to start ranking',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Header with instructions and undo/redo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.drag_indicator,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drag items to reorder your personal ranking',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Undo button
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _rankUndoStack.isNotEmpty ? _undoRank : null,
                tooltip: 'Undo',
              ),
              // Redo button
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _rankRedoStack.isNotEmpty ? _redoRank : null,
                tooltip: 'Redo',
              ),
            ],
          ),
        ),
        
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: entries.length,
            proxyDecorator: (child, index, animation) {
              // Add elevation and scale effect when dragging
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final animValue = Curves.easeInOut.transform(animation.value);
                  final elevation = 8.0 * animValue;
                  final scale = 1.0 + (0.02 * animValue);
                  
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) => _handleReorder(oldIndex, newIndex, entries),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                key: ValueKey(entry.uniqueKey),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: WatchlistRankCard(
                  entry: entry,
                  rank: index + 1,
                  index: index,
                  onTap: () => _navigateToDetailFromRank(entry),
                  onSendToTop: index > 0 ? () => _handleSendToTop(index, entries) : null,
                  onSendToBottom: index < entries.length - 1 ? () => _handleSendToBottom(index, entries) : null,
                ),
              );
            },
          ),
        ),
        
        // TMDB Attribution at bottom
        const TmdbAttribution(),
      ],
    );
  }

  /// Builds the User Rank grid with drag-to-reorder in the main watchlist view.
  Widget _buildUserRankGrid(List<WatchlistEntry> sortedEntries, List<WatchlistEntry> sortedHiddenEntries) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final aspectRatio = isSmallScreen ? 0.38 : 0.43;
        final availableWidth = constraints.maxWidth - 32; // 16px padding each side
        final crossAxisCount = (availableWidth / 150).ceil().clamp(2, 10);

        // Estimate content height to push footer to bottom
        final itemWidth = (availableWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        final itemHeight = itemWidth / aspectRatio;
        final rows = (sortedEntries.length / crossAxisCount).ceil();
        final gridHeight = rows * itemHeight + (rows - 1) * 6 + 32; // 32 = padding
        final hiddenRows = sortedHiddenEntries.isEmpty ? 0 : (sortedHiddenEntries.length / crossAxisCount).ceil();
        final hiddenHeight = sortedHiddenEntries.isEmpty ? 0.0 : (hiddenRows * itemHeight + (hiddenRows - 1) * 6 + 48 + 16); // header + padding
        const attributionHeight = 60.0;
        final contentHeight = gridHeight + hiddenHeight + attributionHeight;
        final remainingSpace = (constraints.maxHeight - contentHeight).clamp(0.0, double.infinity);

        return SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              ReorderableGridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 6,
                childAspectRatio: aspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                dragStartDelay: Duration.zero,
                onReorder: (oldIndex, newIndex) => _handleGridReorder(oldIndex, newIndex, sortedEntries),
                children: [
                  for (int i = 0; i < sortedEntries.length; i++)
                    WatchlistCard(
                      key: ValueKey(sortedEntries[i].uniqueKey),
                      entry: sortedEntries[i],
                      showDateAlways: false,
                      displayRank: i + 1,
                      onTap: () => _navigateToDetailFromRank(sortedEntries[i]),
                      onDelete: () => _handleDelete(sortedEntries[i]),
                      onSnooze: () => _handleHide(sortedEntries[i]),
                      onStatusChanged: (status) => _handleStatusChanged(sortedEntries[i], status),
                    ),
                ],
              ),

              // Hidden section
              if (sortedHiddenEntries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'HIDDEN',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: sortedHiddenEntries.length,
                    itemBuilder: (context, index) {
                      final entry = sortedHiddenEntries[index];
                      return Opacity(
                        opacity: 0.5,
                        child: WatchlistCard(
                          key: ValueKey(entry.uniqueKey),
                          entry: entry,
                          showDateAlways: false,
                          onTap: () => _navigateToDetailFromRank(entry),
                          onDelete: () => _handleDelete(entry),
                          onSnooze: () => _handleUnhide(entry),
                          onStatusChanged: (status) => _handleStatusChanged(entry, status),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Spacer to push attribution to bottom when content is short
              if (remainingSpace > 0)
                SizedBox(height: remainingSpace),
              const TmdbAttribution(),
            ],
          ),
        );
      },
    );
  }

  /// Navigate to detail screen from rank mode
  void _navigateToDetailFromRank(WatchlistEntry entry) {
    final isCollection = entry.type == WorkType.movie &&
        entry.followedContributors.any((c) => c.role == 'Collection');

    if (isCollection) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionConfigurationScreen(
            collectionId: entry.tmdbId,
            collectionTitle: entry.title,
          ),
        ),
      );
    } else if (entry.type == WorkType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailScreen(
            movieId: entry.tmdbId,
            movieTitle: entry.title,
          ),
        ),
      );
    } else if (entry.type == WorkType.tvShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShowConfigurationScreen(
            showId: entry.tmdbId,
            showTitle: entry.title,
          ),
        ),
      );
    }
  }

  /// Gets the most relevant release date for a watchlist entry:
  /// - TV shows: lastAirDate from cached TvShowDetail
  /// - Collections: most recent releaseDate among collection movies
  /// - Movies: the stored entry.releaseDate
  DateTime? _getEffectiveReleaseDate(WatchlistEntry entry) {
    final isCollection = entry.type == WorkType.movie &&
        entry.followedContributors.any((c) => c.role == 'Collection');

    if (entry.type == WorkType.tvShow) {
      final tvDetailRepo = ref.read(tvDetailRepositoryProvider);
      final showDetail = tvDetailRepo.getTvShowDetail(entry.tmdbId);
      if (showDetail != null && showDetail.lastAirDate != null) {
        return showDetail.lastAirDate;
      }
      return entry.releaseDate;
    }

    if (isCollection) {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      final movies = movieStatusRepo.getMoviesByCollection(entry.tmdbId);
      DateTime? mostRecent;
      for (final movie in movies) {
        if (movie.releaseDate != null) {
          if (mostRecent == null || movie.releaseDate!.isAfter(mostRecent)) {
            mostRecent = movie.releaseDate;
          }
        }
      }
      return mostRecent ?? entry.releaseDate;
    }

    return entry.releaseDate;
  }

  /// Returns a sort-priority group index for release date sorting.
  /// Groups: 0=TBD, 1=Upcoming, 2=Recently Released, 3=Ongoing, 4=Released, 5=Ended
  int _getDateStatusGroup(WatchlistEntry entry) {
    final effectiveDate = _getEffectiveReleaseDate(entry);
    final now = DateTime.now();
    final sixMonthsAgo = now.subtract(const Duration(days: 183));

    // Check TV show status
    if (entry.type == WorkType.tvShow) {
      final tvDetailRepo = ref.read(tvDetailRepositoryProvider);
      final showDetail = tvDetailRepo.getTvShowDetail(entry.tmdbId);
      if (showDetail?.status != null) {
        final status = showDetail!.status!.toLowerCase();
        if (status == 'ended' || status == 'canceled') {
          return 5; // Ended — last
        }
        if (status == 'returning series' || status == 'in production') {
          // Ongoing, but if it also has an upcoming date, prioritize that
          if (effectiveDate != null && effectiveDate.isAfter(now)) return 1;
          return 3; // Ongoing
        }
      }
    }

    if (effectiveDate == null) return 0; // TBD — first
    if (effectiveDate.isAfter(now)) return 1; // Upcoming
    if (effectiveDate.isAfter(sixMonthsAgo)) {
      if (entry.lastViewedAt == null || entry.lastViewedAt!.isBefore(effectiveDate)) {
        return 2; // Recently Released
      }
    }
    return 4; // Released
  }

  /// Returns the section header label for a date status group index.
  String _getDateStatusGroupLabel(int group) {
    switch (group) {
      case 0: return 'TBD';
      case 1: return 'UPCOMING';
      case 2: return 'RECENTLY RELEASED';
      case 3: return 'ONGOING';
      case 4: return 'RELEASED';
      case 5: return 'ENDED';
      default: return '';
    }
  }

  List<WatchlistEntry> _sortEntries(List<WatchlistEntry> entries) {
    final sorted = List<WatchlistEntry>.from(entries);

    switch (_sortOption) {
      case WatchlistSortOption.addOrder:
        sorted.sort((a, b) => a.addRank.compareTo(b.addRank));
        break;
      case WatchlistSortOption.userRank:
        sorted.sort((a, b) {
          // Items with userRank come first, sorted by userRank
          // Items without userRank come after, sorted by addRank
          if (a.userRank != null && b.userRank != null) {
            return a.userRank!.compareTo(b.userRank!);
          } else if (a.userRank != null) {
            return -1;
          } else if (b.userRank != null) {
            return 1;
          } else {
            return a.addRank.compareTo(b.addRank);
          }
        });
        break;
      case WatchlistSortOption.alphabetical:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case WatchlistSortOption.releaseDate:
        sorted.sort((a, b) {
          // Group by date status first
          final aGroup = _getDateStatusGroup(a);
          final bGroup = _getDateStatusGroup(b);
          if (aGroup != bGroup) return aGroup.compareTo(bGroup);
          // Within same group, sort by date (newest first)
          final aDate = _getEffectiveReleaseDate(a);
          final bDate = _getEffectiveReleaseDate(b);
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate); // Newest first
        });
        break;
    }

    return sorted;
  }

  /// Builds the slivers for active watchlist items.
  /// When sorting by release date, groups entries by status with section headers.
  List<Widget> _buildActiveItemsSlivers(List<WatchlistEntry> entries, double aspectRatio) {
    final theme = Theme.of(context);
    final isReleaseDateSort = _sortOption == WatchlistSortOption.releaseDate;

    final isUserRankSort = _sortOption == WatchlistSortOption.userRank;

    if (!isReleaseDateSort || entries.isEmpty) {
      // Flat grid — no grouping
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = entries[index];
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: WatchlistCard(
                    key: ValueKey(entry.uniqueKey),
                    entry: entry,
                    showDateAlways: false,
                    displayRank: isUserRankSort ? index + 1 : null,
                    onTap: () => _navigateToDetail(entry),
                    onDelete: () => _handleDelete(entry),
                    onSnooze: () => _handleHide(entry),
                    onStatusChanged: (status) => _handleStatusChanged(entry, status),
                  ),
                );
              },
              childCount: entries.length,
            ),
          ),
        ),
      ];
    }

    // Grouped by date status
    final groups = <int, List<WatchlistEntry>>{};
    for (final entry in entries) {
      final group = _getDateStatusGroup(entry);
      groups.putIfAbsent(group, () => []).add(entry);
    }

    final sortedGroupKeys = groups.keys.toList()..sort();
    final slivers = <Widget>[];
    bool isFirst = true;

    for (final groupKey in sortedGroupKeys) {
      final groupEntries = groups[groupKey]!;
      final label = _getDateStatusGroupLabel(groupKey);

      // Section header
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, isFirst ? 16 : 24, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
              ],
            ),
          ),
        ),
      );

      // Grid for this group
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = groupEntries[index];
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: WatchlistCard(
                    key: ValueKey(entry.uniqueKey),
                    entry: entry,
                    showDateAlways: true,
                    onTap: () => _navigateToDetail(entry),
                    onDelete: () => _handleDelete(entry),
                    onSnooze: () => _handleHide(entry),
                    onStatusChanged: (status) => _handleStatusChanged(entry, status),
                  ),
                );
              },
              childCount: groupEntries.length,
            ),
          ),
        ),
      );

      isFirst = false;
    }

    return slivers;
  }

  void _navigateToDetail(WatchlistEntry entry) {
    // Only navigate for movies - TV shows have their own detail flow
    if (entry.type == WorkType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailScreen(
            movieId: entry.tmdbId,
            movieTitle: entry.title,
          ),
        ),
      );
    }
  }

  Future<void> _handleDelete(WatchlistEntry entry) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.removeWorkFromWatchlist(entry.tmdbId, entry.type);
    
    if (mounted) {
      showRemovedFromWatchlistSnackBar(
        context,
        entry.title,
        () async {
          // Undo: Re-add to watchlist
          await logic.addWorkToWatchlist(
            tmdbId: entry.tmdbId,
            type: entry.type,
            title: entry.title,
            posterPath: entry.posterPath,
            releaseDate: entry.releaseDate,
            releaseType: entry.releaseType,
          );
          ref.invalidate(watchlistEntriesProvider);
        },
        onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
      );
    }
    
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleHide(WatchlistEntry entry) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.setSnoozed(entry.tmdbId, entry.type, true);
    
    if (mounted) {
      showSnoozedSnackBar(
        context,
        entry.title,
        () async {
          // Undo: Unhide
          await logic.setSnoozed(entry.tmdbId, entry.type, false);
          ref.invalidate(watchlistEntriesProvider);
        },
        onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
      );
    }
    
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleUnhide(WatchlistEntry entry) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.setSnoozed(entry.tmdbId, entry.type, false);
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleReorder(int oldIndex, int newIndex, List<WatchlistEntry> entries) async {
    // Check if filters are active
    if (_selectedFilters.length < 4) {
      // Show warning snackbar
      if (mounted) {
        showDragReorderWarningSnackBar(
          context,
          () {
            // Show all items
            setState(() {
              _selectedFilters = {
                WatchStatus.wantToWatch,
                WatchStatus.inProgress,
                WatchStatus.watched,
                WatchStatus.dnf,
              };
            });
          },
          onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
        );
      }
      return;
    }

    // Adjust newIndex if moving down (ReorderableListView convention)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) return; // No change

    // Save to undo stack before changing
    _saveRankToUndoStack(entries);

    // Reorder the list
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);

    // Update userRank for all affected items
    final logic = ref.read(watchlistLogicProvider);
    
    for (int i = 0; i < entries.length; i++) {
      await logic.updateUserRank(entries[i].tmdbId, entries[i].type, i + 1);
    }

    // Refresh the provider
    ref.invalidate(watchlistEntriesProvider);
  }

  /// Handles reorder from ReorderableGridView (no index adjustment needed).
  Future<void> _handleGridReorder(int oldIndex, int newIndex, List<WatchlistEntry> entries) async {
    // Check if filters are active
    if (_selectedFilters.length < 4) {
      if (mounted) {
        showDragReorderWarningSnackBar(
          context,
          () {
            setState(() {
              _selectedFilters = {
                WatchStatus.wantToWatch,
                WatchStatus.inProgress,
                WatchStatus.watched,
                WatchStatus.dnf,
              };
            });
          },
          onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
        );
      }
      return;
    }

    if (oldIndex == newIndex) return; // No change

    // Save to undo stack before changing
    _saveRankToUndoStack(entries);

    // Reorder the list (grid gives final target index directly)
    final entry = entries.removeAt(oldIndex);
    entries.insert(newIndex, entry);

    final logic = ref.read(watchlistLogicProvider);
    for (int i = 0; i < entries.length; i++) {
      await logic.updateUserRank(entries[i].tmdbId, entries[i].type, i + 1);
    }
    ref.invalidate(watchlistEntriesProvider);
  }

  /// Sends an entry to the top of the rank list.
  Future<void> _handleSendToTop(int index, List<WatchlistEntry> entries) async {
    debugPrint('[SendToTop] Called with index=$index, entries.length=${entries.length}');
    if (index == 0) {
      debugPrint('[SendToTop] Already at top, skipping');
      return;
    }
    debugPrint('[SendToTop] Entry: "${entries[index].title}" (tmdbId=${entries[index].tmdbId}, type=${entries[index].type})');
    debugPrint('[SendToTop] Current order: ${entries.map((e) => "${e.title}(rank=${e.userRank})").join(", ")}');
    
    _saveRankToUndoStack(entries);

    // Work on a copy to avoid mutating the list during layout
    final reordered = List<WatchlistEntry>.from(entries);
    final entry = reordered.removeAt(index);
    reordered.insert(0, entry);
    debugPrint('[SendToTop] New order: ${reordered.map((e) => e.title).join(", ")}');

    final logic = ref.read(watchlistLogicProvider);
    for (int i = 0; i < reordered.length; i++) {
      debugPrint('[SendToTop] Saving rank ${i + 1} for "${reordered[i].title}"');
      await logic.updateUserRank(reordered[i].tmdbId, reordered[i].type, i + 1);
    }
    debugPrint('[SendToTop] Invalidating watchlistEntriesProvider');
    ref.invalidate(watchlistEntriesProvider);
    debugPrint('[SendToTop] Done');
  }

  /// Sends an entry to the bottom of the rank list.
  Future<void> _handleSendToBottom(int index, List<WatchlistEntry> entries) async {
    if (index == entries.length - 1) {
      return;
    }

    _saveRankToUndoStack(entries);

    // Work on a copy to avoid mutating the list during layout
    final reordered = List<WatchlistEntry>.from(entries);
    final entry = reordered.removeAt(index);
    reordered.add(entry);

    final logic = ref.read(watchlistLogicProvider);
    for (int i = 0; i < reordered.length; i++) {
      await logic.updateUserRank(reordered[i].tmdbId, reordered[i].type, i + 1);
    }
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleStatusChanged(
    WatchlistEntry entry,
    WatchStatus status,
  ) async {
    final logic = ref.read(watchlistLogicProvider);

    // Check if unreleased
    if (!entry.isReleased && status != WatchStatus.wantToWatch) {
      showUnreleasedWarningSnackBar(
        context,
        entry.title,
        onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
      );
    }

    // Handle In Progress toggle - if already in progress, unmark it
    if (status == WatchStatus.inProgress) {
      final hasInProgress = entry.statusRecords
          .any((r) => r.status == WatchStatus.inProgress);
      
      if (hasInProgress) {
        // Toggle off - remove the in progress status
        await logic.removeStatusFromWork(entry.tmdbId, entry.type, status);
        
        if (mounted) {
          showSimpleSnackBar(
            context,
            '${entry.title} unmarked as In progress',
            duration: const Duration(seconds: 3),
            onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
          );
        }
        
        ref.invalidate(watchlistEntriesProvider);
        return;
      }
    }

    // Handle watched status with re-watch dialog
    if (status == WatchStatus.watched) {
      final watchedRecords = entry.statusRecords
          .where((r) => r.status == WatchStatus.watched)
          .toList();

      if (watchedRecords.isNotEmpty) {
        final existingDates = watchedRecords.first.watchDates ?? [];
        final lastWatchDate = watchedRecords.first.lastWatchDate;

        // Show re-watch dialog
        final updatedDates = await showReWatchDialog(
          context,
          existingWatchDates: existingDates,
          lastWatchDate: lastWatchDate,
        );

        if (updatedDates != null) {
          if (updatedDates.isEmpty) {
            // User deleted all watches - unmark as watched
            await logic.removeStatusFromWork(entry.tmdbId, entry.type, status);
            
            if (mounted) {
              showSimpleSnackBar(
                context,
                '${entry.title} unmarked as Watched',
                duration: const Duration(seconds: 3),
                onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
              );
            }
          } else {
            // Update with new watch dates
            await logic.addStatusToWork(
              entry.tmdbId,
              entry.type,
              status,
              watchDates: updatedDates,
            );
            
            if (mounted) {
              showSimpleSnackBar(
                context,
                '${entry.title} marked as Watched${updatedDates.length > 1 ? ' (x${updatedDates.length})' : ''}',
                duration: const Duration(seconds: 3),
                onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
              );
            }
          }
        }
      } else {
        // First watch
        await logic.addStatusToWork(
          entry.tmdbId,
          entry.type,
          status,
          watchDates: [DateTime.now()],
        );
        
        if (mounted) {
          showSimpleSnackBar(
            context,
            '${entry.title} marked as Watched',
            duration: const Duration(seconds: 3),
            onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
          );
        }
      }
    } else {
      // Other statuses
      await logic.addStatusToWork(entry.tmdbId, entry.type, status);
      
      if (mounted) {
        String text = '';
        switch (status) {
          case WatchStatus.wantToWatch:
            text = 'Want to watch';
            break;
          case WatchStatus.inProgress:
            text = 'In progress';
            break;
          case WatchStatus.dnf:
            text = 'Did not finish';
            break;
          case WatchStatus.watched:
            // Already handled above
            break;
        }
        
        if (text.isNotEmpty) {
          showSimpleSnackBar(
            context,
            '${entry.title} marked as $text',
            duration: const Duration(seconds: 3),
            onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
          );
        }
      }
    }

    ref.invalidate(watchlistEntriesProvider);
  }
}
