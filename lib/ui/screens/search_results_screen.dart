import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../providers/providers.dart';
import '../common/department_selection_dialog.dart';
import '../common/snackbar_utils.dart';

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
      
      final success = await contributorLogic.addEnrichedContributor(
        contributor,
        overrideNotifyDepts: selectedDepts,
        overrideAvailableDepts: availableDepts,
        allRolesSelected: isAllSelected,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        if (success) {
          ref.invalidate(contributorsProvider);
          showSimpleSnackBar(context, 'Added ${contributor.name}');
        } else {
          showSimpleSnackBar(context, 'Already following.');
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final itemWidth = isWide ? (constraints.maxWidth / 2) - 16 : constraints.maxWidth;

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
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

              // Responsive Item
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: itemWidth),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: Container(
                        width: 50,
                        height: 75,
                        decoration: BoxDecoration(
                          color: contributor.type == ContributorType.company 
                              ? Colors.white 
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: contributor.profilePath != null
                            ? CachedNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w200${contributor.profilePath}',
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                              )
                            : Icon(contributor.type == ContributorType.person ? Icons.person : Icons.business),
                      ),
                      title: Text(contributor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(contributor.knownFor, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: isFollowed
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                                Text('Followed', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                              ],
                            )
                          : FilledButton.icon(
                              onPressed: () => _addContributor(contributor),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
