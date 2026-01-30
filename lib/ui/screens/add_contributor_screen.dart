import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/watchlist_entry.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import 'search_results_screen.dart';

class AddContributorScreen extends ConsumerStatefulWidget {
  final ContributorType? initialType;
  
  const AddContributorScreen({
    super.key,
    this.initialType,
  });

  @override
  ConsumerState<AddContributorScreen> createState() => _AddContributorScreenState();
}

class _AddContributorScreenState extends ConsumerState<AddContributorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late ContributorType _selectedType;
  List<Contributor> _results = [];
  int _totalPages = 0;
  int _totalResults = 0;
  bool _isLoading = false;
  String _hintText = 'e.g., Search...';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? ContributorType.person;
    _loadHint();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHint() async {
    final searchLogic = ref.read(searchLogicProvider);
    final prefs = ref.read(preferencesRepositoryProvider).getPreferences();
    
    // We don't want to block the UI, so we load it asynchronously
    final hint = await searchLogic.getDynamicHint(
      _selectedType,
      preferredRoles: prefs.defaultDepartments,
      collectionsEnabled: prefs.includeCollectionsInMovieSearch,
    );
    
    if (mounted) {
      setState(() => _hintText = hint);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    
    try {
      final searchLogic = ref.read(searchLogicProvider);
      final pageResult = await searchLogic.getContributorSuggestions(query, _selectedType);
      
      if (mounted) {
        setState(() {
          _results = pageResult.results;
          _totalPages = pageResult.totalPages;
          _totalResults = pageResult.totalResults; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        showSimpleSnackBar(context, 'Search failed: $e');
      }
    }
  }

  Future<void> _addContributor(Contributor contributor) async {
    try {
      final contributorLogic = ref.read(contributorLogicProvider);
      final prefs = ref.read(preferencesRepositoryProvider).getPreferences();

      List<String>? selectedDepts;
      List<String>? availableDepts;
      TvNotificationPreferences? tvNotificationPrefs;
      bool isAllSelected = false;

      if (contributor.type == ContributorType.person) {
        setState(() => _isLoading = true);
        availableDepts = await contributorLogic.getAvailableDepartments(contributor);
        setState(() => _isLoading = false);

        final initialSelection = availableDepts.where((d) => prefs.effectiveDefaultDepartments.contains(d)).toList();
        
        // Revised Logic matching user request:
        // "All" is only marked if global preference is "All" (True All).
        // Manual selection of all pills (initialSelection covering everything) 
        // does NOT automatically mark the "All" pill.
        final globalAll = (prefs.autoFollowNewRoles ?? true) && (prefs.allRolesSelected ?? false);
        
        if (globalAll) {
             isAllSelected = true;
        }

        // Extract just the role part from knownFor (before the "•" separator)
        final knownForRole = contributor.knownFor.isNotEmpty 
            ? contributor.knownFor.split('•').first.trim()
            : '';
        
        debugPrint('[AddContributor] contributor.knownFor: "${contributor.knownFor}"');
        debugPrint('[AddContributor] extracted knownForRole: "$knownForRole"');
        debugPrint('[AddContributor] initialSelection: $initialSelection');
        debugPrint('[AddContributor] availableDepts: $availableDepts');

        // Logic: specific defaults + knownFor -> or known for/first available
        if (initialSelection.isNotEmpty || knownForRole.isNotEmpty) {
          selectedDepts = {...initialSelection, if (knownForRole.isNotEmpty) knownForRole}.toList();
        } else if (availableDepts.isNotEmpty) {
             // Fallback: Take the first one
             selectedDepts = [availableDepts.first];
             isAllSelected = false; 
        } else {
           selectedDepts = [];
        }
        
        debugPrint('[AddContributor] final selectedDepts: $selectedDepts');
      } else if (contributor.type == ContributorType.tvShow) {
        // Use default TV notification preferences without showing dialog
        final defaultPrefs = prefs.defaultTvNotificationPrefs ?? TvNotificationPreferences();
        
        // Get TV show details for metadata
        setState(() => _isLoading = true);
        final tvDetails = await ref.read(tmdbServiceProvider).getTvDetails(contributor.tmdbId);
        setState(() => _isLoading = false);
        
        // Update contributor with TV show metadata and default preferences
        contributor = Contributor(
          tmdbId: contributor.tmdbId,
          name: contributor.name,
          type: contributor.type,
          profilePath: contributor.profilePath,
          notifyForDepartments: ['TV Show'],
          availableDepartments: ['TV Show'],
          knownFor: contributor.knownFor,
          tvNotificationPrefs: defaultPrefs,
          showStatus: tvDetails['status'],
          totalSeasons: tvDetails['number_of_seasons'],
          nextEpisodeDate: tvDetails['next_episode_to_air']?['air_date'],
        );
        
        tvNotificationPrefs = defaultPrefs;
      }

      setState(() => _isLoading = true);
      
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
          await watchlistLogic.addWorkToWatchlist(
            tmdbId: contributor.tmdbId,
            type: workType,
            title: contributor.name,
            posterPath: contributor.profilePath,
            releaseDate: null, // Will be populated from TMDB data if needed
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
      
      if (success) {
        // Refresh the appropriate providers based on what was added
        if (contributor.type == ContributorType.movie || 
            contributor.type == ContributorType.tvShow || 
            contributor.type == ContributorType.collection) {
          // Refresh watchlist providers
          ref.invalidate(watchlistEntriesProvider);
        } else {
          // Refresh contributors provider for people/companies
          ref.invalidate(contributorsProvider);
        }
        
        if (mounted) {
          // Return a map to indicate success and provide data for SnackBar
          Navigator.pop(context, {
            'contributor': contributor,
            'roles': selectedDepts,
            'availableRoles': availableDepts,
            'allRolesSelected': isAllSelected,
            'tvNotificationPrefs': tvNotificationPrefs,
          });
        }
      } else {
        if (mounted) {
           setState(() => _isLoading = false);
           final itemType = contributor.type == ContributorType.movie ? 'Movie' :
                           contributor.type == ContributorType.tvShow ? 'TV show' :
                           contributor.type == ContributorType.collection ? 'Collection' :
                           'Contributor';
           showSimpleSnackBar(context, '$itemType already followed.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSimpleSnackBar(context, 'Error adding contributor: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find something to follow'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: _hintText,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 16),
                SegmentedButton<ContributorType>(
                  segments: const [
                    ButtonSegment(value: ContributorType.person, label: Text('Person')),
                    ButtonSegment(value: ContributorType.company, label: Text('Company')),
                    ButtonSegment(value: ContributorType.movie, label: Text('Movie')),
                    ButtonSegment(value: ContributorType.tvShow, label: Text('TV Show')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<ContributorType> newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                      _loadHint(); // Update hint for new type
                      _focusNode.requestFocus(); // Return focus to search
                      // Re-trigger search if text exists
                      if (_searchController.text.length >= 2) {
                        _performSearch(_searchController.text);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              // Show max 5 items, or 6 if we need the "See More" button
              itemCount: (_results.length > 5) ? 6 : _results.length,
              itemBuilder: (context, index) {
                if (_results.length > 5 && index == 5) {
                  return ListTile(
                    leading: const Icon(Icons.search),
                    title: Text('See all results for "${_searchController.text}"'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchResultsScreen(
                            query: _searchController.text,
                            type: _selectedType,
                            initialResults: _results,
                            totalPages: _totalPages,
                            totalResults: _totalResults,
                          ),
                        ),
                      );
                    },
                  );
                }

                final contributor = _results[index];
                final isWatchlistItem = contributor.type == ContributorType.movie || 
                                       contributor.type == ContributorType.tvShow || 
                                       contributor.type == ContributorType.collection;
                
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 60,
                    color: contributor.type == ContributorType.company 
                        ? Colors.white 
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: contributor.profilePath != null
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w200${contributor.profilePath}',
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.person),
                          )
                        : const Icon(Icons.person),
                  ),
                  title: Text(contributor.name),
                  subtitle: Text(contributor.knownFor),
                  trailing: Icon(
                    isWatchlistItem ? Icons.bookmark_add : Icons.person_add,
                    color: isWatchlistItem 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary,
                  ),
                  onTap: () => _addContributor(contributor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
