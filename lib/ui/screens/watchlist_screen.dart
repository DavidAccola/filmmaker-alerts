import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_entry.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/watchlist_card.dart';
import '../common/snackbar_utils.dart';
import '../common/rewatch_dialog.dart';

enum WatchlistSortOption {
  addOrder,
  userRank,
  alphabetical,
  releaseDate,
}

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _hasFrozenItems = false;
  
  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  // Sort state
  WatchlistSortOption _sortOption = WatchlistSortOption.addOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistEntriesProvider);

    return watchlistAsync.when(
      data: (entries) {
        final hasFrozen = entries.any((e) => e.isSnoozed);
        
        // Update tab controller if frozen status changed (outside of build)
        if (_hasFrozenItems != hasFrozen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateTabController(hasFrozen);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Watchlist'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Watchlist'),
                if (_hasFrozenItems)
                  const Tab(text: 'Freezer'),
              ],
            ),
            actions: [
              // Add test data button (for testing)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addTestData,
                tooltip: 'Add Test Data',
              ),
              // Filter button
              IconButton(
                icon: Badge(
                  isLabelVisible: _selectedFilters.length < 4,
                  label: Text('${_selectedFilters.length}'),
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter',
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Drag and drop cards to reorder'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
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
          body: _tabController.length > 0
            ? TabBarView(
                controller: _tabController,
                children: [
                  // Watchlist tab
                  watchlistAsync.when(
                    data: (entries) {
                      final theme = Theme.of(context);
                      final activeEntries = entries.where((e) => !e.isSnoozed).toList();
                      final filteredEntries = _filterEntries(activeEntries);
                      final sortedEntries = _sortEntries(filteredEntries);

                      if (sortedEntries.isEmpty) {
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
                                activeEntries.isEmpty 
                                    ? 'No items in watchlist'
                                    : 'No items match current filters',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (activeEntries.isNotEmpty && _selectedFilters.length < 4) ...[
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
                              ] else if (activeEntries.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Add movies and TV shows to get started',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _addTestData,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Test Data'),
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
                                                onSnooze: () => _handleSnooze(entry),
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
                                : GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 200,
                                      childAspectRatio: 0.48,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: sortedEntries.length,
                                    itemBuilder: (context, index) {
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
                                          onSnooze: () => _handleSnooze(entry),
                                          onToggleNotificationSnooze: () =>
                                              _handleToggleNotificationSnooze(entry),
                                          onStatusChanged: (status) =>
                                              _handleStatusChanged(entry, status),
                                        ),
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

                  // Freezer tab (only shown if frozen items exist)
                  if (_hasFrozenItems)
                    watchlistAsync.when(
                      data: (entries) {
                        final frozenEntries = entries.where((e) => e.isSnoozed).toList();

                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.48,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: frozenEntries.length,
                          itemBuilder: (context, index) {
                            final entry = frozenEntries[index];
                            return WatchlistCard(
                              entry: entry,
                              onTap: () {
                                // TODO: Navigate to detail screen
                              },
                              onDelete: () => _handleDelete(entry),
                              onSnooze: () => _handleUnsnooze(entry),
                              onToggleNotificationSnooze: () =>
                                  _handleToggleNotificationSnooze(entry),
                              onStatusChanged: (status) =>
                                  _handleStatusChanged(entry, status),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Error: $error'),
                      ),
                    ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  List<WatchlistEntry> _filterEntries(List<WatchlistEntry> entries) {
    return entries.where((entry) {
      // Check if entry has any of the selected statuses
      return entry.statusRecords.any((record) =>
          _selectedFilters.contains(record.status));
    }).toList();
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
      showSimpleSnackBar(context, 'Added 4 test items to watchlist');
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
      );
    }
    
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleSnooze(WatchlistEntry entry) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.setSnoozed(entry.tmdbId, entry.type, true);
    
    if (mounted) {
      showSnoozedSnackBar(
        context,
        entry.title,
        () async {
          // Undo: Unsnooze
          await logic.setSnoozed(entry.tmdbId, entry.type, false);
          ref.invalidate(watchlistEntriesProvider);
        },
      );
    }
    
    ref.invalidate(watchlistEntriesProvider);
  }

  Future<void> _handleUnsnooze(WatchlistEntry entry) async {
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
      showUnreleasedWarningSnackBar(context, entry.title);
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
          await logic.addStatusToWork(
            entry.tmdbId,
            entry.type,
            status,
            watchDates: updatedDates,
          );
          
          if (mounted) {
            showSimpleSnackBar(
              context,
              '${entry.title} marked as Watched (${updatedDates.length}x)',
              duration: const Duration(seconds: 3),
            );
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
          );
        }
      }
    }

    ref.invalidate(watchlistEntriesProvider);
  }
}
