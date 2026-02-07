import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/status_record.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/expand_poster_button.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/notification_prefs_chips.dart';
import '../common/external_navigation_utils.dart';
import '../common/status_colors.dart';
import 'movie_detail_screen.dart';

class CollectionConfigurationScreen extends ConsumerStatefulWidget {
  final int collectionId;
  final String collectionTitle;
  final WatchStatus? initialMarkAllStatus;

  const CollectionConfigurationScreen({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
    this.initialMarkAllStatus,
  });

  @override
  ConsumerState<CollectionConfigurationScreen> createState() =>
      _CollectionConfigurationScreenState();
}

class _CollectionConfigurationScreenState
    extends ConsumerState<CollectionConfigurationScreen> {
  // Track pending changes: Map<movieId, Set<WatchStatus>>
  final Map<int, Set<WatchStatus>> _pendingChanges = {};

  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  bool _isDirty = false;
  bool _isOrderDirty = false;
  bool _isPosterHovered = false;
  bool _isLoading = true;
  String? _error;

  // Collection data from TMDB
  Map<String, dynamic>? _collectionData;
  List<Map<String, dynamic>> _movies = [];
  
  // Custom movie order (list of movie IDs)
  List<int> _movieOrder = [];

  // Undo/Redo history stacks
  final List<Map<int, Set<WatchStatus>>> _undoStack = [];
  final List<Map<int, Set<WatchStatus>>> _redoStack = [];

  Map<int, Set<WatchStatus>> _copyPendingChanges() {
    final copy = <int, Set<WatchStatus>>{};
    for (final entry in _pendingChanges.entries) {
      copy[entry.key] = Set<WatchStatus>.from(entry.value);
    }
    return copy;
  }

  void _saveToUndoStack() {
    _undoStack.add(_copyPendingChanges());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_copyPendingChanges());
      final previousState = _undoStack.removeLast();
      _pendingChanges.clear();
      _pendingChanges.addAll(previousState);
      _isDirty = _undoStack.isNotEmpty;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_copyPendingChanges());
      final nextState = _redoStack.removeLast();
      _pendingChanges.clear();
      _pendingChanges.addAll(nextState);
      _isDirty = true;
    });
  }

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
      _collectionData = await tmdbService.getCollectionDetails(widget.collectionId);
      _movies = List<Map<String, dynamic>>.from(_collectionData?['parts'] ?? []);
      
      // Sort movies by release date (default order)
      _movies.sort((a, b) {
        final aDate = a['release_date'] as String?;
        final bDate = b['release_date'] as String?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      
      // Load custom order if it exists
      final orderRepo = ref.read(collectionOrderRepositoryProvider);
      final savedOrder = orderRepo.getMovieOrder(widget.collectionId);
      if (savedOrder != null && savedOrder.isNotEmpty) {
        // Reorder movies based on saved order
        _movieOrder = savedOrder;
        _applyCustomOrder();
      } else {
        // Use default order (by release date)
        _movieOrder = _movies.map((m) => m['id'] as int).toList();
      }

      _initializeLocalChanges();

      setState(() => _isLoading = false);
      
      // Apply initial mark all status if provided
      if (widget.initialMarkAllStatus != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleMarkAllStatus(widget.initialMarkAllStatus!);
          }
        });
      }
      
      // Fetch movie details in background to get streaming options
      _fetchMovieDetails();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Fetches movie details for all movies in the collection to get streaming options.
  Future<void> _fetchMovieDetails() async {
    final workLogic = ref.read(workLogicProvider);
    final prefsAsync = ref.read(preferencesProvider);
    final regionCode = prefsAsync.whenOrNull(data: (p) => p?.streamingCountry) ?? 'US';
    
    for (final movie in _movies) {
      final movieId = movie['id'] as int;
      await workLogic.fetchAndCacheMovieDetail(movieId, regionCode: regionCode);
    }
    
    // Refresh UI after fetching
    if (mounted) {
      setState(() {});
    }
  }

  /// Applies the custom order to the movies list
  void _applyCustomOrder() {
    final movieMap = {for (var m in _movies) m['id'] as int: m};
    final orderedMovies = <Map<String, dynamic>>[];
    
    // Add movies in custom order
    for (final id in _movieOrder) {
      if (movieMap.containsKey(id)) {
        orderedMovies.add(movieMap[id]!);
        movieMap.remove(id);
      }
    }
    
    // Add any remaining movies (new movies not in saved order)
    orderedMovies.addAll(movieMap.values);
    
    _movies = orderedMovies;
    
    // Update order to include any new movies
    _movieOrder = _movies.map((m) => m['id'] as int).toList();
  }

  /// Handles reordering of movies
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final movie = _movies.removeAt(oldIndex);
      _movies.insert(newIndex, movie);
      
      // Update the order list
      _movieOrder = _movies.map((m) => m['id'] as int).toList();
      _isOrderDirty = true;
      _isDirty = true;
    });
  }

  void _initializeLocalChanges() {
    final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
    
    for (final movie in _movies) {
      final movieId = movie['id'] as int;
      final existingEntry = movieStatusRepo.getMovie(widget.collectionId, movieId);
      
      if (existingEntry != null && existingEntry.statusRecords.isNotEmpty) {
        _pendingChanges[movieId] = existingEntry.currentStatuses.toSet();
      }
    }
  }

  Set<WatchStatus> _getEffectiveMovieStatuses(int movieId) {
    if (_pendingChanges.containsKey(movieId)) {
      return _pendingChanges[movieId]!;
    }
    
    final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
    final movie = movieStatusRepo.getMovie(widget.collectionId, movieId);
    if (movie != null && movie.statusRecords.isNotEmpty) {
      return movie.statusRecords.map((r) => r.status).toSet();
    }
    
    return {};
  }

  Map<WatchStatus, int> _getCollectionStatusCounts() {
    final counts = <WatchStatus, int>{};
    
    for (final movie in _movies) {
      final movieId = movie['id'] as int;
      final statuses = _getEffectiveMovieStatuses(movieId);
      for (final status in statuses) {
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  Future<void> _showUnsavedChangesDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _handleSave();
      if (mounted) Navigator.pop(context);
    } else if (result == 'discard') {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleSave() async {
    try {
      final movieStatusRepo = ref.read(movieStatusRepositoryProvider);
      final orderRepo = ref.read(collectionOrderRepositoryProvider);

      // Save status changes
      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        final movieTitle = movie['title'] as String;
        final releaseDate = movie['release_date'] != null
            ? DateTime.tryParse(movie['release_date'])
            : null;

        final newStatuses = _pendingChanges[movieId] ?? <WatchStatus>{};
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

      // Save custom order if changed
      if (_isOrderDirty) {
        await orderRepo.setMovieOrder(widget.collectionId, _movieOrder);
      }

      setState(() {
        _isDirty = false;
        _isOrderDirty = false;
        _undoStack.clear();
        _redoStack.clear();
      });

      if (mounted) {
        showSimpleSnackBar(context, 'Changes saved');
      }
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(context, 'Error saving: $e');
      }
    }
  }

  void _handleMarkAllStatus(WatchStatus status) {
    _saveToUndoStack();

    setState(() {
      // Check if all movies already have this status
      bool allHaveStatus = true;
      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        final statuses = _getEffectiveMovieStatuses(movieId);
        if (!statuses.contains(status)) {
          allHaveStatus = false;
          break;
        }
      }

      for (final movie in _movies) {
        final movieId = movie['id'] as int;
        var currentStatuses = Set<WatchStatus>.from(_getEffectiveMovieStatuses(movieId));

        if (allHaveStatus) {
          currentStatuses.remove(status);
        } else {
          _applyStatusTransitionRules(currentStatuses, status);
          currentStatuses.add(status);
        }

        _pendingChanges[movieId] = currentStatuses;
      }

      _isDirty = true;
    });
  }

  void _handleMovieStatusTap(int movieId, WatchStatus status) {
    _saveToUndoStack();

    setState(() {
      var currentStatuses = Set<WatchStatus>.from(_getEffectiveMovieStatuses(movieId));

      if (currentStatuses.contains(status)) {
        currentStatuses.remove(status);
      } else {
        _applyStatusTransitionRules(currentStatuses, status);
        currentStatuses.add(status);
      }

      _pendingChanges[movieId] = currentStatuses;
      _isDirty = true;
    });
  }

  void _applyStatusTransitionRules(Set<WatchStatus> statuses, WatchStatus newStatus) {
    switch (newStatus) {
      case WatchStatus.inProgress:
        statuses.remove(WatchStatus.wantToWatch);
        break;
      case WatchStatus.watched:
        statuses.removeAll([WatchStatus.wantToWatch, WatchStatus.inProgress]);
        break;
      case WatchStatus.wantToWatch:
        statuses.remove(WatchStatus.dnf);
        break;
      case WatchStatus.dnf:
        statuses.removeAll([WatchStatus.wantToWatch, WatchStatus.inProgress, WatchStatus.watched]);
        break;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: WatchStatus.values.map((status) {
              return CheckboxListTile(
                title: Text(_getStatusName(status)),
                value: _selectedFilters.contains(status),
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      _selectedFilters.add(status);
                    } else if (_selectedFilters.length > 1) {
                      _selectedFilters.remove(status);
                    }
                  });
                  setState(() {});
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
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
        appBar: AppBar(title: Text(widget.collectionTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.collectionTitle)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadCollectionData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isDirty && mounted) {
          await _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.collectionTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.isNotEmpty ? _undo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: 'Redo',
            ),
            if (_selectedFilters.length < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Chip(
                    label: const Text('Filtered'),
                    onDeleted: () {
                      setState(() {
                        _selectedFilters = {
                          WatchStatus.wantToWatch,
                          WatchStatus.inProgress,
                          WatchStatus.watched,
                          WatchStatus.dnf,
                        };
                      });
                    },
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildMetadataHeader(),
            _buildMarkAllRow(),
            Expanded(child: _buildMoviesList()),
          ],
        ),
        floatingActionButton: _isDirty
            ? FloatingActionButton(
                onPressed: _handleSave,
                tooltip: 'Save',
                child: const Icon(Icons.check),
              )
            : null,
      ),
    );
  }

  /// Builds the metadata header with poster, title, and movie count.
  Widget _buildMetadataHeader() {
    final theme = Theme.of(context);
    
    final posterPath = _collectionData?['poster_path'] as String?;
    final name = _collectionData?['name'] as String? ?? widget.collectionTitle;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPoster(posterPath, name),
          const SizedBox(width: 16),
          Expanded(child: _buildCollectionInfo(name)),
        ],
      ),
    );
  }

  Widget _buildPoster(String? posterPath, String name) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isPosterHovered = true),
      onExit: (_) => setState(() => _isPosterHovered = false),
      child: SizedBox(
        width: 100,
        height: 150,
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: 'https://image.tmdb.org/t/p/w300$posterPath',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Icon(Icons.video_library, size: 40),
                        errorWidget: (context, url, error) => const Icon(Icons.video_library, size: 40),
                      )
                    : const Icon(Icons.video_library, size: 40),
              ),
            ),
            // Expand poster button
            Positioned(
              top: 4,
              left: 4,
              child: ExpandPosterButton(
                posterPath: posterPath,
                title: name,
                isCardHovered: _isPosterHovered,
                iconSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionInfo(String name) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(preferencesProvider);
    final prefs = prefsAsync.whenOrNull(data: (p) => p);
    
    // Calculate year range from movies
    final years = _movies
        .map((m) => m['release_date'] as String?)
        .where((d) => d != null && d.isNotEmpty)
        .map((d) => DateTime.tryParse(d!)?.year)
        .whereType<int>()
        .toList();
    years.sort();
    
    String yearRange = 'Unknown';
    if (years.isNotEmpty) {
      if (years.length == 1) {
        yearRange = years.first.toString();
      } else {
        yearRange = '${years.first}–${years.last}';
      }
    }
    
    // Calculate average rating
    final ratings = _movies
        .map((m) => m['vote_average'] as num?)
        .whereType<num>()
        .where((r) => r > 0)
        .toList();
    final avgRating = ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        AdaptiveTooltipText(
          name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        
        // Year range
        Text(
          yearRange,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        
        // Movie count
        Text(
          '${_movies.length} Movie${_movies.length == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Average rating
        if (avgRating != null && !(prefs?.hideRatingsInDetails ?? false))
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                avgRating.toStringAsFixed(1),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' avg',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        
        // Notification preferences chips
        const SizedBox(height: 8),
        NotificationPrefsChips(
          tmdbId: widget.collectionId,
          workType: WorkType.movie, // Collections are groups of movies
        ),
      ],
    );
  }

  /// Builds the "Mark All" row with status buttons.
  Widget _buildMarkAllRow() {
    final theme = Theme.of(context);
    final statusCounts = _getCollectionStatusCounts();
    final totalMovies = _movies.length;
    
    // Helper to generate tooltip based on whether all movies have the status
    String tooltipFor(WatchStatus status, String statusName) {
      final allHaveStatus = statusCounts[status] == totalMovies;
      return allHaveStatus ? 'Unmark all as $statusName' : 'Mark all as $statusName';
    }
    
    return _HoverableRow(
      child: (isHovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isHovered 
              ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            // Status buttons for marking all movies
            SizedBox(
              width: 112, // 4 buttons * 28px = 112px
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MovieStatusButton(
                    icon: Icons.bookmark_border,
                    activeIcon: Icons.bookmark,
                    status: WatchStatus.wantToWatch,
                    isActive: statusCounts[WatchStatus.wantToWatch] == totalMovies,
                    isRowHovered: isHovered,
                    tooltip: tooltipFor(WatchStatus.wantToWatch, 'Want to watch'),
                    size: 26,
                    fixedWidth: 28,
                    onTap: () => _handleMarkAllStatus(WatchStatus.wantToWatch),
                  ),
                  _MovieStatusButton(
                    icon: Icons.play_circle_outline,
                    activeIcon: Icons.play_circle,
                    status: WatchStatus.inProgress,
                    isActive: statusCounts[WatchStatus.inProgress] == totalMovies,
                    isRowHovered: isHovered,
                    tooltip: tooltipFor(WatchStatus.inProgress, 'In progress'),
                    size: 26,
                    fixedWidth: 28,
                    onTap: () => _handleMarkAllStatus(WatchStatus.inProgress),
                  ),
                  _MovieStatusButton(
                    icon: Icons.check_circle_outline,
                    activeIcon: Icons.check_circle,
                    status: WatchStatus.watched,
                    isActive: statusCounts[WatchStatus.watched] == totalMovies,
                    isRowHovered: isHovered,
                    tooltip: tooltipFor(WatchStatus.watched, 'Watched'),
                    size: 26,
                    fixedWidth: 28,
                    onTap: () => _handleMarkAllStatus(WatchStatus.watched),
                  ),
                  _MovieStatusButton(
                    icon: Icons.cancel_outlined,
                    activeIcon: Icons.cancel,
                    status: WatchStatus.dnf,
                    isActive: statusCounts[WatchStatus.dnf] == totalMovies,
                    isRowHovered: isHovered,
                    tooltip: tooltipFor(WatchStatus.dnf, 'Did not finish'),
                    size: 26,
                    fixedWidth: 28,
                    onTap: () => _handleMarkAllStatus(WatchStatus.dnf),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Mark All Movies',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the list of movies with status buttons.
  Widget _buildMoviesList() {
    // Filter movies based on selected filters
    final filteredMovies = _movies.where((movie) {
      final movieId = movie['id'] as int;
      final statuses = _getEffectiveMovieStatuses(movieId);
      
      // Show movie if it has no status (unmarked) or if any of its statuses match the filter
      if (statuses.isEmpty) {
        return _selectedFilters.length == 4; // Show unmarked only if all filters selected
      }
      return statuses.any((s) => _selectedFilters.contains(s));
    }).toList();
    
    if (filteredMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No movies match the current filter',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
    
    // Use ReorderableListView when no filters are active
    final isFiltered = _selectedFilters.length < 4;
    
    if (isFiltered) {
      // Regular list when filtered (can't reorder filtered list)
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: filteredMovies.length,
        itemBuilder: (context, index) {
          final movie = filteredMovies[index];
          return _buildMovieItem(movie, index + 1, showDragHandle: false);
        },
      );
    }
    
    // Reorderable list when not filtered
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _movies.length,
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final movie = _movies[index];
        return _buildMovieItem(movie, index + 1, showDragHandle: true, reorderIndex: index);
      },
    );
  }

  /// Builds a movie item row with status buttons, poster, title, and year.
  Widget _buildMovieItem(Map<String, dynamic> movie, int displayIndex, {bool showDragHandle = false, int? reorderIndex}) {
    final movieId = movie['id'] as int;
    final title = movie['title'] as String? ?? 'Unknown';
    final posterPath = movie['poster_path'] as String?;
    final releaseDate = movie['release_date'] as String?;
    final year = releaseDate != null && releaseDate.isNotEmpty
        ? DateTime.tryParse(releaseDate)?.year.toString() ?? ''
        : '';
    
    final effectiveStatuses = _getEffectiveMovieStatuses(movieId);
    
    // Check if movie has streaming options from cached movie detail
    final movieDetailRepo = ref.read(movieDetailRepositoryProvider);
    final movieDetail = movieDetailRepo.getMovieDetail(movieId);
    final hasStreaming = movieDetail?.streamingOptions.isNotEmpty ?? false;
    
    return _MovieRow(
      key: ValueKey(movieId),
      movieId: movieId,
      title: title,
      posterPath: posterPath,
      year: year,
      displayIndex: displayIndex,
      effectiveStatuses: effectiveStatuses,
      hasStreaming: hasStreaming,
      showDragHandle: showDragHandle,
      reorderIndex: reorderIndex,
      onStatusTap: _handleMovieStatusTap,
      onNavigate: () => _navigateToMovieDetails(movieId, title),
    );
  }

  void _navigateToMovieDetails(int movieId, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MovieDetailScreen(
          movieId: movieId,
          movieTitle: title,
        ),
      ),
    );
  }
}

/// Movie row widget that shows status buttons, poster thumbnail, title, year, and streaming icon.
class _MovieRow extends ConsumerStatefulWidget {
  final int movieId;
  final String title;
  final String? posterPath;
  final String year;
  final int displayIndex;
  final Set<WatchStatus> effectiveStatuses;
  final bool hasStreaming;
  final bool showDragHandle;
  final int? reorderIndex;
  final void Function(int movieId, WatchStatus status) onStatusTap;
  final VoidCallback onNavigate;

  const _MovieRow({
    super.key,
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.year,
    required this.displayIndex,
    required this.effectiveStatuses,
    required this.hasStreaming,
    this.showDragHandle = false,
    this.reorderIndex,
    required this.onStatusTap,
    required this.onNavigate,
  });

  @override
  ConsumerState<_MovieRow> createState() => _MovieRowState();
}

class _MovieRowState extends ConsumerState<_MovieRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStatuses = widget.effectiveStatuses;
    
    // Calculate the width of the status buttons area for consistent spacing
    // 4 buttons * 28px = 112px
    const statusButtonsWidth = 112.0;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: _isHovered 
            ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            // Status buttons row - always visible (subtly when not hovered)
            SizedBox(
              width: statusButtonsWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MovieStatusButton(
                    icon: Icons.bookmark_border,
                    activeIcon: Icons.bookmark,
                    status: WatchStatus.wantToWatch,
                    isActive: effectiveStatuses.contains(WatchStatus.wantToWatch),
                    isRowHovered: _isHovered,
                    tooltip: 'Want to watch',
                    onTap: () => widget.onStatusTap(widget.movieId, WatchStatus.wantToWatch),
                  ),
                  _MovieStatusButton(
                    icon: Icons.play_circle_outline,
                    activeIcon: Icons.play_circle,
                    status: WatchStatus.inProgress,
                    isActive: effectiveStatuses.contains(WatchStatus.inProgress),
                    isRowHovered: _isHovered,
                    tooltip: 'In progress',
                    onTap: () => widget.onStatusTap(widget.movieId, WatchStatus.inProgress),
                  ),
                  _MovieStatusButton(
                    icon: Icons.check_circle_outline,
                    activeIcon: Icons.check_circle,
                    status: WatchStatus.watched,
                    isActive: effectiveStatuses.contains(WatchStatus.watched),
                    isRowHovered: _isHovered,
                    tooltip: 'Watched',
                    onTap: () => widget.onStatusTap(widget.movieId, WatchStatus.watched),
                  ),
                  _MovieStatusButton(
                    icon: Icons.cancel_outlined,
                    activeIcon: Icons.cancel,
                    status: WatchStatus.dnf,
                    isActive: effectiveStatuses.contains(WatchStatus.dnf),
                    isRowHovered: _isHovered,
                    tooltip: 'Did not finish',
                    onTap: () => widget.onStatusTap(widget.movieId, WatchStatus.dnf),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Movie number
            SizedBox(
              width: 28,
              child: Text(
                '${widget.displayIndex}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Poster thumbnail
            GestureDetector(
              onTap: widget.onNavigate,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 32,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: widget.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w92${widget.posterPath}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Icon(Icons.movie, size: 16),
                            errorWidget: (context, url, error) => const Icon(Icons.movie, size: 16),
                          )
                        : const Icon(Icons.movie, size: 16),
                  ),
                ),
              ),
            ),
            // Title and year
            Expanded(
              child: GestureDetector(
                onTap: widget.onNavigate,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Expanded(
                        child: AdaptiveTooltipText(
                          widget.title,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Fixed width for year to align vertically
                      SizedBox(
                        width: 50,
                        child: Text(
                          widget.year.isNotEmpty ? '(${widget.year})' : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Trailing JustWatch icon - fixed width container for alignment
            SizedBox(
              width: 32,
              child: widget.hasStreaming
                  ? Tooltip(
                      message: 'Where to watch',
                      child: InkWell(
                        onTap: () => ExternalNavigationUtils.launchTmdbWatchPage(
                          context,
                          tmdbId: widget.movieId,
                          isTV: false,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: Image.asset(
                              'assets/images/justwatch_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // Drag handle for reordering
            if (widget.showDragHandle && widget.reorderIndex != null) ...[
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: widget.reorderIndex!,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.drag_handle,
                      color: _isHovered
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact status button for movie rows.
class _MovieStatusButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final WatchStatus status;
  final bool isActive;
  final bool isRowHovered;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double? fixedWidth;

  const _MovieStatusButton({
    required this.icon,
    required this.activeIcon,
    required this.status,
    required this.isActive,
    required this.tooltip,
    this.isRowHovered = false,
    this.onTap,
    this.size = 20,
    this.fixedWidth,
  });

  @override
  State<_MovieStatusButton> createState() => _MovieStatusButtonState();
}

class _MovieStatusButtonState extends State<_MovieStatusButton> {
  bool _isHovered = false;

  static const double _baseSize = 20;
  static const double _basePadding = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = StatusColors.getColor(widget.status, isDark: isDark);
    
    final IconData icon;
    final Color color;
    
    if (widget.isActive) {
      icon = widget.activeIcon;
      color = statusColor;
    } else if (_isHovered) {
      icon = widget.activeIcon;
      color = statusColor.withValues(alpha: 0.6);
    } else if (widget.isRowHovered) {
      icon = widget.icon;
      color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    } else {
      icon = widget.icon;
      color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15);
    }
    
    Widget iconWidget = GestureDetector(
      onTap: widget.onTap,
      child: Icon(
        icon,
        size: widget.size,
        color: color,
      ),
    );
    
    if (widget.fixedWidth != null) {
      iconWidget = SizedBox(
        width: widget.fixedWidth,
        child: Center(child: iconWidget),
      );
    } else {
      final sizeDiff = widget.size - _baseSize;
      final adjustedPadding = _basePadding - (sizeDiff / 2);
      iconWidget = Padding(
        padding: EdgeInsets.all(adjustedPadding.clamp(0, _basePadding)),
        child: iconWidget,
      );
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        child: iconWidget,
      ),
    );
  }
}

/// A simple wrapper widget that tracks hover state and passes it to a builder.
class _HoverableRow extends StatefulWidget {
  final Widget Function(bool isHovered) child;

  const _HoverableRow({required this.child});

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.child(_isHovered),
    );
  }
}
