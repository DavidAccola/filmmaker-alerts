import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/preferences.dart';
import '../../data/models/watchlist_entry.dart';
import '../../providers/providers.dart';
import '../common/contributor_card.dart';
import '../common/department_selection_dialog.dart';
import '../common/release_preferences_dialog.dart';
import '../common/snackbar_utils.dart';
import '../common/tmdb_attribution.dart';
import 'add_contributor_screen.dart';
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
    final fabRaised = ref.watch(fabRaisedProvider);
    final fabBottomPadding = fabRaised ? 70.0 : 0.0;

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

  void _scrollToNewContributor(Contributor newContributor) {
    // Wait for the UI to rebuild with the new contributor
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;
      
      // Give a bit more time for the UI to fully render
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Try to find the widget with the new contributor's key and scroll to it
      final context = _newContributorKey.currentContext;
      if (context != null) {
        try {
          await Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            alignment: 0.1, // Show the item near the top of the screen
          );
        } catch (e) {
          // Fallback to approximate scrolling if ensureVisible fails
          _fallbackScrollToContributor(newContributor);
        }
      } else {
        // Fallback if we can't find the context
        _fallbackScrollToContributor(newContributor);
      }
    });
  }

  void _fallbackScrollToContributor(Contributor newContributor) {
    // Fallback method using improved calculations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;
      
      final contributorsAsync = ref.read(contributorsProvider);
      final prefsAsync = ref.read(preferencesProvider);
      
      await contributorsAsync.when(
        data: (contributors) async {
          final prefs = prefsAsync.value ?? Preferences();
          final sortedList = _sortContributors(contributors, prefs.homeSortOrder ?? 'dateAdded');
          final isGrouped = prefs.groupByType ?? true;
          
          if (isGrouped) {
            // Find which group the new contributor belongs to
            final groups = <ContributorType, List<Contributor>>{};
            for (var c in sortedList) {
              groups.putIfAbsent(c.type, () => []).add(c);
            }
            
            final displayTypes = [
              ContributorType.person,
              ContributorType.movie,
              ContributorType.collection,
              ContributorType.tvShow,
              ContributorType.company,
            ].where((t) => groups.containsKey(t)).toList();
            
            // Find the group index
            final groupIndex = displayTypes.indexOf(newContributor.type);
            if (groupIndex >= 0) {
              // Calculate approximate scroll offset to the group
              double scrollOffset = 0;
              
              // Add offset for previous groups (more conservative estimates)
              for (int i = 0; i < groupIndex; i++) {
                final prevType = displayTypes[i];
                final prevGroupSize = groups[prevType]?.length ?? 0;
                
                // Group header: approximately 60px
                scrollOffset += 60;
                
                // Items in the group: use more conservative height estimates
                final useGrid = MediaQuery.of(context).size.width >= 600 && (prefs.useGridView ?? true);
                
                if (useGrid) {
                  // Grid: estimate 2 items per row, ~160px per row
                  final rows = (prevGroupSize / 2).ceil();
                  scrollOffset += rows * 170; // 160px + 10px spacing
                } else {
                  // List: estimate 140px per item (more conservative)
                  scrollOffset += prevGroupSize * 140;
                }
              }
              
              // Ensure we don't scroll past the end and add some buffer
              final maxScroll = _scrollController.position.maxScrollExtent;
              scrollOffset = (scrollOffset - 100).clamp(0.0, maxScroll); // 100px buffer to show above
              
              await _scrollController.animateTo(
                scrollOffset,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              );
            }
          } else {
            // Find the position of the new contributor in the flat list
            final index = sortedList.indexWhere((c) => c.tmdbId == newContributor.tmdbId);
            if (index >= 0) {
              final useGrid = MediaQuery.of(context).size.width >= 600 && (prefs.useGridView ?? true);
              double scrollOffset;
              
              if (useGrid) {
                // Grid: estimate 2 items per row, ~160px per row
                final row = (index / 2).floor();
                scrollOffset = row * 170; // 160px + 10px spacing
              } else {
                // List: estimate 140px per item
                scrollOffset = index * 140;
              }
              
              // Ensure we don't scroll past the end and add buffer
              final maxScroll = _scrollController.position.maxScrollExtent;
              scrollOffset = (scrollOffset - 100).clamp(0.0, maxScroll); // 100px buffer
              
              await _scrollController.animateTo(
                scrollOffset,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              );
            }
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    });
  }
  
  Widget _buildContributorsList(List<Contributor> contributors, Preferences prefs, AsyncValue<Preferences> prefsAsync) {
    if (contributors.isEmpty) {
      return const Center(
        child: Text('No items in this category yet.'),
      );
    }

    final sortedList = _sortContributors(contributors, prefs.homeSortOrder ?? 'dateAdded');

    return Column(
      children: [
        // Display Settings button in top right
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: prefsAsync.when(
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
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Contributors list
        Expanded(
          child: _buildContributorsListContent(sortedList, prefs),
        ),
      ],
    );
  }

  Widget _buildContributorsListContent(List<Contributor> sortedList, Preferences prefs) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;
        final useGrid = isLargeScreen && (prefs.useGridView ?? true);
        final isGrouped = prefs.groupByType ?? true; // Default to true

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
                          ),
                        );
                      },
                      childCount: groups[type]!.length,
                    ),
                  ),
              ],
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
                      );
                    },
                    childCount: sortedList.length,
                  ),
                ),
              ),
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
                        ),
                      );
                    },
                    childCount: sortedList.length,
                  ),
                ),
              ),
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
        ),
      );

      if (result != null) {
        final newPrefs = result['preferences'] as TvNotificationPreferences;
        final oldPrefs = contributor.tvNotificationPrefs ?? TvNotificationPreferences();
        
        // Check if preferences actually changed
        final hasChanges = oldPrefs.seriesPremiere != newPrefs.seriesPremiere ||
                          oldPrefs.seasonPremieres != newPrefs.seasonPremieres ||
                          oldPrefs.seasonFinales != newPrefs.seasonFinales ||
                          oldPrefs.newEpisodes != newPrefs.newEpisodes ||
                          oldPrefs.specials != newPrefs.specials;
        
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
          );
          
          await logic.updateContributorRoles(updatedContributor, contributor.notifyForDepartments);
          ref.invalidate(contributorsProvider);
          
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'TV preferences updated.',
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
              'No changes made to TV preferences.',
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
          debugPrint('[HomeScreen] Opening DepartmentSelectionDialog for ${contributor.name}');
          debugPrint('[HomeScreen] availableDepartments: ${contributor.availableDepartments}');
          debugPrint('[HomeScreen] initialSelectedDepartments: ${contributor.notifyForDepartments}');
          debugPrint('[HomeScreen] initialAllRolesSelected: ${contributor.allRolesSelected ?? false}');
          
          return DepartmentSelectionDialog(
            name: contributor.name,
            availableDepartments: contributor.availableDepartments,
            initialSelectedDepartments: contributor.notifyForDepartments,
            defaultDepartments: prefs.effectiveDefaultDepartments,
            initialAllRolesSelected: contributor.allRolesSelected ?? false,
            allowTrueAll: prefs.autoFollowNewRoles ?? true,
          );
        },
      );

      if (result != null && result is Map) {
        final selectedDepts = result['roles'] as List<String>;
        final allSelected = result['allRolesSelected'] as bool;
        
        // Check if roles actually changed
        final oldRoles = Set<String>.from(contributor.notifyForDepartments);
        final newRoles = Set<String>.from(selectedDepts);
        final oldAllSelected = contributor.allRolesSelected ?? false;
        
        const setEquality = SetEquality<String>();
        final hasRoleChanges = !setEquality.equals(oldRoles, newRoles) || oldAllSelected != allSelected;
        
        if (hasRoleChanges) {
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
          );
          
          await logic.updateContributorRoles(updatedContributor, selectedDepts);
          ref.invalidate(contributorsProvider);
          
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'Roles updated.',
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
              'No changes made to roles.',
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

  const _TvNotificationPreferencesDialog({
    required this.showName,
    required this.currentPrefs,
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

  @override
  void initState() {
    super.initState();
    seriesPremiere = widget.currentPrefs.seriesPremiere;
    seasonPremieres = widget.currentPrefs.seasonPremieres;
    seasonFinales = widget.currentPrefs.seasonFinales;
    newEpisodes = widget.currentPrefs.newEpisodes;
    specials = widget.currentPrefs.specials;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.showName} Notifications'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
