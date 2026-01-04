import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../providers/providers.dart';
import 'search_results_screen.dart';

class AddContributorScreen extends ConsumerStatefulWidget {
  const AddContributorScreen({super.key});

  @override
  ConsumerState<AddContributorScreen> createState() => _AddContributorScreenState();
}

class _AddContributorScreenState extends ConsumerState<AddContributorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  ContributorType _selectedType = ContributorType.person;
  List<Contributor> _results = [];
  int _totalPages = 0;
  int _totalResults = 0;
  bool _isLoading = false;
  String _hintText = 'e.g., Search...';

  @override
  void initState() {
    super.initState();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
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

        // Logic: specific defaults -> or known for/first available
        if (initialSelection.isNotEmpty) {
          selectedDepts = initialSelection;
        } else if (availableDepts.isNotEmpty) {
             // Fallback: Try to match "Known For" or take the first one
             if (availableDepts.contains(contributor.knownFor)) {
                selectedDepts = [contributor.knownFor];
             } else {
                selectedDepts = [availableDepts.first];
             }
             isAllSelected = false; 
        } else {
           selectedDepts = [];
        }
      }

      setState(() => _isLoading = true);
      
      final success = await contributorLogic.addEnrichedContributor(
        contributor,
        overrideNotifyDepts: selectedDepts,
        overrideAvailableDepts: availableDepts,
        allRolesSelected: isAllSelected,
      );
      
      if (success) {
        // Refresh the list in Home Screen
        ref.invalidate(contributorsProvider);
        
        if (mounted) {
          // Return a map to indicate success and provide data for SnackBar
          Navigator.pop(context, {
            'contributor': contributor,
            'roles': selectedDepts,
            'availableRoles': availableDepts,
            'allRolesSelected': isAllSelected,
          });
        }
      } else {
        if (mounted) {
           setState(() => _isLoading = false);
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contributor already followed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding contributor: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Contributor'),
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
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 60,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  trailing: const Icon(Icons.add),
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