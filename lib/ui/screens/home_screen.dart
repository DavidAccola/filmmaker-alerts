import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/models/contributor.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import '../common/contributor_card.dart';
import '../common/department_selection_dialog.dart';
import '../common/snackbar_utils.dart';
import '../common/tmdb_attribution.dart';
import 'contributor_detail_screen.dart';
import 'movie_detail_screen.dart';
import 'tv_show_detail_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _newContributorKey = GlobalKey();
  int? _newlyAddedContributorId; // Track the newly added contributor
  
  TabController? _tabController;
  bool _isInitialized = false;

  // People filter state
  bool _showFilmmakers = true;
  bool _showCompanies = true;
  bool _showHidden = false;

  /// Whether any filter is actively hiding items.
  bool get _hasActiveFilters => !_showFilmmakers || !_showCompanies;

  /// Helper to update FAB raised state via provider
  void _setFabRaised(bool raised) {
    ref.read(fabRaisedProvider.notifier).setRaised(raised);
  }

  void _initTabController(int initialIndex) {
    if (_isInitialized) return;
    _isInitialized = true;
    
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      // Update provider when user swipes or taps tab
      final currentProviderValue = ref.read(homeTabProvider);
      if (currentProviderValue != _tabController!.index) {
        ref.read(homeTabProvider.notifier).setTab(_tabController!.index);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _navigateToDetail(Contributor contributor) {
    if (contributor.type == ContributorType.person ||
        contributor.type == ContributorType.company ||
        contributor.type == ContributorType.collection) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContributorDetailScreen(contributor: contributor),
        ),
      );
    } else if (contributor.type == ContributorType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailScreen(
            movieId: contributor.tmdbId,
            movieTitle: contributor.name,
          ),
        ),
      );
    } else if (contributor.type == ContributorType.tvShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TvShowDetailScreen(
            showId: contributor.tmdbId,
            showTitle: contributor.name,
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final contributorsAsync = ref.watch(contributorsProvider);
    final prefsAsync = ref.watch(preferencesProvider);
    final homeTab = ref.watch(homeTabProvider);
    final scrollTarget = ref.watch(watchlistScrollTargetProvider);
    // Watch fabRaised to trigger rebuilds when snackbar visibility changes
    ref.watch(fabRaisedProvider);

    // Initialize TabController with current provider value (only once)
    _initTabController(homeTab);

    // Sync TabController with provider when provider changes externally
    if (_tabController != null && _tabController!.index != homeTab) {
      _tabController!.animateTo(homeTab);
    }

    // If TabController not ready yet, show loading
    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Following'),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh All',
              onPressed: () async {
                final logic = ref.read(contributorLogicProvider);
                showSimpleSnackBar(
                  context,
                  'Refreshing contributors...',
                  duration: const Duration(seconds: 1),
                  onSnackBarVisibilityChanged: (isVisible) {
                    _setFabRaised(isVisible);
                  },
                );
                await logic.refreshAllContributors();
                ref.invalidate(contributorsProvider);
                if (context.mounted) {
                  showSimpleSnackBar(
                    context,
                    'Refresh complete.',
                    onSnackBarVisibilityChanged: (isVisible) {
                      _setFabRaised(isVisible);
                    },
                  );
                }
              },
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController!,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          onTap: (index) {
            // Update provider when user taps tab
            ref.read(homeTabProvider.notifier).setTab(index);
          },
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Watchlist'),
          ],
        ),
      ),
      body: contributorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (contributors) {
          if (contributors.isEmpty) {
            return const Center(
              child: Text('No contributors followed yet.\nAdd one to get started!'),
            );
          }

          final prefs = prefsAsync.value ?? Preferences();
          
          // Separate contributors by type
          final peopleContributors = _filterPeopleContributors(contributors);
          
          return TabBarView(
            controller: _tabController!,
            children: [
              // People tab - only show person/company contributors
              _buildContributorsList(peopleContributors, prefs, prefsAsync),
              // Watchlist tab
              WatchlistScreen(scrollToTmdbId: scrollTarget),
            ],
          );
        },
      ),
    );
  }

  
  Widget _buildContributorsList(List<Contributor> contributors, Preferences prefs, AsyncValue<Preferences> prefsAsync) {
    if (contributors.isEmpty) {
      return const Center(
        child: Text('No items in this category yet.'),
      );
    }

    // Split into active and hidden
    final activeContributors = contributors.where((c) => !c.isHidden).toList();
    final hiddenContributors = contributors.where((c) => c.isHidden).toList();

    // Apply type filters to active contributors
    final filteredActive = activeContributors.where((c) {
      if (c.type == ContributorType.person && !_showFilmmakers) return false;
      if (c.type == ContributorType.company && !_showCompanies) return false;
      return true;
    }).toList();

    final sortedList = _sortContributors(filteredActive, prefs.homeSortOrder ?? 'dateAdded');
    final sortedHidden = _showHidden ? _sortContributors(hiddenContributors, prefs.homeSortOrder ?? 'dateAdded') : <Contributor>[];

    // Calculate filtered-out count for badge
    int filteredOutCount = 0;
    if (!_showFilmmakers) filteredOutCount += activeContributors.where((c) => c.type == ContributorType.person).length;
    if (!_showCompanies) filteredOutCount += activeContributors.where((c) => c.type == ContributorType.company).length;
    if (!_showHidden) filteredOutCount += hiddenContributors.length;

    return Column(
      children: [
        // Toolbar with filter and display settings
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              // Filter button
              PopupMenuButton<String>(
                icon: Badge(
                  isLabelVisible: filteredOutCount > 0,
                  label: Text('$filteredOutCount'),
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: 'Filter',
                onSelected: (value) {
                  setState(() {
                    if (value == 'filmmakers') {
                      _showFilmmakers = !_showFilmmakers;
                    } else if (value == 'companies') {
                      _showCompanies = !_showCompanies;
                    } else if (value == 'showHidden') {
                      _showHidden = !_showHidden;
                    }
                  });
                },
                itemBuilder: (context) {
                  final filmmakersCount = _showFilmmakers ? 0 : activeContributors.where((c) => c.type == ContributorType.person).length;
                  final companiesCount = _showCompanies ? 0 : activeContributors.where((c) => c.type == ContributorType.company).length;
                  final hiddenCount = _showHidden ? 0 : hiddenContributors.length;

                  return [
                    CheckedPopupMenuItem(
                      value: 'filmmakers',
                      checked: _showFilmmakers,
                      child: Row(
                        children: [
                          const Text('Filmmakers'),
                          if (filmmakersCount > 0) ...[
                            const Spacer(),
                            Text(
                              '+$filmmakersCount',
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
                      value: 'companies',
                      checked: _showCompanies,
                      child: Row(
                        children: [
                          const Text('Companies'),
                          if (companiesCount > 0) ...[
                            const Spacer(),
                            Text(
                              '+$companiesCount',
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
              // Display Settings button
              prefsAsync.when(
                data: (prefs) => PopupMenuButton<String>(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Display Settings',
                  onSelected: (value) async {
                    final repo = ref.read(preferencesRepositoryProvider);
                    if (value == 'toggle_group') {
                      prefs.groupByType = !(prefs.groupByType ?? true);
                    } else if (value == 'toggle_view') {
                      prefs.useGridView = !(prefs.useGridView ?? true);
                    } else {
                      prefs.homeSortOrder = value;
                    }
                    await repo.savePreferences(prefs);
                    ref.invalidate(preferencesProvider);
                  },
                  itemBuilder: (context) {
                    final currentSort = prefs.homeSortOrder ?? 'dateAdded';
                    final isGrouped = prefs.groupByType ?? true;
                    final isGrid = prefs.useGridView ?? true;

                    return [
                      const PopupMenuItem(
                        enabled: false,
                        height: 32,
                        child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'dateAdded',
                        child: Row(
                          children: [
                            if (currentSort == 'dateAdded') const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                            const Text('Date Added'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'name',
                        child: Row(
                          children: [
                            if (currentSort == 'name') const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                            const Text('Alphabetical'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'latestRelease',
                        child: Row(
                          children: [
                            if (currentSort == 'latestRelease') const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                            const Text('Latest Release'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        height: 32,
                        child: Text('Group by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      CheckedPopupMenuItem(
                        value: 'toggle_group',
                        checked: isGrouped,
                        child: const Text('Group by Type'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'toggle_view',
                        child: Row(
                          children: [
                            Icon(isGrid ? Icons.view_list : Icons.grid_view, size: 18),
                            const SizedBox(width: 8),
                            Text(isGrid ? 'Switch to Detail View' : 'Switch to Grid View'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        // Filtered indicator
        if (_hasActiveFilters)
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
                  'Filtered (${filteredActive.length} of ${activeContributors.length})',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showFilmmakers = true;
                      _showCompanies = true;
                    });
                  },
                  child: const Text('Show All'),
                ),
              ],
            ),
          ),
        // Contributors list
        Expanded(
          child: _buildContributorsListContent(sortedList, prefs, sortedHidden),
        ),
      ],
    );
  }

  Widget _buildContributorsListContent(List<Contributor> sortedList, Preferences prefs, List<Contributor> hiddenList) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;
        final useGrid = isLargeScreen && (prefs.useGridView ?? true);
        final isGrouped = prefs.groupByType ?? true; // Default to true
        final theme = Theme.of(context);

        if (isGrouped) {
          // Grouping Logic
          final Map<ContributorType, List<Contributor>> groups = {};
          for (var c in sortedList) {
            groups.putIfAbsent(c.type, () => []).add(c);
          }

          // Sort types for consistent display (Person first, then Movie, etc.)
          final displayTypes = [
            ContributorType.person,
            ContributorType.movie,
            ContributorType.collection,
            ContributorType.tvShow,
            ContributorType.company,
          ].where((t) => groups.containsKey(t)).toList();

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              for (var type in displayTypes) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      _getTypeLabel(type).toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                if (useGrid)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        // Use a smaller aspect ratio (taller cards) on narrower screens
                        final screenWidth = constraints.crossAxisExtent;
                        final aspectRatio = screenWidth < 500 ? 2.3 : 2.7;
                        
                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            childAspectRatio: aspectRatio,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final contributor = groups[type]![index];
                              return ContributorCard(
                                key: contributor.tmdbId == _newlyAddedContributorId 
                                    ? _newContributorKey 
                                    : ValueKey(contributor.tmdbId),
                                contributor: contributor,
                                onTap: () => _navigateToDetail(contributor),
                                onRemove: () => _removeContributor(context, ref, contributor),
                                onEditRoles: () => _editRoles(context, ref, contributor),
                                onHide: () => _hideContributor(context, ref, contributor),
                              );
                            },
                            childCount: groups[type]!.length,
                          ),
                        );
                      },
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contributor = groups[type]![index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ContributorCard(
                            key: contributor.tmdbId == _newlyAddedContributorId 
                                ? _newContributorKey 
                                : ValueKey(contributor.tmdbId),
                            contributor: contributor,
                            onTap: () => _navigateToDetail(contributor),
                            onRemove: () => _removeContributor(context, ref, contributor),
                            onEditRoles: () => _editRoles(context, ref, contributor),
                            onHide: () => _hideContributor(context, ref, contributor),
                          ),
                        );
                      },
                      childCount: groups[type]!.length,
                    ),
                  ),
              ],
              // Hidden section
              ..._buildHiddenSlivers(hiddenList, useGrid, theme),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [TmdbAttribution()],
                ),
              ),
            ],
          );
        }

        // Normal Flat View
        if (useGrid) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    childAspectRatio: 2.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final contributor = sortedList[index];
                      return ContributorCard(
                        key: contributor.tmdbId == _newlyAddedContributorId 
                            ? _newContributorKey 
                            : ValueKey(contributor.tmdbId),
                        contributor: contributor,
                        onTap: () => _navigateToDetail(contributor),
                        onRemove: () => _removeContributor(context, ref, contributor),
                        onEditRoles: () => _editRoles(context, ref, contributor),
                        onHide: () => _hideContributor(context, ref, contributor),
                      );
                    },
                    childCount: sortedList.length,
                  ),
                ),
              ),
              // Hidden section
              ..._buildHiddenSlivers(hiddenList, true, theme),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [TmdbAttribution()],
                ),
              ),
            ],
          );
        } else {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final contributor = sortedList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ContributorCard(
                          key: contributor.tmdbId == _newlyAddedContributorId 
                              ? _newContributorKey 
                              : ValueKey(contributor.tmdbId),
                          contributor: contributor,
                          onTap: () => _navigateToDetail(contributor),
                          onRemove: () => _removeContributor(context, ref, contributor),
                          onEditRoles: () => _editRoles(context, ref, contributor),
                          onHide: () => _hideContributor(context, ref, contributor),
                        ),
                      );
                    },
                    childCount: sortedList.length,
                  ),
                ),
              ),
              // Hidden section
              ..._buildHiddenSlivers(hiddenList, false, theme),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [TmdbAttribution()],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  /// Builds sliver widgets for the hidden section (matching watchlist pattern).
  List<Widget> _buildHiddenSlivers(List<Contributor> hiddenList, bool useGrid, ThemeData theme) {
    if (hiddenList.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Divider(color: theme.colorScheme.outlineVariant),
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
                child: Divider(color: theme.colorScheme.outlineVariant),
              ),
            ],
          ),
        ),
      ),
      if (useGrid)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              childAspectRatio: 2.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final contributor = hiddenList[index];
                return Opacity(
                  opacity: 0.5,
                  child: ContributorCard(
                    key: ValueKey('hidden_${contributor.tmdbId}'),
                    contributor: contributor,
                    onTap: () => _navigateToDetail(contributor),
                    onRemove: () => _removeContributor(context, ref, contributor),
                    onEditRoles: () => _editRoles(context, ref, contributor),
                    onHide: () => _unhideContributor(context, ref, contributor),
                  ),
                );
              },
              childCount: hiddenList.length,
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final contributor = hiddenList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Opacity(
                  opacity: 0.5,
                  child: ContributorCard(
                    key: ValueKey('hidden_${contributor.tmdbId}'),
                    contributor: contributor,
                    onTap: () => _navigateToDetail(contributor),
                    onRemove: () => _removeContributor(context, ref, contributor),
                    onEditRoles: () => _editRoles(context, ref, contributor),
                    onHide: () => _unhideContributor(context, ref, contributor),
                  ),
                ),
              );
            },
            childCount: hiddenList.length,
          ),
        ),
    ];
  }

  Future<void> _hideContributor(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final repo = ref.read(contributorRepositoryProvider);
    await repo.setHidden(contributor.tmdbId, true);
    ref.invalidate(contributorsProvider);

    if (context.mounted) {
      showSnoozedSnackBar(
        context,
        contributor.name,
        () async {
          await repo.setHidden(contributor.tmdbId, false);
          ref.invalidate(contributorsProvider);
        },
        onSnackBarVisibilityChanged: (isVisible) => _setFabRaised(isVisible),
      );
    }
  }

  Future<void> _unhideContributor(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final repo = ref.read(contributorRepositoryProvider);
    await repo.setHidden(contributor.tmdbId, false);
    ref.invalidate(contributorsProvider);
  }

  List<Contributor> _filterPeopleContributors(List<Contributor> contributors) {
    return contributors.where((c) => 
      c.type == ContributorType.person || 
      c.type == ContributorType.company
    ).toList();
  }

  List<Contributor> _sortContributors(List<Contributor> list, String sortOrder) {
    final sorted = List<Contributor>.from(list);
    switch (sortOrder) {
      case 'name':
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'latestRelease':
        sorted.sort((a, b) {
          final dateA = a.latestWork?.releaseDate ?? '';
          final dateB = b.latestWork?.releaseDate ?? '';
          if (dateA == dateB) return a.name.compareTo(b.name);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
      case 'dateAdded':
      default:
        sorted.sort((a, b) {
          final dateA = a.followedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.followedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (dateA == dateB) return a.name.compareTo(b.name);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
    }
    return sorted;
  }

  String _getTypeLabel(ContributorType type) {
    switch (type) {
      case ContributorType.person: return 'Filmmakers';
      case ContributorType.movie: return 'Movies';
      case ContributorType.collection: return 'Collections';
      case ContributorType.tvShow: return 'TV Shows';
      case ContributorType.company: return 'Companies';
    }
  }

  Future<void> _removeContributor(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final repo = ref.read(contributorRepositoryProvider);
    
    // 1. Remove immediately
    await repo.removeContributor(contributor.tmdbId);
    ref.invalidate(contributorsProvider);

    // 2. Show Undo SnackBar
    if (context.mounted) {
      showRemovalSnackBar(
        context,
        message: 'Unfollowed ${contributor.name}',
        onSnackBarVisibilityChanged: (isVisible) {
          _setFabRaised(isVisible);
        },
        onUndo: () async {
          // 3. Re-add if Undone
          await repo.addContributor(contributor);
          ref.invalidate(contributorsProvider);
        },
      );
    }
  }

  Future<void> _editRoles(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final logic = ref.read(contributorLogicProvider);
    final repo = ref.read(preferencesRepositoryProvider);
    final prefs = repo.getPreferences();
    
    if (contributor.type == ContributorType.tvShow) {
      // Handle TV show preferences editing
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _TvNotificationPreferencesDialog(
          showName: contributor.name,
          currentPrefs: contributor.tvNotificationPrefs ?? TvNotificationPreferences(),
          initialNotificationsPaused: contributor.notificationsSnoozed,
        ),
      );

      if (result != null) {
        final newPrefs = result['preferences'] as TvNotificationPreferences;
        final newNotificationsPaused = result['notificationsPaused'] as bool;
        final oldPrefs = contributor.tvNotificationPrefs ?? TvNotificationPreferences();
        
        // Check if preferences actually changed
        final hasPrefsChanges = oldPrefs.seriesPremiere != newPrefs.seriesPremiere ||
                          oldPrefs.seasonPremieres != newPrefs.seasonPremieres ||
                          oldPrefs.seasonFinales != newPrefs.seasonFinales ||
                          oldPrefs.newEpisodes != newPrefs.newEpisodes ||
                          oldPrefs.specials != newPrefs.specials;
        final hasPauseChanges = contributor.notificationsSnoozed != newNotificationsPaused;
        final hasChanges = hasPrefsChanges || hasPauseChanges;
        
        if (hasChanges) {
          // Create updated contributor with new TV preferences
          final updatedContributor = Contributor(
            tmdbId: contributor.tmdbId,
            name: contributor.name,
            type: contributor.type,
            profilePath: contributor.profilePath,
            notifyForDepartments: contributor.notifyForDepartments,
            availableDepartments: contributor.availableDepartments,
            knownFor: contributor.knownFor,
            latestWork: contributor.latestWork,
            followedAt: contributor.followedAt,
            tvNotificationPrefs: newPrefs,
            showStatus: contributor.showStatus,
            totalSeasons: contributor.totalSeasons,
            nextEpisodeDate: contributor.nextEpisodeDate,
            notificationsSnoozed: newNotificationsPaused,
            isHidden: contributor.isHidden,
          );
          
          await logic.updateContributorRoles(updatedContributor, contributor.notifyForDepartments);
          ref.invalidate(contributorsProvider);
          
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'Notification preferences updated.',
              onSnackBarVisibilityChanged: (isVisible) {
                _setFabRaised(isVisible);
              },
            );
          }
        } else {
          // No changes made
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'No changes made.',
              onSnackBarVisibilityChanged: (isVisible) {
                _setFabRaised(isVisible);
              },
            );
          }
        }
      }
    } else {
      // Handle person role editing (existing logic)
      final result = await showDialog<dynamic>(
        context: context,
        builder: (context) {
          return DepartmentSelectionDialog(
            name: contributor.name,
            availableDepartments: contributor.availableDepartments,
            initialSelectedDepartments: contributor.notifyForDepartments,
            defaultDepartments: prefs.effectiveDefaultDepartments,
            initialAllRolesSelected: contributor.allRolesSelected ?? false,
            allowTrueAll: prefs.autoFollowNewRoles ?? true,
            initialNotificationsPaused: contributor.notificationsSnoozed,
          );
        },
      );

      if (result != null && result is Map) {
        final selectedDepts = result['roles'] as List<String>;
        final allSelected = result['allRolesSelected'] as bool;
        final newNotificationsPaused = result['notificationsPaused'] as bool;
        
        // Check if roles actually changed
        final oldRoles = Set<String>.from(contributor.notifyForDepartments);
        final newRoles = Set<String>.from(selectedDepts);
        final oldAllSelected = contributor.allRolesSelected ?? false;
        
        const setEquality = SetEquality<String>();
        final hasRoleChanges = !setEquality.equals(oldRoles, newRoles) || oldAllSelected != allSelected;
        final hasPauseChanges = contributor.notificationsSnoozed != newNotificationsPaused;
        final hasChanges = hasRoleChanges || hasPauseChanges;
        
        if (hasChanges) {
          // Create updated contributor with new flags
          final updatedContributor = Contributor(
            tmdbId: contributor.tmdbId,
            name: contributor.name,
            type: contributor.type,
            profilePath: contributor.profilePath,
            notifyForDepartments: selectedDepts,
            availableDepartments: contributor.availableDepartments, 
            knownFor: contributor.knownFor,
            latestWork: contributor.latestWork,
            followedAt: contributor.followedAt,
            allRolesSelected: allSelected,
            tvNotificationPrefs: contributor.tvNotificationPrefs, // Preserve TV preferences
            showStatus: contributor.showStatus,
            totalSeasons: contributor.totalSeasons,
            nextEpisodeDate: contributor.nextEpisodeDate,
            notificationsSnoozed: newNotificationsPaused,
            isHidden: contributor.isHidden,
          );
          
          await logic.updateContributorRoles(updatedContributor, selectedDepts);
          ref.invalidate(contributorsProvider);
          
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'Notification preferences updated.',
              onSnackBarVisibilityChanged: (isVisible) {
                _setFabRaised(isVisible);
              },
            );
          }
        } else {
          // No changes made
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'No changes made.',
              onSnackBarVisibilityChanged: (isVisible) {
                _setFabRaised(isVisible);
              },
            );
          }
        }
      }
    }
  }
}

class _TvNotificationPreferencesDialog extends StatefulWidget {
  final String showName;
  final TvNotificationPreferences currentPrefs;
  final bool initialNotificationsPaused;

  const _TvNotificationPreferencesDialog({
    required this.showName,
    required this.currentPrefs,
    this.initialNotificationsPaused = false,
  });

  @override
  State<_TvNotificationPreferencesDialog> createState() => _TvNotificationPreferencesDialogState();
}

class _TvNotificationPreferencesDialogState extends State<_TvNotificationPreferencesDialog> {
  late bool seriesPremiere;
  late bool seasonPremieres;
  late bool seasonFinales;
  late bool newEpisodes;
  late bool specials;
  late bool notificationsPaused;

  @override
  void initState() {
    super.initState();
    seriesPremiere = widget.currentPrefs.seriesPremiere;
    seasonPremieres = widget.currentPrefs.seasonPremieres;
    seasonFinales = widget.currentPrefs.seasonFinales;
    newEpisodes = widget.currentPrefs.newEpisodes;
    specials = widget.currentPrefs.specials;
    notificationsPaused = widget.initialNotificationsPaused;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Notification preferences for ${widget.showName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pause notifications toggle
            SwitchListTile(
              title: const Text('Pause notifications'),
              subtitle: Text(
                notificationsPaused 
                    ? 'Notifications are paused' 
                    : 'Notifications are active',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: notificationsPaused,
              onChanged: (value) {
                setState(() {
                  notificationsPaused = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Choose which types of notifications you want for this show:'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Series Premiere'),
              subtitle: const Text('First episode of brand new shows'),
              value: seriesPremiere,
              onChanged: (value) => setState(() => seriesPremiere = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('Season Premieres'),
              subtitle: const Text('First episode of any season'),
              value: seasonPremieres,
              onChanged: (value) => setState(() => seasonPremieres = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('Season Finales'),
              subtitle: const Text('Last episode of any season'),
              value: seasonFinales,
              onChanged: (value) => setState(() => seasonFinales = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('New Episodes'),
              subtitle: const Text('All episodes as they air'),
              value: newEpisodes,
              onChanged: (value) => setState(() => newEpisodes = value ?? false),
            ),
            CheckboxListTile(
              title: const Text('Specials'),
              subtitle: const Text('Holiday specials and one-offs'),
              value: specials,
              onChanged: (value) => setState(() => specials = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final preferences = TvNotificationPreferences(
              seriesPremiere: seriesPremiere,
              seasonPremieres: seasonPremieres,
              seasonFinales: seasonFinales,
              newEpisodes: newEpisodes,
              specials: specials,
            );
            
            Navigator.pop(context, {
              'preferences': preferences,
              'notificationsPaused': notificationsPaused,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
