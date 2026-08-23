import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/connections_models.dart';
import '../../providers/providers.dart';
import '../common/snackbar_utils.dart';
import '../common/tmdb_attribution.dart';
import 'contributor_detail_screen.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Contributor filter (set from Contributors tab tap)
  int? _selectedContributorId;
  String? _selectedContributorName;

  // Feed type filter: null = both, 'movie' = movies only, 'tv' = TV only
  String? _typeFilter;

  // Era filter: false = all time, true = recent (last 5 years)
  bool _recentOnly = false;

  // Refresh state
  bool _isRefreshing = false;
  int _refreshCompleted = 0;
  int _refreshTotal = 0;

  // Auto-fetch on cold cache
  bool _autoFetchTriggered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auto-fetch on cold cache
  // ---------------------------------------------------------------------------

  void _maybeAutoFetch(List<Contributor> contributors) {
    if (_autoFetchTriggered) return;
    _autoFetchTriggered = true;

    final detailRepo = ref.read(contributorDetailRepositoryProvider);
    final hasCache = contributors.any((c) => detailRepo.isCached(c.tmdbId));
    if (!hasCache) {
      // Cold cache — trigger refresh silently
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRefresh(silent: true);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  Future<void> _handleRefresh({bool silent = false}) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _refreshCompleted = 0;
      _refreshTotal = 0;
    });

    try {
      final logic = ref.read(contributorLogicProvider);
      await logic.refreshAllContributors(
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _refreshCompleted = completed;
              _refreshTotal = total;
            });
          }
        },
      );

      ref.invalidate(contributorsProvider);
      ref.invalidate(rankedDiscoveryFeedProvider);
      ref.invalidate(contributorsByAffinityProvider);

      if (mounted && !silent) {
        showSimpleSnackBar(context, 'Refresh complete');
      }
    } catch (e) {
      if (mounted && !silent) {
        showSimpleSnackBar(context, 'Refresh failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dismiss
  // ---------------------------------------------------------------------------

  Future<void> _dismissWork(ConnectionWork work) async {
    // Use the already-loaded prefs synchronously — no await needed since
    // preferencesProvider is always loaded by the time the feed is visible.
    final prefs = ref.read(preferencesProvider).value;
    if (prefs == null) return; // prefs not yet loaded — shouldn't happen in practice
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final key = '${work.type.name}_${work.tmdbId}';
    final updated = List<String>.from(prefs.dismissedConnectionIds ?? []);
    if (!updated.contains(key)) {
      updated.add(key);
      prefs.dismissedConnectionIds = updated;
      await prefsRepo.savePreferences(prefs);
      ref.invalidate(preferencesProvider);
      ref.invalidate(rankedDiscoveryFeedProvider);
    }
  }

  // ---------------------------------------------------------------------------
  // Add to watchlist
  // ---------------------------------------------------------------------------

  Future<void> _addToWatchlist(ConnectionWork work) async {
    final logic = ref.read(watchlistLogicProvider);
    await logic.addWorkToWatchlist(
      tmdbId: work.tmdbId,
      type: work.type,
      title: work.title,
      posterPath: work.posterPath,
      releaseDate: work.releaseDate,
    );
    ref.invalidate(watchlistEntriesProvider);
    ref.invalidate(rankedDiscoveryFeedProvider);
    if (mounted) {
      showSimpleSnackBar(context, '${work.title} added to watchlist');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final contributorsAsync = ref.watch(contributorsProvider);

    contributorsAsync.whenData((contributors) => _maybeAutoFetch(contributors));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildTitle(),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Contributors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildContributorsTab(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        const SizedBox(width: 16),
        const Text('Connections'),
        if (_isRefreshing) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _refreshTotal > 0 ? _refreshCompleted / _refreshTotal : null,
            ),
          ),
          if (_refreshTotal > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '$_refreshCompleted/$_refreshTotal',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _isRefreshing ? null : () => _handleRefresh(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Discover Tab
  // ---------------------------------------------------------------------------

  Widget _buildDiscoverTab() {
    final feedAsync = ref.watch(rankedDiscoveryFeedProvider(_selectedContributorId));

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: feedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(rankedDiscoveryFeedProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (works) {
              final filtered = _applyFilters(works);
              if (filtered.isEmpty) {
                return _buildEmptyDiscoverState();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: filtered.length + 1, // +1 for attribution
                itemBuilder: (context, index) {
                  if (index == filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TmdbAttribution(),
                    );
                  }
                  return _DiscoverCard(
                    work: filtered[index],
                    onAdd: () => _addToWatchlist(filtered[index]),
                    onDismiss: () => _dismissWork(filtered[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Active contributor filter chip
          if (_selectedContributorId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_selectedContributorName ?? 'Person'),
                selected: true,
                onSelected: (_) => setState(() {
                  _selectedContributorId = null;
                  _selectedContributorName = null;
                }),
                onDeleted: () => setState(() {
                  _selectedContributorId = null;
                  _selectedContributorName = null;
                }),
              ),
            ),
          // Type filter
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Movies'),
              selected: _typeFilter == 'movie',
              onSelected: (v) => setState(() =>
                  _typeFilter = v ? 'movie' : (_typeFilter == 'movie' ? null : _typeFilter)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('TV'),
              selected: _typeFilter == 'tv',
              onSelected: (v) => setState(() =>
                  _typeFilter = v ? 'tv' : (_typeFilter == 'tv' ? null : _typeFilter)),
            ),
          ),
          // Era filter
          FilterChip(
            label: const Text('Recent (5yr)'),
            selected: _recentOnly,
            onSelected: (v) => setState(() => _recentOnly = v),
          ),
        ],
      ),
    );
  }

  List<ConnectionWork> _applyFilters(List<ConnectionWork> works) {
    return works.where((w) {
      if (_typeFilter == 'movie' && w.type != WorkType.movie) return false;
      if (_typeFilter == 'tv' && w.type != WorkType.tvShow) return false;
      if (_recentOnly) {
        // Exclude items with no release date — we can't confirm they're recent.
        if (w.releaseDate == null) return false;
        final cutoff = DateTime.now().subtract(const Duration(days: 365 * 5));
        if (w.releaseDate!.isBefore(cutoff)) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildEmptyDiscoverState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined,
                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _selectedContributorId != null
                  ? 'No discoveries for this person yet.'
                  : 'Nothing to discover yet.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing to fetch the latest works from people you follow.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isRefreshing ? null : () => _handleRefresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Contributors Tab
  // ---------------------------------------------------------------------------

  Widget _buildContributorsTab() {
    final contributorsAsync = ref.watch(contributorsByAffinityProvider);
    final allContributorsAsync = ref.watch(contributorsProvider);

    return contributorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (contributors) {
        final allContributors = allContributorsAsync.value ?? [];
        if (contributors.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No contributors followed yet.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: contributors.length,
          itemBuilder: (context, index) {
            final c = contributors[index];
            final isSelected = _selectedContributorId == c.contributorId;
            // Find full Contributor object for detail screen
            final fullContributor = allContributors
                .where((fc) => fc.tmdbId == c.contributorId)
                .firstOrNull;
            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundImage: c.profilePath != null
                    ? CachedNetworkImageProvider(
                        'https://image.tmdb.org/t/p/w185${c.profilePath}')
                    : null,
                child: c.profilePath == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(c.name),
              subtitle: Text(
                c.contributorType == ContributorType.person
                    ? '${c.appearanceCount} works'
                    : 'Company · ${c.appearanceCount} works',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              selected: isSelected,
              selectedTileColor:
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedContributorId = null;
                          _selectedContributorName = null;
                        });
                        _tabController.animateTo(0);
                      },
                      child: const Text('Clear filter'),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedContributorId = c.contributorId;
                          _selectedContributorName = c.name;
                        });
                        _tabController.animateTo(0);
                      },
                      child: const Text('Filter'),
                    ),
                  if (fullContributor != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      tooltip: 'View profile',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ContributorDetailScreen(
                            contributor: fullContributor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Discover Card Widget
// ---------------------------------------------------------------------------

class _DiscoverCard extends StatelessWidget {
  final ConnectionWork work;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _DiscoverCard({
    required this.work,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = work.releaseDate?.year;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 84,
                child: work.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl:
                            'https://image.tmdb.org/t/p/w185${work.posterPath}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.movie,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.movie,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + year
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          work.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (year != null)
                        Text(
                          '$year',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // TMDB rating
                  if (work.tmdbRating != null && (work.voteCount ?? 0) > 0)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          work.tmdbRating!.toStringAsFixed(1),
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          work.type == WorkType.tvShow ? 'TV' : 'Movie',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Why — people + roles
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: work.matchedContributors.take(4).map((mc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${mc.name} · ${mc.role}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Actions
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Dismiss'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
