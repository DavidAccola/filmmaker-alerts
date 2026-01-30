import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/watchlist_card.dart';
import '../common/snackbar_utils.dart';
import '../common/rewatch_dialog.dart';
import 'add_contributor_screen.dart';

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
  bool _hasFrozenItems = false;
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
  WatchlistSortOption _sortOption = WatchlistSortOption.addOrder;

  /// Helper to update FAB raised state via provider (shared with HomeScreen)
  void _setFabRaised(bool raised) {
    ref.read(fabRaisedProvider.notifier).state = raised;
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

  void _updateTabController(bool hasFrozen) {
    if (_hasFrozenItems != hasFrozen && mounted) {
      _hasFrozenItems = hasFrozen;
      try {
        _tabController.dispose();
      } catch (_) {
        // Ignore if already disposed
      }
      _tabController = TabController(
        length: hasFrozen ? 2 : 1,
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
    // Grid has 2 columns with maxCrossAxisExtent: 200, childAspectRatio: 0.48
    // So each item is roughly 200 wide and 200/0.48 = ~416 tall
    const itemHeight = 416.0; // More accurate height estimate
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

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistEntriesProvider);

    return watchlistAsync.when(
      data: (entries) {
        debugPrint('[WatchlistScreen] === BUILD DEBUG ===');
        debugPrint('[WatchlistScreen] Total entries: ${entries.length}');
        
        final hasFrozen = entries.any((e) => e.isSnoozed);
        debugPrint('[WatchlistScreen] Has frozen items: $hasFrozen');
        
        final activeEntries = entries.where((e) => !e.isSnoozed).toList();
        final hiddenEntries = entries.where((e) => e.isSnoozed).toList();
        debugPrint('[WatchlistScreen] Active entries: ${activeEntries.length}, Hidden entries: ${hiddenEntries.length}');
        
        // Update tab controller if frozen status changed (outside of build)
        if (_hasFrozenItems != hasFrozen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTabController(hasFrozen);
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
        
        debugPrint('[WatchlistScreen] Filtered active entries: ${filteredActiveEntries.length}');
        
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
                  // Add test data button (for testing)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTestData,
                    tooltip: 'Add Test Data',
                  ),
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
                      
                      // Show hint about drag-and-drop when user rank is selected
                      if (option == WatchlistSortOption.userRank && mounted) {
                        showSimpleSnackBar(
                          context,
                          'Drag and drop cards to reorder',
                          duration: const Duration(seconds: 2),
                          onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
                        );
                      }
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
                        
                        debugPrint('[WatchlistScreen] Empty state debug:');
                        debugPrint('[WatchlistScreen]   entries.length: $totalItems');
                        debugPrint('[WatchlistScreen]   activeEntries.length: ${activeEntries.length}');
                        debugPrint('[WatchlistScreen]   hiddenEntries.length: ${hiddenEntries.length}');
                        debugPrint('[WatchlistScreen]   sortedEntries.length: ${sortedEntries.length}');
                        debugPrint('[WatchlistScreen]   sortedHiddenEntries.length: ${sortedHiddenEntries.length}');
                        debugPrint('[WatchlistScreen]   _selectedFilters: $_selectedFilters');
                        debugPrint('[WatchlistScreen]   _showHidden: $_showHidden');
                        
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

                          // Grid of cards
                          Expanded(
                            child: _sortOption == WatchlistSortOption.userRank
                                ? ReorderableListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: sortedEntries.length,
                                    onReorder: (oldIndex, newIndex) => _handleReorder(oldIndex, newIndex, sortedEntries),
                                    itemBuilder: (context, index) {
                                      final entry = sortedEntries[index];
                                      return Container(
                                        key: ValueKey(entry.uniqueKey),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 200,
                                              child: WatchlistCard(
                                                entry: entry,
                                                onTap: () {
                                                  // TODO: Navigate to detail screen
                                                },
                                                onDelete: () => _handleDelete(entry),
                                                onSnooze: () => _handleHide(entry),
                                                onToggleNotificationSnooze: () =>
                                                    _handleToggleNotificationSnooze(entry),
                                                onStatusChanged: (status) =>
                                                    _handleStatusChanged(entry, status),
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.drag_handle,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                : CustomScrollView(
                                    controller: _scrollController,
                                    slivers: [
                                      // Active items grid
                                      SliverPadding(
                                        padding: const EdgeInsets.all(16),
                                        sliver: SliverGrid(
                                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 200,
                                            childAspectRatio: 0.55,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 8,
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              final entry = sortedEntries[index];
                                              return AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 300),
                                                child: WatchlistCard(
                                                  key: ValueKey(entry.uniqueKey),
                                                  entry: entry,
                                                  onTap: () {
                                                    // TODO: Navigate to detail screen
                                                  },
                                                  onDelete: () => _handleDelete(entry),
                                                  onSnooze: () => _handleHide(entry),
                                                  onToggleNotificationSnooze: () =>
                                                      _handleToggleNotificationSnooze(entry),
                                                  onStatusChanged: (status) =>
                                                      _handleStatusChanged(entry, status),
                                                ),
                                              );
                                            },
                                            childCount: sortedEntries.length,
                                          ),
                                        ),
                                      ),
                                      
                                      // Hidden section header (if showing hidden items)
                                      if (sortedHiddenEntries.isNotEmpty) ...[
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
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 200,
                                              childAspectRatio: 0.55,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 8,
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
                                                      onTap: () {
                                                        // TODO: Navigate to detail screen
                                                      },
                                                      onDelete: () => _handleDelete(entry),
                                                      onSnooze: () => _handleUnhide(entry),
                                                      onToggleNotificationSnooze: () =>
                                                          _handleToggleNotificationSnooze(entry),
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
                                    ],
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
    debugPrint('[WatchlistScreen] _filterEntries called with ${entries.length} entries');
    
    final filtered = entries.where((entry) {
      // Items with no status records are treated as "Want to Watch"
      if (entry.statusRecords.isEmpty) {
        final matches = _selectedFilters.contains(WatchStatus.wantToWatch);
        if (!matches) {
          debugPrint('[WatchlistScreen]   Entry "${entry.title}" filtered out (no status, treated as Want to Watch)');
        }
        return matches;
      }
      
      final hasMatchingStatus = entry.statusRecords.any((record) =>
          _selectedFilters.contains(record.status));
      
      if (!hasMatchingStatus) {
        debugPrint('[WatchlistScreen]   Entry "${entry.title}" filtered out:');
        debugPrint('[WatchlistScreen]     statusRecords: ${entry.statusRecords.map((r) => r.status).toList()}');
        debugPrint('[WatchlistScreen]     selectedFilters: $_selectedFilters');
      }
      
      return hasMatchingStatus;
    }).toList();
    
    debugPrint('[WatchlistScreen] _filterEntries returning ${filtered.length} entries');
    return filtered;
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
          if (a.releaseDate == null && b.releaseDate == null) return 0;
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return b.releaseDate!.compareTo(a.releaseDate!); // Newest first
        });
        break;
    }

    return sorted;
  }

  Future<void> _addTestData() async {
    final logic = ref.read(watchlistLogicProvider);
    
    // Add a few test movies and shows
    await logic.addWorkToWatchlist(
      tmdbId: 550,
      type: WorkType.movie,
      title: 'Fight Club',
      posterPath: '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
      releaseDate: DateTime(1999, 10, 15),
      releaseType: ReleaseType.theatrical,
    );
    
    await logic.addWorkToWatchlist(
      tmdbId: 13,
      type: WorkType.movie,
      title: 'Forrest Gump',
      posterPath: '/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg',
      releaseDate: DateTime(1994, 7, 6),
      releaseType: ReleaseType.theatrical,
    );
    
    await logic.addWorkToWatchlist(
      tmdbId: 1396,
      type: WorkType.tvShow,
      title: 'Breaking Bad',
      posterPath: '/ggFHVNu6YYI5L9pCfOacjizRGt.jpg',
      releaseDate: DateTime(2008, 1, 20),
      releaseType: ReleaseType.streaming,
    );
    
    await logic.addWorkToWatchlist(
      tmdbId: 94605,
      type: WorkType.tvShow,
      title: 'Arcane',
      posterPath: '/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
      releaseDate: DateTime(2021, 11, 6),
      releaseType: ReleaseType.streaming,
    );
    
    ref.invalidate(watchlistEntriesProvider);
    
    if (mounted) {
      showSimpleSnackBar(
        context,
        'Added 4 test items to watchlist',
        onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
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

  Future<void> _handleToggleNotificationSnooze(WatchlistEntry entry) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.setNotificationsSnoozed(
      entry.tmdbId,
      entry.type,
      !entry.notificationsSnoozed,
    );
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

    // Adjust newIndex if moving down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

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
      
      // If DNF, also freeze the item
      if (status == WatchStatus.dnf) {
        await logic.setSnoozed(entry.tmdbId, entry.type, true);
      }
      
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
