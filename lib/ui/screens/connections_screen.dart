import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/preferences.dart';
import '../../logic/connections_logic.dart';
import '../../logic/connections_models.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/connection_work_card.dart';
import '../common/pair_group_card.dart';
import '../common/unfollowed_person_card.dart';
import '../common/tv_preferences_dialog.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isInitialized = false;

  // Person filter state
  int? _selectedContributorId;

  // Watchlist tab mode: false = Contributors (followed), true = All Connections (unfollowed)
  bool _showAllConnections = false;

  // Refresh state
  bool _isRefreshing = false;
  int _refreshCompleted = 0;
  int _refreshTotal = 0;

  // Discovery lazy loading state
  int _discoveryLoadedCount = 20;
  bool _isLoadingMore = false;
  final ScrollController _discoveryScrollController = ScrollController();

  void _initTabController(int initialIndex) {
    if (_isInitialized) return;
    _isInitialized = true;

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      final currentProviderValue = ref.read(connectionsTabProvider);
      if (currentProviderValue != _tabController!.index) {
        ref.read(connectionsTabProvider.notifier).setTab(_tabController!.index);
      }
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _discoveryScrollController.dispose();
    super.dispose();
  }

  /// Compute the initial tab index: default 0 (Connections),
  /// but if Connections is empty and Discovery has results, use 1.
  int _computeInitialTab(ConnectionsData data) {
    if (data.watchlistItems.isEmpty && data.discoveryItems.isNotEmpty) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(connectionsDataProvider);
    final prefsAsync = ref.watch(preferencesProvider);
    final connectionsTab = ref.watch(connectionsTabProvider);

    return connectionsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) {
        // Show error state with retry
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showSimpleSnackBar(context, 'Error loading connections: $err');
          }
        });
        return Scaffold(
          appBar: AppBar(title: const Text('Watchlist Connections')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load connections'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(connectionsDataProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      data: (connectionsData) {
        final prefs = prefsAsync.value ?? Preferences();
        final sortMode = prefs.connectionsSortOrder ?? 'connectionCount';
        final groupByRelease = prefs.connectionsGroupByRelease ??
            (sortMode == 'releaseDate');

        // Sort and group the data
        final logic = ref.read(connectionsLogicProvider);
        final sortedData = logic.sortAndGroup(
          data: connectionsData,
          sortMode: sortMode,
          groupByRelease: groupByRelease,
          contributorFilter: _selectedContributorId,
        );

        // Initialize tab controller with computed initial index
        if (!_isInitialized) {
          final initialTab = _computeInitialTab(connectionsData);
          // If provider already has a value different from default, use it
          final providerTab = ref.read(connectionsTabProvider);
          _initTabController(providerTab == 0 ? initialTab : providerTab);
          if (initialTab != 0 && providerTab == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(connectionsTabProvider.notifier).setTab(initialTab);
              }
            });
          }
        }

        // Sync TabController with provider when provider changes externally
        if (_tabController != null && _tabController!.index != connectionsTab) {
          _tabController!.animateTo(connectionsTab);
        }

        if (_tabController == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: _buildToolbar(prefs, connectionsData),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryStatsBar(connectionsData.stats),
                  _buildPersonFilterChipBar(connectionsData.chipBarContributors),
                  TabBar(
                    controller: _tabController!,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                    onTap: (index) {
                      ref.read(connectionsTabProvider.notifier).setTab(index);
                    },
                    tabs: const [
                      Tab(text: 'Watchlist'),
                      Tab(text: 'Discovery'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController!,
            children: [
              _buildConnectionsTab(sortedData),
              _buildDiscoveryTab(sortedData),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7.2 — Toolbar: Display Options + Refresh
  // ---------------------------------------------------------------------------

  Widget _buildToolbar(Preferences prefs, ConnectionsData data) {
    return Row(
      children: [
        const SizedBox(width: 16),
        const Text('Watchlist Connections'),
        // Refresh button — right next to title, matching Following screen pattern
        _buildRefreshButton(),
        const Spacer(),
        // Display Options button
        _buildDisplayOptionsButton(prefs),
      ],
    );
  }

  Widget _buildDisplayOptionsButton(Preferences prefs) {
    final currentSort = prefs.connectionsSortOrder ?? 'connectionCount';
    final groupByRelease = prefs.connectionsGroupByRelease ??
        (currentSort == 'releaseDate');
    final showHiddenContributors =
        prefs.connectionsShowHiddenContributors ?? false;
    final showHiddenWatchlist =
        prefs.connectionsShowHiddenWatchlist ?? false;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune),
      tooltip: 'Display Options',
      onSelected: (value) async {
        final repo = ref.read(preferencesRepositoryProvider);
        final currentPrefs =
            (await ref.read(preferencesProvider.future));

        if (value == 'sort_connectionCount') {
          currentPrefs.connectionsSortOrder = 'connectionCount';
          // Default group-by-release to off for connection count sort
          currentPrefs.connectionsGroupByRelease = false;
        } else if (value == 'sort_releaseDate') {
          currentPrefs.connectionsSortOrder = 'releaseDate';
          // Default group-by-release to on for release date sort
          currentPrefs.connectionsGroupByRelease = true;
        } else if (value == 'toggle_group') {
          currentPrefs.connectionsGroupByRelease = !groupByRelease;
        } else if (value == 'toggle_hidden_contributors') {
          currentPrefs.connectionsShowHiddenContributors =
              !showHiddenContributors;
        } else if (value == 'toggle_hidden_watchlist') {
          currentPrefs.connectionsShowHiddenWatchlist =
              !showHiddenWatchlist;
        }

        await repo.savePreferences(currentPrefs);
        ref.invalidate(preferencesProvider);
        if (value == 'toggle_hidden_contributors' ||
            value == 'toggle_hidden_watchlist') {
          ref.invalidate(connectionsDataProvider);
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            enabled: false,
            height: 32,
            child: Text('Sort by',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          PopupMenuItem(
            value: 'sort_connectionCount',
            child: Row(
              children: [
                if (currentSort == 'connectionCount')
                  const Icon(Icons.check, size: 18),
                const SizedBox(width: 8),
                const Text('Number of Connections'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'sort_releaseDate',
            child: Row(
              children: [
                if (currentSort == 'releaseDate')
                  const Icon(Icons.check, size: 18),
                const SizedBox(width: 8),
                const Text('Release Date'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'toggle_group',
            checked: groupByRelease,
            child: const Text('Group by Release Status'),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'toggle_hidden_contributors',
            checked: showHiddenContributors,
            child: const Text('Show Hidden Contributors'),
          ),
          CheckedPopupMenuItem(
            value: 'toggle_hidden_watchlist',
            checked: showHiddenWatchlist,
            child: const Text('Show Hidden Watchlist Items'),
          ),
        ];
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7.7 — Refresh button
  // ---------------------------------------------------------------------------

  Widget _buildRefreshButton() {
    if (_isRefreshing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _refreshTotal > 0
                    ? '$_refreshCompleted / $_refreshTotal'
                    : 'Refreshing...',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: _refreshTotal > 0
                    ? _refreshCompleted / _refreshTotal
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.refresh, size: 20),
      tooltip: 'Refresh All',
      onPressed: _handleRefresh,
    );
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _refreshCompleted = 0;
      _refreshTotal = 0;
    });

    try {
      final logic = ref.read(contributorLogicProvider);
      await logic.refreshAllContributors(
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _refreshCompleted = completed;
              _refreshTotal = total;
            });
          }
        },
      );

      // Fetch MovieDetail/TvShowDetail for watchlist works that aren't cached.
      // computeUnfollowedConnections reads from these caches to find the full
      // cast/crew of each work (getPersonCombinedCredits only returns a person's
      // own roles, not the full cast/crew of each movie/show).
      await _fetchUncachedWatchlistDetails();

      ref.invalidate(contributorsProvider);
      ref.invalidate(connectionsDataProvider);
      ref.invalidate(unfollowedConnectionsProvider);

      if (mounted) {
        showSimpleSnackBar(context, 'Refresh complete');
      }
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(context, 'Refresh failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Fetch and cache MovieDetail/TvShowDetail for watchlist works that don't
  /// have cached detail yet. This populates the full cast/crew data needed
  /// by the "All Connections" unfollowed-person feature.
  Future<void> _fetchUncachedWatchlistDetails() async {
    final watchlistLogic = ref.read(watchlistLogicProvider);
    final workLogic = ref.read(workLogicProvider);
    final movieDetailRepo = ref.read(movieDetailRepositoryProvider);
    final tvDetailRepo = ref.read(tvDetailRepositoryProvider);

    final entries = watchlistLogic.getWatchlistWorks();

    for (final entry in entries) {
      try {
        if (entry.type == WorkType.movie) {
          if (!movieDetailRepo.isCached(entry.tmdbId)) {
            await workLogic.fetchAndCacheMovieDetail(entry.tmdbId);
          }
        } else if (entry.type == WorkType.tvShow) {
          if (!tvDetailRepo.isShowCached(entry.tmdbId)) {
            await workLogic.fetchAndCacheTvShowDetail(entry.tmdbId);
          }
        }
      } catch (_) {
        // Skip individual failures — best effort
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 7.3 — Summary Stats Bar
  // ---------------------------------------------------------------------------

  Widget _buildSummaryStatsBar(ConnectionsStats stats) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final parts = <String>[
      '${stats.watchlistCount} on watchlist',
      '${stats.discoveryCount} to discover',
      '${stats.peopleCount} people',
    ];
    if (stats.pendingCount > 0) {
      parts.add('${stats.pendingCount} pending');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        parts.join(' · '),
        style: style,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7.4 — Person Filter Chip Bar
  // ---------------------------------------------------------------------------

  Widget _buildPersonFilterChipBar(List<ContributorSummary> contributors) {
    if (contributors.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
          },
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: contributors.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final contributor = contributors[index];
            final isSelected =
                _selectedContributorId == contributor.contributorId;

            return FilterChip(
              selected: isSelected,
              avatar: contributor.profilePath != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://image.tmdb.org/t/p/w45${contributor.profilePath}',
                      ),
                      radius: 14,
                    )
                  : CircleAvatar(
                      radius: 14,
                      child: Text(
                        contributor.name.isNotEmpty
                            ? contributor.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
              label: Text(
                contributor.name,
                style: const TextStyle(fontSize: 12),
              ),
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    _selectedContributorId = null;
                  } else {
                    _selectedContributorId = contributor.contributorId;
                  }
                  // Reset discovery lazy loading when filter changes
                  _discoveryLoadedCount = 20;
                });
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7.5 — Connections Tab Content
  // ---------------------------------------------------------------------------

  Widget _buildConnectionsTab(SortedConnectionsData sortedData) {
    return Column(
      children: [
        // Toggle between Contributors and All Connections
        _buildWatchlistModeToggle(),
        Expanded(
          child: _showAllConnections
              ? _buildAllConnectionsList()
              : _buildContributorsList(sortedData),
        ),
      ],
    );
  }

  Widget _buildWatchlistModeToggle() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Contributors'),
            icon: Icon(Icons.people_outline, size: 18),
          ),
          ButtonSegment(
            value: true,
            label: Text('All Connections'),
            icon: Icon(Icons.person_search_outlined, size: 18),
          ),
        ],
        selected: {_showAllConnections},
        onSelectionChanged: (selected) {
          setState(() {
            _showAllConnections = selected.first;
          });
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildContributorsList(SortedConnectionsData sortedData) {
    final items = sortedData.watchlistItems;

    if (items.isEmpty) {
      return const Center(
        child: Text('No connections found on your watchlist.'),
      );
    }

    // If grouped by release status, show with headers
    if (sortedData.watchlistGroups != null) {
      return _buildGroupedItemList(sortedData.watchlistGroups!);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildDiscoveryItem(items[index]);
      },
    );
  }

  Widget _buildAllConnectionsList() {
    final unfollowedAsync = ref.watch(unfollowedConnectionsProvider);

    return unfollowedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(
            child: Text('No unfollowed people found across your watchlist.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            return UnfollowedPersonCard(personGroup: groups[index]);
          },
        );
      },
    );
  }

  /// Shared grouped list builder for both Connections and Discovery tabs.
  Widget _buildGroupedItemList(
      Map<ReleaseStatusGroup, List<DiscoveryItem>> groups) {
    final entries = groups.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (context, index) {
        int current = 0;
        for (final entry in entries) {
          if (index == current) {
            return _buildGroupHeader(entry.key);
          }
          current++;
          if (index < current + entry.value.length) {
            return _buildDiscoveryItem(entry.value[index - current]);
          }
          current += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGroupHeader(ReleaseStatusGroup group) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        ConnectionsLogic.releaseStatusGroupLabel(group),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7.6 — Discovery Tab Content with Lazy Loading
  // ---------------------------------------------------------------------------

  Widget _buildDiscoveryTab(SortedConnectionsData sortedData) {
    final collaborations = sortedData.collaborations;
    final spotlightItems = sortedData.spotlightItems;

    if (collaborations.isEmpty && spotlightItems.isEmpty) {
      return const Center(
        child: Text('No discoveries found.'),
      );
    }

    // If grouped by release status, show the old flat grouped view
    if (sortedData.discoveryGroups != null) {
      return _buildGroupedDiscoveryList(sortedData.discoveryGroups!);
    }

    // Build a combined list with section headers
    final allItems = <_GroupedItem>[];

    if (collaborations.isNotEmpty) {
      allItems.add(_GroupedItem.sectionHeader('Collaborations'));
      for (final item in collaborations) {
        allItems.add(_GroupedItem.item(item));
      }
    }

    if (spotlightItems.isNotEmpty) {
      allItems.add(_GroupedItem.sectionHeader('Spotlight'));
      for (final item in spotlightItems) {
        allItems.add(_GroupedItem.item(item));
      }
    }

    final visibleCount = _discoveryLoadedCount.clamp(0, allItems.length);
    final hasMore = visibleCount < allItems.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 300 &&
            hasMore &&
            !_isLoadingMore) {
          _loadMoreDiscovery(allItems.length);
        }
        return false;
      },
      child: ListView.builder(
        controller: _discoveryScrollController,
        padding: const EdgeInsets.all(8),
        itemCount: visibleCount + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visibleCount) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final grouped = allItems[index];
          if (grouped.isHeader) {
            if (grouped.sectionLabel != null) {
              return _buildSectionHeader(grouped.sectionLabel!);
            }
            return _buildGroupHeader(grouped.group!);
          }
          return _buildDiscoveryItem(grouped.discoveryItem!);
        },
      ),
    );
  }

  Widget _buildGroupedDiscoveryList(
      Map<ReleaseStatusGroup, List<DiscoveryItem>> groups) {
    final entries = groups.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    // Flatten for lazy loading
    final allItems = <_GroupedItem>[];
    for (final entry in entries) {
      allItems.add(_GroupedItem.header(entry.key));
      for (final item in entry.value) {
        allItems.add(_GroupedItem.item(item));
      }
    }

    final visibleCount = _discoveryLoadedCount.clamp(0, allItems.length);
    final hasMore = visibleCount < allItems.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 300 &&
            hasMore &&
            !_isLoadingMore) {
          _loadMoreDiscovery(allItems.length);
        }
        return false;
      },
      child: ListView.builder(
        controller: _discoveryScrollController,
        padding: const EdgeInsets.all(8),
        itemCount: visibleCount + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visibleCount) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final grouped = allItems[index];
          if (grouped.isHeader) {
            return _buildGroupHeader(grouped.group!);
          }
          return _buildDiscoveryItem(grouped.discoveryItem!);
        },
      ),
    );
  }

  void _loadMoreDiscovery(int totalCount) {
    setState(() {
      _isLoadingMore = true;
    });
    // Simulate a brief delay for batch loading
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _discoveryLoadedCount =
              (_discoveryLoadedCount + 20).clamp(0, totalCount);
          _isLoadingMore = false;
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Add to Watchlist from Discovery (Task 10.1)
  // ---------------------------------------------------------------------------

  Future<void> _handleAddToWatchlist(ConnectionWork work) async {
    try {
      final watchlistLogic = ref.read(watchlistLogicProvider);

      final entry = await watchlistLogic.addWorkToWatchlist(
        tmdbId: work.tmdbId,
        type: work.type,
        title: work.title,
        posterPath: work.posterPath,
        releaseDate: work.releaseDate,
      );

      // Invalidate providers to trigger recomputation (moves work from Discovery → Connections)
      ref.invalidate(watchlistEntriesProvider);
      ref.invalidate(connectionsDataProvider);

      if (!mounted) return;

      if (work.type == WorkType.tvShow) {
        final tvPrefs = entry.tvNotificationPrefs;
        final selectedTypes = tvPrefs?.selectedTypes ?? [];

        showTvWatchlistSnackBar(
          context,
          workTitle: work.title,
          selectedEpisodeTypes: selectedTypes,
          onUndo: () async {
            await watchlistLogic.removeWorkFromWatchlist(
              work.tmdbId,
              work.type,
            );
            ref.invalidate(watchlistEntriesProvider);
            ref.invalidate(connectionsDataProvider);
          },
          onEditPreferences: () {},
        );
      } else {
        showSimpleSnackBar(
          context,
          'Added "${work.title}" to watchlist',
        );
      }
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(
          context,
          'Failed to add to watchlist: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Discovery item builder — uses ConnectionWorkCard and PairGroupCard
  // ---------------------------------------------------------------------------

  Widget _buildDiscoveryItem(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) =>
        ConnectionWorkCard(
          work: work,
          onAddToWatchlist: _handleAddToWatchlist,
        ),
      PairGroupDiscoveryItem(:final pairGroup) =>
        PairGroupCard(
          pairGroup: pairGroup,
          onAddToWatchlist: _handleAddToWatchlist,
        ),
    };
  }
}

// Helper class for grouped discovery list
class _GroupedItem {
  final bool isHeader;
  final ReleaseStatusGroup? group;
  final String? sectionLabel;
  final DiscoveryItem? discoveryItem;

  _GroupedItem.header(this.group)
      : isHeader = true,
        sectionLabel = null,
        discoveryItem = null;

  _GroupedItem.sectionHeader(this.sectionLabel)
      : isHeader = true,
        group = null,
        discoveryItem = null;

  _GroupedItem.item(this.discoveryItem)
      : isHeader = false,
        group = null,
        sectionLabel = null;
}
