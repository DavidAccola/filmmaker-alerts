import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/episode_status_entry.dart';
import '../../data/models/season_status_entry.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';

class ShowConfigurationScreen extends ConsumerStatefulWidget {
  final int showId;
  final String showTitle;

  const ShowConfigurationScreen({
    super.key,
    required this.showId,
    required this.showTitle,
  });

  @override
  ConsumerState<ShowConfigurationScreen> createState() =>
      _ShowConfigurationScreenState();
}

class _ShowConfigurationScreenState
    extends ConsumerState<ShowConfigurationScreen> {
  bool _isEditMode = false;
  WatchStatus _selectedMode = WatchStatus.wantToWatch;
  bool _markAllSeasons = false;

  // Track local changes: Map<seasonNumber, Map<episodeNumber, WatchStatus?>>
  // null means unmarked, WatchStatus means marked with that status
  final Map<int, Map<int, WatchStatus?>> _localChanges = {};

  // Track which seasons are marked
  final Set<int> _markedSeasons = {};

  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _initializeLocalChanges();
    _fetchShowEpisodes();
  }

  Future<void> _fetchShowEpisodes() async {
    try {
      final workLogic = ref.read(workLogicProvider);
      
      // Fetch show details which includes seasons
      final showDetail = await workLogic.fetchAndCacheTvShowDetail(widget.showId);
      
      if (showDetail != null) {
        // Fetch all episodes for all seasons
        for (final season in showDetail.seasons) {
          await workLogic.fetchAndCacheTvSeasonDetail(
            showId: widget.showId,
            seasonNumber: season.seasonNumber,
          );
        }
      }
      
      // Refresh the UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[ShowConfigurationScreen] Error fetching episodes: $e');
    }
  }

  void _initializeLocalChanges() {
    // Load existing statuses from repositories
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);
    final seasonRepo = ref.read(seasonStatusRepositoryProvider);

    final episodes = episodeRepo.getEpisodesByShow(widget.showId);
    final seasons = seasonRepo.getSeasonsByShow(widget.showId);

    // Initialize local changes from existing data
    for (final episode in episodes) {
      if (!_localChanges.containsKey(episode.seasonNumber)) {
        _localChanges[episode.seasonNumber] = {};
      }

      // Get the primary status (first one in the list)
      if (episode.statusRecords.isNotEmpty) {
        _localChanges[episode.seasonNumber]![episode.episodeNumber] =
            episode.statusRecords.first.status;
      }
    }

    // Track marked seasons
    for (final season in seasons) {
      if (season.statusRecords.isNotEmpty) {
        _markedSeasons.add(season.seasonNumber);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tvDetailRepo = ref.watch(tvDetailRepositoryProvider);
    final episodeRepo = ref.watch(episodeStatusRepositoryProvider);
    final seasonRepo = ref.watch(seasonStatusRepositoryProvider);

    // Get the cached show details
    final showDetail = tvDetailRepo.getTvShowDetail(widget.showId);
    
    if (showDetail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.showTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get marked episodes from status repository
    final markedEpisodes = episodeRepo.getEpisodesByShow(widget.showId);
    final markedSeasons = seasonRepo.getSeasonsByShow(widget.showId);

    // Group marked episodes by season for quick lookup
    final markedEpisodesBySeasonAndNumber = <int, Map<int, EpisodeStatusEntry>>{};
    for (final episode in markedEpisodes) {
      if (!markedEpisodesBySeasonAndNumber.containsKey(episode.seasonNumber)) {
        markedEpisodesBySeasonAndNumber[episode.seasonNumber] = {};
      }
      markedEpisodesBySeasonAndNumber[episode.seasonNumber]![episode.episodeNumber] = episode;
    }

    // Convert cached show detail seasons to SeasonStatusEntry for display
    final seasons = showDetail.seasons
        .map((season) => SeasonStatusEntry(
          showId: widget.showId,
          seasonNumber: season.seasonNumber,
          statusRecords: markedSeasons
              .where((s) => s.seasonNumber == season.seasonNumber)
              .expand((s) => s.statusRecords)
              .toList(),
        ))
        .toList();

    // Convert cached episodes to EpisodeStatusEntry for display
    final episodesBySeasonMap = <int, List<EpisodeStatusEntry>>{};
    for (final season in showDetail.seasons) {
      // Get the season detail which contains episodes
      final seasonDetail = tvDetailRepo.getTvSeasonDetail(widget.showId, season.seasonNumber);
      
      if (seasonDetail != null) {
        episodesBySeasonMap[season.seasonNumber] = seasonDetail.episodes
            .map((episode) {
              final markedEpisode = markedEpisodesBySeasonAndNumber[season.seasonNumber]?[episode.episodeNumber];
              return EpisodeStatusEntry(
                showId: widget.showId,
                seasonNumber: season.seasonNumber,
                episodeNumber: episode.episodeNumber,
                episodeTitle: episode.name,
                statusRecords: markedEpisode?.statusRecords ?? [],
              );
            })
            .toList();
      } else {
        episodesBySeasonMap[season.seasonNumber] = [];
      }
    }

    // Sort seasons
    final sortedSeasons = seasons.toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

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
          title: Text(widget.showTitle),
          actions: [
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
        body: Stack(
          children: [
            // Main content
            _buildMainContent(sortedSeasons, episodesBySeasonMap),

            // Edit mode snackbar
            if (_isEditMode)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildModeSnackbar(),
              ),
          ],
        ),
        floatingActionButton: _isEditMode
            ? FloatingActionButton(
                onPressed: _handleSave,
                tooltip: 'Save',
                child: const Icon(Icons.check),
              )
            : FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isEditMode = true;
                  });
                },
                tooltip: 'Edit',
                child: const Icon(Icons.edit),
              ),
      ),
    );
  }

  Widget _buildMainContent(
    List<SeasonStatusEntry> seasons,
    Map<int, List<EpisodeStatusEntry>> episodesByseason,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768; // Improved breakpoint

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: isMobile
            ? _buildMobileLayout(seasons, episodesByseason)
            : _buildDesktopLayout(seasons, episodesByseason),
      ),
    );
  }

  Widget _buildDesktopLayout(
    List<SeasonStatusEntry> seasons,
    Map<int, List<EpisodeStatusEntry>> episodesByseason,
  ) {
    return Column(
      children: [
        // Bulk controls
        if (_isEditMode)
          Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _markAllSeasons,
                  onChanged: (value) {
                    setState(() {
                      _markAllSeasons = value ?? false;
                      _toggleAllSeasons(_markAllSeasons);
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Mark/Unmark all seasons',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

        // Grid layout with improved styling
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2.5),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Season',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Episodes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Season rows
              for (int i = 0; i < seasons.length; i++)
                _buildSeasonRow(
                  seasons[i], 
                  episodesByseason[seasons[i].seasonNumber] ?? [],
                  isLast: i == seasons.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    List<SeasonStatusEntry> seasons,
    Map<int, List<EpisodeStatusEntry>> episodesByseason,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bulk controls
        if (_isEditMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Checkbox(
                  value: _markAllSeasons,
                  onChanged: (value) {
                    setState(() {
                      _markAllSeasons = value ?? false;
                      _toggleAllSeasons(_markAllSeasons);
                    });
                  },
                ),
                const Text('Mark/Unmark all seasons'),
              ],
            ),
          ),

        // Stacked layout
        for (final season in seasons) ...[
          _buildSeasonHeading(season),
          _buildEpisodesList(season, episodesByseason[season.seasonNumber] ?? []),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  TableRow _buildSeasonRow(
    SeasonStatusEntry season,
    List<EpisodeStatusEntry> episodes, {
    bool isLast = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      children: [
        // Season column
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSeasonCell(season),
        ),

        // Episodes column
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final episode in episodes)
                if (_shouldShowEpisode(episode))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: _buildEpisodeItem(episode),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonCell(SeasonStatusEntry season) {
    final theme = Theme.of(context);
    final isMarked = _isSeasonMarked(season.seasonNumber);
    final statusSymbol = _getStatusSymbol(_selectedMode);

    return InkWell(
      onTap: _isEditMode
          ? () {
              setState(() {
                _toggleSeason(season.seasonNumber);
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isMarked
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isMarked
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
        ),
        child: Row(
          children: [
            if (isMarked)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(statusSymbol),
              ),
            Expanded(
              child: Text(
                season.displayName,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonHeading(SeasonStatusEntry season) {
    final theme = Theme.of(context);
    final isMarked = _isSeasonMarked(season.seasonNumber);
    final statusSymbol = _getStatusSymbol(_selectedMode);

    return InkWell(
      onTap: _isEditMode
          ? () {
              setState(() {
                _toggleSeason(season.seasonNumber);
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isMarked
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isMarked
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
        ),
        child: Row(
          children: [
            if (isMarked)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(statusSymbol),
              ),
            Expanded(
              child: Text(
                season.displayName,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesList(
    SeasonStatusEntry season,
    List<EpisodeStatusEntry> episodes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final episode in episodes)
          if (_shouldShowEpisode(episode))
            _buildEpisodeItem(episode),
      ],
    );
  }

  Widget _buildEpisodeItem(EpisodeStatusEntry episode) {
    final theme = Theme.of(context);
    final isMarked = _isEpisodeMarked(episode.seasonNumber, episode.episodeNumber);
    final statusSymbol = _getStatusSymbol(_selectedMode);

    return InkWell(
      onTap: _isEditMode
          ? () {
              setState(() {
                _toggleEpisode(episode.seasonNumber, episode.episodeNumber);
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            if (isMarked)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(statusSymbol),
              ),
            Expanded(
              child: Text(
                'E${episode.episodeNumber.toString().padLeft(2, '0')} - ${episode.episodeTitle}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSnackbar() {
    final theme = Theme.of(context);
    final statusText = _getStatusText(_selectedMode);
    final statusSymbol = _getStatusSymbol(_selectedMode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Marking shows as $statusSymbol $statusText',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModePill(WatchStatus.wantToWatch),
                const SizedBox(width: 8),
                _buildModePill(WatchStatus.inProgress),
                const SizedBox(width: 8),
                _buildModePill(WatchStatus.watched),
                const SizedBox(width: 8),
                _buildModePill(WatchStatus.dnf),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(WatchStatus status) {
    final isSelected = _selectedMode == status;
    final theme = Theme.of(context);
    final statusText = _getStatusText(status);
    final statusSymbol = _getStatusSymbol(status);

    return FilterChip(
      label: Text('$statusSymbol $statusText'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMode = status;
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: theme.colorScheme.primaryContainer,
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
    );
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

  bool _shouldShowEpisode(EpisodeStatusEntry episode) {
    // Always show all episodes
    return true;
  }

  bool _isSeasonMarked(int seasonNumber) {
    return _markedSeasons.contains(seasonNumber);
  }

  bool _isEpisodeMarked(int seasonNumber, int episodeNumber) {
    return _localChanges[seasonNumber]?[episodeNumber] != null;
  }

  void _toggleSeason(int seasonNumber) {
    setState(() {
      if (_isSeasonMarked(seasonNumber)) {
        // Unmark season and all its episodes
        _markedSeasons.remove(seasonNumber);
        _localChanges[seasonNumber]?.clear();
      } else {
        // Mark season and all its episodes
        _markedSeasons.add(seasonNumber);
        if (!_localChanges.containsKey(seasonNumber)) {
          _localChanges[seasonNumber] = {};
        }

        // Mark all episodes in this season
        final episodeRepo = ref.read(episodeStatusRepositoryProvider);
        final episodes = episodeRepo.getEpisodesBySeason(widget.showId, seasonNumber);
        for (final episode in episodes) {
          _localChanges[seasonNumber]![episode.episodeNumber] = _selectedMode;
        }
      }
      _isDirty = true;
    });
  }

  void _toggleEpisode(int seasonNumber, int episodeNumber) {
    setState(() {
      if (!_localChanges.containsKey(seasonNumber)) {
        _localChanges[seasonNumber] = {};
      }

      if (_isEpisodeMarked(seasonNumber, episodeNumber)) {
        // Unmark episode
        _localChanges[seasonNumber]![episodeNumber] = null;
      } else {
        // Mark episode
        _localChanges[seasonNumber]![episodeNumber] = _selectedMode;
      }
      _isDirty = true;
    });
  }

  void _toggleAllSeasons(bool mark) {
    setState(() {
      final episodeRepo = ref.read(episodeStatusRepositoryProvider);
      final seasonRepo = ref.read(seasonStatusRepositoryProvider);

      if (mark) {
        // Mark all seasons and episodes
        final seasons = seasonRepo.getSeasonsByShow(widget.showId);
        for (final season in seasons) {
          _markedSeasons.add(season.seasonNumber);
          if (!_localChanges.containsKey(season.seasonNumber)) {
            _localChanges[season.seasonNumber] = {};
          }

          final episodes =
              episodeRepo.getEpisodesBySeason(widget.showId, season.seasonNumber);
          for (final episode in episodes) {
            _localChanges[season.seasonNumber]![episode.episodeNumber] =
                _selectedMode;
          }
        }
      } else {
        // Unmark all seasons and episodes
        _markedSeasons.clear();
        _localChanges.clear();
      }
      _isDirty = true;
    });
  }

  Future<void> _handleSave() async {
    final logic = ref.read(watchlistLogicProvider);
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);
    final seasonRepo = ref.read(seasonStatusRepositoryProvider);

    // Check for unreleased content
    bool hasUnreleased = false;

    // Save all marked episodes
    for (final seasonEntry in _localChanges.entries) {
      final seasonNumber = seasonEntry.key;
      final episodes = seasonEntry.value;

      for (final episodeEntry in episodes.entries) {
        final episodeNumber = episodeEntry.key;
        final status = episodeEntry.value;

        if (status != null) {
          // Check if unreleased
          final episode =
              episodeRepo.getEpisode(widget.showId, seasonNumber, episodeNumber);
          if (episode != null && !episode.isReleased) {
            hasUnreleased = true;
          }

          // Save episode status
          await logic.addStatusToEpisode(
            widget.showId,
            seasonNumber,
            episodeNumber,
            status,
          );
        }
      }

      // If season is marked, also save season status
      if (_markedSeasons.contains(seasonNumber)) {
        final season = seasonRepo.getSeason(widget.showId, seasonNumber);
        if (season != null && !season.isReleased) {
          hasUnreleased = true;
        }

        await logic.addStatusToSeason(
          widget.showId,
          seasonNumber,
          _selectedMode,
        );
      }
    }

    // Show confirmation snackbar
    if (mounted) {
      showSimpleSnackBar(
        context,
        'Changes saved',
        duration: const Duration(seconds: 3),
      );

      if (hasUnreleased) {
        showUnreleasedWarningSnackBar(context, widget.showTitle);
      }
    }

    // Reset dirty flag and exit edit mode
    setState(() {
      _isDirty = false;
      _isEditMode = false;
    });

    // Invalidate providers to refresh data
    ref.invalidate(episodeStatusRepositoryProvider);
    ref.invalidate(seasonStatusRepositoryProvider);
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

  String _getStatusText(WatchStatus status) {
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

  Future<void> _showUnsavedChangesDialog() async {
    if (!mounted) return;
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    
    if (shouldPop ?? false) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
