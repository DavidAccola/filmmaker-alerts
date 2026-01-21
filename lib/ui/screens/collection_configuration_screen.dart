import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/movie_status_entry.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';

class CollectionConfigurationScreen extends ConsumerStatefulWidget {
  final int collectionId;
  final String collectionTitle;

  const CollectionConfigurationScreen({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
  });

  @override
  ConsumerState<CollectionConfigurationScreen> createState() => _CollectionConfigurationScreenState();
}

class _CollectionConfigurationScreenState extends ConsumerState<CollectionConfigurationScreen> {
  bool _isEditMode = false;
  WatchStatus _selectedMode = WatchStatus.wantToWatch;
  bool _isDirty = false;
  bool _isLoading = true;
  String? _error;
  
  // Collection data
  Map<String, dynamic>? _collectionData;
  List<Map<String, dynamic>> _movies = [];
  
  // Local state for tracking changes
  final Map<int, Set<WatchStatus>> _localStatuses = {};
  
  // Filter state
  Set<WatchStatus> _statusFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  @override
  void initState() {
    super.initState();
    _loadCollectionData();
  }

  Future<void> _loadCollectionData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final tmdbService = ref.read(tmdbServiceProvider);
      final collectionData = await tmdbService.getCollectionDetails(widget.collectionId);
      
      setState(() {
        _collectionData = collectionData;
        _movies = List<Map<String, dynamic>>.from(collectionData['parts'] ?? []);
        _isLoading = false;
      });

      // Load existing statuses
      _loadExistingStatuses();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadExistingStatuses() {
    final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
    
    for (final movie in _movies) {
      final movieId = movie['id'] as int;
      final existingEntry = movieStatusRepo.getMovie(widget.collectionId, movieId);
      
      if (existingEntry != null) {
        _localStatuses[movieId] = existingEntry.currentStatuses.toSet();
      } else {
        _localStatuses[movieId] = {};
      }
    }
  }

  void _toggleEditMode() {
    if (_isEditMode && _isDirty) {
      _showUnsavedChangesDialog();
    } else {
      setState(() {
        _isEditMode = !_isEditMode;
        if (!_isEditMode) {
          _isDirty = false;
        }
      });
    }
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isEditMode = false;
                _isDirty = false;
                _loadExistingStatuses(); // Reset to saved state
              });
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveChanges();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleMovieStatus(int movieId, String movieTitle, DateTime? releaseDate) {
    if (!_isEditMode) return;

    setState(() {
      final currentStatuses = _localStatuses[movieId] ?? <WatchStatus>{};
      
      if (currentStatuses.contains(_selectedMode)) {
        // Remove the status
        currentStatuses.remove(_selectedMode);
      } else {
        // Add the status (with conflict clearing)
        _clearConflictingStatuses(currentStatuses, _selectedMode);
        currentStatuses.add(_selectedMode);
      }
      
      _localStatuses[movieId] = currentStatuses;
      _isDirty = true;
    });
  }

  void _clearConflictingStatuses(Set<WatchStatus> statuses, WatchStatus newStatus) {
    switch (newStatus) {
      case WatchStatus.watched:
        statuses.removeAll([WatchStatus.inProgress, WatchStatus.wantToWatch]);
        break;
      case WatchStatus.inProgress:
        statuses.remove(WatchStatus.wantToWatch);
        break;
      case WatchStatus.wantToWatch:
        statuses.remove(WatchStatus.inProgress);
        break;
      case WatchStatus.dnf:
        // DNF doesn't clear other statuses automatically
        break;
    }
  }

  void _markAllMovies() {
    if (!_isEditMode) return;

    setState(() {
      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        final currentStatuses = _localStatuses[movieId] ?? <WatchStatus>{};
        
        _clearConflictingStatuses(currentStatuses, _selectedMode);
        currentStatuses.add(_selectedMode);
        _localStatuses[movieId] = currentStatuses;
      }
      _isDirty = true;
    });
  }

  void _unmarkAllMovies() {
    if (!_isEditMode) return;

    setState(() {
      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        final currentStatuses = _localStatuses[movieId] ?? <WatchStatus>{};
        currentStatuses.remove(_selectedMode);
        _localStatuses[movieId] = currentStatuses;
      }
      _isDirty = true;
    });
  }

  Future<void> _saveChanges() async {
    try {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      
      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        final movieTitle = movie['title'] as String;
        final releaseDate = movie['release_date'] != null 
            ? DateTime.tryParse(movie['release_date']) 
            : null;
        
        final newStatuses = _localStatuses[movieId] ?? <WatchStatus>{};
        final existingEntry = movieStatusRepo.getMovie(widget.collectionId, movieId);
        final existingStatuses = existingEntry?.currentStatuses.toSet() ?? <WatchStatus>{};
        
        // Add new statuses
        for (final status in newStatuses) {
          if (!existingStatuses.contains(status)) {
            final statusRecord = StatusRecord(
              status: status,
              setAt: DateTime.now(),
              watchDates: status == WatchStatus.watched ? [DateTime.now()] : null,
            );
            
            await movieStatusRepo.addStatusRecord(
              collectionId: widget.collectionId,
              movieId: movieId,
              movieTitle: movieTitle,
              statusRecord: statusRecord,
              releaseDate: releaseDate,
            );
          }
        }
        
        // Remove old statuses
        for (final status in existingStatuses) {
          if (!newStatuses.contains(status)) {
            await movieStatusRepo.removeStatus(
              collectionId: widget.collectionId,
              movieId: movieId,
              status: status,
            );
          }
        }
      }
      
      setState(() {
        _isDirty = false;
        _isEditMode = false;
      });
      
      if (mounted) {
        showSimpleSnackBar(context, 'Changes saved successfully');
      }
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(context, 'Error saving changes: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMovies {
    if (_statusFilters.length == 4) {
      return _movies; // Show all if all filters selected
    }
    
    return _movies.where((movie) {
      final movieId = movie['id'] as int;
      final statuses = _localStatuses[movieId] ?? <WatchStatus>{};
      
      if (statuses.isEmpty) {
        // Show unmarked items only if "Want to watch" is selected (default assumption)
        return _statusFilters.contains(WatchStatus.wantToWatch);
      }
      
      return statuses.any((status) => _statusFilters.contains(status));
    }).toList();
  }

  String _getStatusSymbol(WatchStatus status) {
    switch (status) {
      case WatchStatus.wantToWatch:
        return '📖';
      case WatchStatus.inProgress:
        return '▶';
      case WatchStatus.watched:
        return '✓';
      case WatchStatus.dnf:
        return '✗';
    }
  }

  String _getStatusName(WatchStatus status) {
    switch (status) {
      case WatchStatus.wantToWatch:
        return 'Want to watch';
      case WatchStatus.inProgress:
        return 'In progress';
      case WatchStatus.watched:
        return 'Watched';
      case WatchStatus.dnf:
        return 'Did not finish';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.collectionTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.collectionTitle),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCollectionData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredMovies = _filteredMovies;
    final isFiltered = _statusFilters.length < 4;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isDirty) {
          _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.collectionTitle),
              if (isFiltered)
                Text(
                  'Filtered',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          actions: [
            // Filter button
            PopupMenuButton<WatchStatus>(
              icon: Icon(
                Icons.filter_list,
                color: isFiltered ? Theme.of(context).colorScheme.primary : null,
              ),
              onSelected: (status) {
                setState(() {
                  if (_statusFilters.contains(status)) {
                    _statusFilters.remove(status);
                  } else {
                    _statusFilters.add(status);
                  }
                  
                  // Ensure at least one filter is selected
                  if (_statusFilters.isEmpty) {
                    _statusFilters.add(status);
                  }
                });
              },
              itemBuilder: (context) => WatchStatus.values.map((status) {
                final isSelected = _statusFilters.contains(status);
                return CheckedPopupMenuItem<WatchStatus>(
                  value: status,
                  checked: isSelected,
                  child: Row(
                    children: [
                      Text(_getStatusSymbol(status)),
                      const SizedBox(width: 8),
                      Text(_getStatusName(status)),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            // Edit mode toggle
            IconButton(
              onPressed: _toggleEditMode,
              icon: Icon(_isEditMode ? Icons.close : Icons.edit),
              tooltip: _isEditMode ? 'Exit Edit Mode' : 'Edit Mode',
            ),
          ],
        ),
        body: Column(
          children: [
            // Edit mode controls
            if (_isEditMode) ...[
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Mode selector
                    Row(
                      children: [
                        const Text('Mode: '),
                        ...WatchStatus.values.map((status) {
                          final isSelected = _selectedMode == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_getStatusSymbol(status)),
                                  const SizedBox(width: 4),
                                  Text(_getStatusName(status)),
                                ],
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedMode = status);
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Bulk controls
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _markAllMovies,
                          child: Text('Mark all as ${_getStatusName(_selectedMode)}'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _unmarkAllMovies,
                          child: Text('Unmark all ${_getStatusName(_selectedMode)}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Mode snackbar
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Marking movies as ${_getStatusSymbol(_selectedMode)} ${_getStatusName(_selectedMode)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            // Movies grid
            Expanded(
              child: filteredMovies.isEmpty
                  ? const Center(
                      child: Text('No movies match the current filters'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredMovies.length,
                      itemBuilder: (context, index) {
                        final movie = filteredMovies[index];
                        final movieId = movie['id'] as int;
                        final movieTitle = movie['title'] as String;
                        final posterPath = movie['poster_path'] as String?;
                        final releaseDate = movie['release_date'] != null 
                            ? DateTime.tryParse(movie['release_date']) 
                            : null;
                        
                        final statuses = _localStatuses[movieId] ?? <WatchStatus>{};
                        final hasSelectedStatus = statuses.contains(_selectedMode);
                        
                        return Card(
                          child: InkWell(
                            onTap: _isEditMode 
                                ? () => _toggleMovieStatus(movieId, movieTitle, releaseDate)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Poster
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: posterPath != null
                                        ? ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            child: Image.network(
                                              'https://image.tmdb.org/t/p/w500$posterPath',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                                            ),
                                          )
                                        : const Icon(Icons.movie, size: 48),
                                  ),
                                ),
                                
                                // Title and status
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Status symbols
                                          if (statuses.isNotEmpty) ...[
                                            ...statuses.map((status) => Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Text(_getStatusSymbol(status)),
                                            )),
                                            const SizedBox(width: 4),
                                          ],
                                          
                                          // Edit mode indicator
                                          if (_isEditMode && hasSelectedStatus)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _getStatusSymbol(_selectedMode),
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      
                                      Text(
                                        movieTitle,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      
                                      if (releaseDate != null)
                                        Text(
                                          '${releaseDate.year}',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        
        // Save button
        floatingActionButton: _isDirty
            ? FloatingActionButton.extended(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              )
            : null,
      ),
    );
  }
}