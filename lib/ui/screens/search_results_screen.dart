import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/watchlist_entry.dart';
import '../../providers/providers.dart';
import '../common/department_selection_dialog.dart';
import '../common/snackbar_utils.dart';
import 'home_screen.dart';

enum SearchSort { relevance, name }

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final ContributorType type;
  final List<Contributor> initialResults;
  final int totalPages;
  final int totalResults;

  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.type,
    required this.initialResults,
    required this.totalPages,
    required this.totalResults,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late List<Contributor> _results;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalResults = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _results = List.from(widget.initialResults);
    _scrollController.addListener(_onScroll);
    _totalPages = widget.totalPages; 
    _totalResults = widget.totalResults;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    try {
      final searchLogic = ref.read(searchLogicProvider);
      final prefs = ref.read(preferencesRepositoryProvider).getPreferences();
      final nextPage = _currentPage + 1;
      final result = await searchLogic.searchGlobal(
        widget.query, 
        widget.type, 
        page: nextPage,
        includeCollections: prefs.includeCollectionsInMovieSearch,
      );
      
      if (mounted) {
        setState(() {
          _results.addAll(result.results);
          _currentPage = result.currentPage;
          _totalPages = result.totalPages;
          _totalResults = result.totalResults;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
       if (mounted) {
         setState(() => _isLoadingMore = false);
         showSimpleSnackBar(context, 'Failed to load more results: $e');
       }
    }
  }

  Future<void> _addContributor(Contributor contributor) async {
    try {
      final contributorLogic = ref.read(contributorLogicProvider);
      final prefs = ref.read(preferencesRepositoryProvider).getPreferences();

      List<String>? selectedDepts;
      List<String>? availableDepts;
      bool isAllSelected = false;

      if (contributor.type == ContributorType.person) {
        // Show loading while fetching details/departments
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        
        availableDepts = await contributorLogic.getAvailableDepartments(contributor);
        
        if (mounted) {
          Navigator.pop(context); // Close loading
          
          final initialSelection = availableDepts.where((d) => prefs.defaultDepartments.contains(d)).toList();
          
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) => DepartmentSelectionDialog(
              name: contributor.name,
              availableDepartments: availableDepts!,
              initialSelectedDepartments: initialSelection.isEmpty && availableDepts.isNotEmpty 
                  ? [availableDepts[0]] 
                  : initialSelection,
              defaultDepartments: prefs.effectiveDefaultDepartments,
              allowTrueAll: prefs.autoFollowNewRoles ?? true,
            ),
          );

          if (result == null) return; 
          selectedDepts = result['roles'] as List<String>;
          isAllSelected = result['allRolesSelected'] as bool;
        }
      }

      // Show another loading while adding/enriching
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }
      
      bool success;
      
      // Route movies, TV shows, and collections to watchlist directly
      if (contributor.type == ContributorType.movie || 
          contributor.type == ContributorType.tvShow || 
          contributor.type == ContributorType.collection) {
        
        final watchlistLogic = ref.read(watchlistLogicProvider);
        
        // Create contributor snapshot
        final contributorSnapshot = ContributorSnapshot(
          contributorId: contributor.tmdbId,
          name: contributor.name,
          role: contributor.type == ContributorType.movie ? 'Movie' : 
                contributor.type == ContributorType.tvShow ? 'TV Show' : 'Collection',
        );

        // Determine work type and release type
        WorkType workType;
        ReleaseType releaseType;
        
        if (contributor.type == ContributorType.movie) {
          workType = WorkType.movie;
          releaseType = ReleaseType.theatrical;
        } else if (contributor.type == ContributorType.tvShow) {
          workType = WorkType.tvShow;
          releaseType = ReleaseType.streaming;
        } else {
          workType = WorkType.movie; // Collections are treated as movies
          releaseType = ReleaseType.theatrical;
        }

        try {
          // Parse release date from search result if available
          DateTime? releaseDate;
          if (contributor.releaseDateRaw != null && contributor.releaseDateRaw!.isNotEmpty) {
            releaseDate = DateTime.tryParse(contributor.releaseDateRaw!);
          }

          await watchlistLogic.addWorkToWatchlist(
            tmdbId: contributor.tmdbId,
            type: workType,
            title: contributor.name,
            posterPath: contributor.profilePath,
            releaseDate: releaseDate,
            releaseType: releaseType,
            followedContributors: [contributorSnapshot],
          );
          success = true;
        } catch (e) {
          if (e.toString().contains('already exists')) {
            success = false; // Already in watchlist
          } else {
            rethrow;
          }
        }
      } else {
        // Use regular method for people and companies
        success = await contributorLogic.addEnrichedContributor(
          contributor,
          overrideNotifyDepts: selectedDepts,
          overrideAvailableDepts: availableDepts,
          allRolesSelected: isAllSelected,
        );
      }
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        if (success) {
          // Refresh the appropriate providers based on what was added
          if (contributor.type == ContributorType.movie || 
              contributor.type == ContributorType.tvShow || 
              contributor.type == ContributorType.collection) {
            // Refresh watchlist providers
            ref.invalidate(watchlistEntriesProvider);
            
            // Show watchlist snackbar with undo and navigation
            showWatchlistSnackBar(
              context,
              message: '${contributor.name} added to watchlist',
              onUndo: () async {
                final watchlistLogic = ref.read(watchlistLogicProvider);
                final workType = contributor.type == ContributorType.movie ? WorkType.movie :
                                contributor.type == ContributorType.tvShow ? WorkType.tvShow :
                                WorkType.movie;
                await watchlistLogic.removeWorkFromWatchlist(
                  contributor.tmdbId,
                  workType,
                );
                ref.invalidate(watchlistEntriesProvider);
              },
              onView: () {
                // Set tab and scroll target via providers
                ref.read(homeTabProvider.notifier).setTab(1);
                ref.read(watchlistScrollTargetProvider.notifier).setTarget(contributor.tmdbId);
                
                // Clear scroll target after a delay
                Future.delayed(const Duration(seconds: 2), () {
                  ref.read(watchlistScrollTargetProvider.notifier).clear();
                });
                
                // Pop back to home screen
                Navigator.of(context).popUntil((route) {
                  // Pop until we find the home screen or reach the root
                  return route.isFirst || route.settings.name == '/home';
                });
                
                // Now push a new HomeScreen with watchlist tab selected
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
            );
          } else {
            // Refresh contributors provider for people/companies
            ref.invalidate(contributorsProvider);
            showSimpleSnackBar(context, 'Added ${contributor.name} to Contributors');
          }
        } else {
          final itemType = contributor.type == ContributorType.movie ? 'Movie' :
                          contributor.type == ContributorType.tvShow ? 'TV show' :
                          contributor.type == ContributorType.collection ? 'Collection' :
                          'Contributor';
          showSimpleSnackBar(context, '$itemType already followed.');
        }
      }
    } catch (e) {
      if (mounted) {
        // Ensure loading check is closed
        try { Navigator.pop(context); } catch (_) {}
        showSimpleSnackBar(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final followedList = ref.watch(contributorsProvider).maybeWhen(
      data: (list) => list.map((c) => c.tmdbId).toSet(),
      orElse: () => <int>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Results for "${widget.query}"', style: theme.textTheme.titleMedium),
            Text('${widget.type.name.toUpperCase()} - $_totalResults results found', 
                 style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
          ],
        ),
        actions: [
          PopupMenuButton<SearchSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) {
              setState(() {
                if (sort == SearchSort.name) {
                  _results.sort((a, b) => a.name.compareTo(b.name));
                } else {
                  // Re-sorting requires re-fetching from API
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: SearchSort.relevance, child: Text('Sort by Relevance')),
              const PopupMenuItem(value: SearchSort.name, child: Text('Sort by Name (A-Z)')),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _results.length + 1, // +1 for footer (loader, button, or spacer)
        itemBuilder: (context, index) {
          if (index == _results.length) {
            if (_isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            if (_currentPage < _totalPages) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Load More Results'),
                  ),
                ),
              );
            }
            
            return const SizedBox(height: 40);
          }

          final contributor = _results[index];
          final isFollowed = followedList.contains(contributor.tmdbId);
          final isWatchlistItem = contributor.type == ContributorType.movie || 
                                 contributor.type == ContributorType.tvShow || 
                                 contributor.type == ContributorType.collection;

          return ListTile(
            leading: Container(
              width: 40,
              height: 60,
              color: contributor.type == ContributorType.company 
                  ? (theme.brightness == Brightness.dark ? Colors.grey[300] : Colors.white)
                  : theme.colorScheme.surfaceContainerHighest,
              child: contributor.profilePath != null
                  ? Padding(
                      padding: contributor.type == ContributorType.company
                          ? const EdgeInsets.symmetric(horizontal: 4)
                          : EdgeInsets.zero,
                      child: CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w200${contributor.profilePath}',
                        fit: BoxFit.contain,
                        errorWidget: (ctx, url, err) => const Icon(Icons.person),
                      ),
                    )
                  : const Icon(Icons.person),
            ),
            title: Text(contributor.name),
            subtitle: Text(contributor.knownFor, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: isFollowed
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : Icon(
                    Icons.add_circle,
                    color: isWatchlistItem 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
            onTap: isFollowed ? null : () => _addContributor(contributor),
          );
        },
      ),
    );
  }
}
