import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/episode_status_entry.dart';
import '../../data/models/season_status_entry.dart';
import '../../data/models/status_record.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/status_selector_bar.dart';

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
  // Currently selected status to apply when checking boxes
  WatchStatus _selectedStatus = WatchStatus.watched;

  // Track pending changes: Map<seasonNumber, Map<episodeNumber, WatchStatus?>>
  // null means "clear status", WatchStatus means "set to this status"
  final Map<int, Map<int, WatchStatus?>> _pendingChanges = {};

  // Track which seasons are expanded in the UI
  final Set<int> _expandedSeasons = {};

  // Filter state
  Set<WatchStatus> _selectedFilters = {
    WatchStatus.wantToWatch,
    WatchStatus.inProgress,
    WatchStatus.watched,
    WatchStatus.dnf,
  };

  bool _isDirty = false;

  // ============================================================
  // Tri-State Checkbox Helper Functions
  // ============================================================
  // These helpers compute checkbox states for hierarchical selection:
  // - true = all items checked
  // - false = no items checked  
  // - null = indeterminate (some items checked)
  // ============================================================

  /// Gets the effective status for an episode, checking pending changes first,
  /// then falling back to the existing persisted status.
  /// 
  /// Returns null if no status exists (neither pending nor persisted).
  WatchStatus? _getEffectiveEpisodeStatus(int seasonNumber, int episodeNumber) {
    // Check pending changes first
    if (_pendingChanges.containsKey(seasonNumber) &&
        _pendingChanges[seasonNumber]!.containsKey(episodeNumber)) {
      return _pendingChanges[seasonNumber]![episodeNumber];
    }
    
    // Fall back to existing persisted status
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);
    final episode = episodeRepo.getEpisode(widget.showId, seasonNumber, episodeNumber);
    if (episode != null && episode.statusRecords.isNotEmpty) {
      return episode.statusRecords.first.status;
    }
    
    return null;
  }

  /// Computes the checkbox state for a season based on its episodes.
  /// 
  /// Returns:
  /// - true if ALL episodes in the season have a status
  /// - false if NO episodes in the season have a status
  /// - null if SOME episodes have a status (indeterminate)
  bool? _computeSeasonCheckboxState(int seasonNumber, List<EpisodeStatusEntry> episodes) {
    if (episodes.isEmpty) return false;
    
    int markedCount = 0;
    for (final episode in episodes) {
      if (_getEffectiveEpisodeStatus(seasonNumber, episode.episodeNumber) != null) {
        markedCount++;
      }
    }
    
    if (markedCount == 0) return false;
    if (markedCount == episodes.length) return true;
    return null; // indeterminate - some but not all are marked
  }

  /// Computes the checkbox state for the entire show based on all episodes.
  /// 
  /// Returns:
  /// - true if ALL episodes across all seasons have a status
  /// - false if NO episodes have a status
  /// - null if SOME episodes have a status (indeterminate)
  bool? _computeShowCheckboxState(Map<int, List<EpisodeStatusEntry>> episodesBySeason) {
    int totalEpisodes = 0;
    int markedEpisodes = 0;
    
    for (final entry in episodesBySeason.entries) {
      final seasonNumber = entry.key;
      final episodes = entry.value;
      
      for (final episode in episodes) {
        totalEpisodes++;
        if (_getEffectiveEpisodeStatus(seasonNumber, episode.episodeNumber) != null) {
          markedEpisodes++;
        }
      }
    }
    
    if (totalEpisodes == 0) return false;
    if (markedEpisodes == 0) return false;
    if (markedEpisodes == totalEpisodes) return true;
    return null; // indeterminate - some but not all are marked
  }

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

    final episodes = episodeRepo.getEpisodesByShow(widget.showId);

    // Initialize pending changes from existing data
    for (final episode in episodes) {
      if (!_pendingChanges.containsKey(episode.seasonNumber)) {
        _pendingChanges[episode.seasonNumber] = {};
      }

      // Get the primary status (first one in the list)
      if (episode.statusRecords.isNotEmpty) {
        _pendingChanges[episode.seasonNumber]![episode.episodeNumber] =
            episode.statusRecords.first.status;
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

    // Compute show-level checkbox state
    final showCheckboxState = _computeShowCheckboxState(episodesBySeasonMap);

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
        body: Column(
          children: [
            // StatusSelectorBar - sticky at top (doesn't scroll)
            StatusSelectorBar(
              selectedStatus: _selectedStatus,
              onStatusChanged: (status) {
                setState(() {
                  _selectedStatus = status;
                });
              },
            ),
            // Show-level "Mark All" checkbox with tri-state support
            _buildMarkAllCheckbox(showCheckboxState, episodesBySeasonMap),
            // Expandable list content
            Expanded(
              child: _buildExpandableList(sortedSeasons, episodesBySeasonMap),
            ),
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

  /// Builds the show-level "Mark All" checkbox with tri-state support.
  Widget _buildMarkAllCheckbox(
    bool? showCheckboxState,
    Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            tristate: true,
            value: showCheckboxState,
            onChanged: (value) {
              _handleShowCheckboxChanged(value, episodesBySeasonMap);
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Mark All Episodes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Handles the show-level checkbox change.
  void _handleShowCheckboxChanged(
    bool? value,
    Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap,
  ) {
    setState(() {
      // The 'value' parameter is the NEW value that Flutter wants to set.
      // For tri-state checkbox: false->true, true->null, null->false
      // We want to mark all when transitioning TO checked (value == true)
      // OR when clicking indeterminate (value == false but was null)
      // We want to clear all when transitioning FROM checked (value == null, was true)
      // 
      // Since we can't know the old value here, we use a simpler rule:
      // - If new value is true OR false (from indeterminate), mark all
      // - If new value is null (from checked), clear all
      final shouldMark = value != null;
      
      for (final entry in episodesBySeasonMap.entries) {
        final seasonNumber = entry.key;
        final episodes = entry.value;
        
        if (!_pendingChanges.containsKey(seasonNumber)) {
          _pendingChanges[seasonNumber] = {};
        }
        
        for (final episode in episodes) {
          if (shouldMark) {
            _pendingChanges[seasonNumber]![episode.episodeNumber] = _selectedStatus;
          } else {
            _pendingChanges[seasonNumber]![episode.episodeNumber] = null;
          }
        }
      }
      _isDirty = true;
    });
  }

  /// Builds the expandable list of seasons and episodes.
  Widget _buildExpandableList(
    List<SeasonStatusEntry> seasons,
    Map<int, List<EpisodeStatusEntry>> episodesBySeasonMap,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        final episodes = episodesBySeasonMap[season.seasonNumber] ?? [];
        final isExpanded = _expandedSeasons.contains(season.seasonNumber);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeasonItem(season, episodes, isExpanded),
            if (isExpanded)
              ...episodes.map((episode) => _buildEpisodeItem(episode)),
          ],
        );
      },
    );
  }

  /// Builds a season item row with checkbox, name, episode count, and expand icon.
  Widget _buildSeasonItem(
    SeasonStatusEntry season,
    List<EpisodeStatusEntry> episodes,
    bool isExpanded,
  ) {
    final theme = Theme.of(context);
    final seasonCheckboxState = _computeSeasonCheckboxState(season.seasonNumber, episodes);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedSeasons.remove(season.seasonNumber);
            } else {
              _expandedSeasons.add(season.seasonNumber);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Tri-state checkbox for season
              Checkbox(
                tristate: true,
                value: seasonCheckboxState,
                onChanged: (value) {
                  _handleSeasonCheckboxChanged(season.seasonNumber, episodes, value);
                },
              ),
              const SizedBox(width: 8),
              // Season name
              Expanded(
                child: Row(
                  children: [
                    Text(
                      season.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Episode count
                    Text(
                      '(${episodes.length} episodes)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Expand/collapse icon
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles the season checkbox change.
  void _handleSeasonCheckboxChanged(
    int seasonNumber,
    List<EpisodeStatusEntry> episodes,
    bool? value,
  ) {
    setState(() {
      // The 'value' parameter is the NEW value that Flutter wants to set.
      // For tri-state checkbox: false->true, true->null, null->false
      // We want to mark all when transitioning TO checked (value == true)
      // OR when clicking indeterminate (value == false but was null)
      // We want to clear all when transitioning FROM checked (value == null, was true)
      // 
      // Since we can't know the old value here, we use a simpler rule:
      // - If new value is true OR false (from indeterminate), mark all
      // - If new value is null (from checked), clear all
      final shouldMark = value != null;
      
      if (!_pendingChanges.containsKey(seasonNumber)) {
        _pendingChanges[seasonNumber] = {};
      }
      
      for (final episode in episodes) {
        if (shouldMark) {
          _pendingChanges[seasonNumber]![episode.episodeNumber] = _selectedStatus;
        } else {
          _pendingChanges[seasonNumber]![episode.episodeNumber] = null;
        }
      }
      _isDirty = true;
    });
  }

  /// Builds an episode item row with checkbox, number, title, and status symbol.
  Widget _buildEpisodeItem(EpisodeStatusEntry episode) {
    final theme = Theme.of(context);
    final effectiveStatus = _getEffectiveEpisodeStatus(episode.seasonNumber, episode.episodeNumber);
    final isChecked = effectiveStatus != null;
    final statusSymbol = effectiveStatus != null ? _getStatusSymbol(effectiveStatus) : '';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _handleEpisodeCheckboxChanged(episode.seasonNumber, episode.episodeNumber, !isChecked);
        },
        child: Padding(
          // 24px indent from season headers
          padding: const EdgeInsets.only(left: 40.0, right: 16.0, top: 4.0, bottom: 4.0),
          child: Row(
            children: [
              // Binary checkbox for episode
              Checkbox(
                value: isChecked,
                onChanged: (value) {
                  _handleEpisodeCheckboxChanged(episode.seasonNumber, episode.episodeNumber, value ?? false);
                },
              ),
              const SizedBox(width: 8),
              // Episode number and title
              Expanded(
                child: Text(
                  'E${episode.episodeNumber.toString().padLeft(2, '0')} - ${episode.episodeTitle}',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status symbol on right
              if (statusSymbol.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    statusSymbol,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles the episode checkbox change.
  void _handleEpisodeCheckboxChanged(int seasonNumber, int episodeNumber, bool isChecked) {
    setState(() {
      if (!_pendingChanges.containsKey(seasonNumber)) {
        _pendingChanges[seasonNumber] = {};
      }
      
      if (isChecked) {
        // Mark episode with selected status
        _pendingChanges[seasonNumber]![episodeNumber] = _selectedStatus;
      } else {
        // Clear episode status (set to null)
        _pendingChanges[seasonNumber]![episodeNumber] = null;
      }
      _isDirty = true;
    });
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

  Future<void> _handleSave() async {
    final logic = ref.read(watchlistLogicProvider);
    final episodeRepo = ref.read(episodeStatusRepositoryProvider);

    // Check for unreleased content
    bool hasUnreleased = false;

    // Save all pending changes
    for (final seasonEntry in _pendingChanges.entries) {
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
        } else {
          // Clear episode status (null means clear)
          await logic.removeStatusFromEpisode(
            widget.showId,
            seasonNumber,
            episodeNumber,
          );
        }
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

    // Reset dirty flag
    setState(() {
      _isDirty = false;
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
