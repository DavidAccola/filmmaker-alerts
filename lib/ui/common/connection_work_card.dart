import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/connections_models.dart';
import '../../providers/providers.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/tv_show_detail_screen.dart';
import '../screens/tv_episode_detail_screen.dart';
import '../screens/contributor_detail_screen.dart';
import 'hover_action_button.dart';

/// A card widget displaying a ConnectionWork with poster, title, year,
/// TMDB rating, streaming logos, people list, and TV standout episodes.
class ConnectionWorkCard extends ConsumerStatefulWidget {
  final ConnectionWork work;
  final VoidCallback? onTap;

  /// Optional callback for adding this work to the watchlist (Discovery mode).
  /// When non-null, a HoverActionButton is shown on the poster.
  final void Function(ConnectionWork work)? onAddToWatchlist;

  const ConnectionWorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.onAddToWatchlist,
  });

  @override
  ConsumerState<ConnectionWorkCard> createState() => _ConnectionWorkCardState();
}

class _ConnectionWorkCardState extends ConsumerState<ConnectionWorkCard> {
  bool _breakdownExpanded = false;
  bool _isHovered = false;

  ConnectionWork get work => widget.work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onCardTap(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: poster + info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPoster(context),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInfo(context)),
                  ],
                ),
                const SizedBox(height: 8),
                // People list
                _buildPeopleList(context),
                // Episode drill-down breakdown (Req 17)
                if (work.episodeBreakdown.isNotEmpty)
                  _buildEpisodeBreakdown(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8.1 — Poster thumbnail with collection indicator (8.5)
  // ---------------------------------------------------------------------------

  Widget _buildPoster(BuildContext context) {
    final theme = Theme.of(context);
    const posterWidth = 60.0;
    const posterHeight = 90.0;

    return SizedBox(
      width: posterWidth,
      height: posterHeight,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: work.posterPath != null
                ? CachedNetworkImage(
                    imageUrl:
                        'https://image.tmdb.org/t/p/w154${work.posterPath}',
                    width: posterWidth,
                    height: posterHeight,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        work.type == WorkType.tvShow
                            ? Icons.tv
                            : Icons.movie,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      work.type == WorkType.tvShow ? Icons.tv : Icons.movie,
                      size: 24,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          // Collection indicator (Task 8.5)
          if (work.type == WorkType.movie && work.collectionId != null)
            _buildCollectionIndicator(context),
          // Add to Watchlist button (Discovery mode, Task 10.1)
          if (widget.onAddToWatchlist != null)
            Positioned(
              top: 2,
              right: 2,
              child: HoverActionButton(
                onPressed: () => widget.onAddToWatchlist!(work),
                icon: Icons.add_circle,
                tooltip: 'Add to Watchlist',
                iconSize: 20,
                isCardHovered: _isHovered,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8.1 — Title, year/year-range, TMDB rating, streaming logos
  // ---------------------------------------------------------------------------

  Widget _buildInfo(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          work.title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Year + rating row
        _buildYearRatingRow(context),
        // Streaming logos
        if (_filteredStreamingOptions.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildStreamingLogos(context),
        ],
      ],
    );
  }

  Widget _buildYearRatingRow(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final yearStr = _formatYear();
    final showRating = work.tmdbRating != null &&
        work.voteCount != null &&
        work.voteCount! >= 10;

    return Row(
      children: [
        if (yearStr != null) Text(yearStr, style: style),
        if (yearStr != null && showRating)
          Text(' · ', style: style),
        if (showRating)
          Text(work.tmdbRating!.toStringAsFixed(1), style: style),
      ],
    );
  }

  String? _formatYear() {
    if (work.releaseDate == null) return null;
    final startYear = work.releaseDate!.year.toString();
    if (work.type == WorkType.tvShow) {
      if (work.endDate != null) {
        final endYear = work.endDate!.year.toString();
        return startYear == endYear ? startYear : '$startYear–$endYear';
      }
      // Ongoing show — open-ended range
      return '$startYear–';
    }
    return startYear;
  }

  // ---------------------------------------------------------------------------
  // 8.1 — Streaming provider logos (subscription/free only, max 4, +N overflow)
  // ---------------------------------------------------------------------------

  List<StreamingOption> get _filteredStreamingOptions {
    return work.streamingOptions
        .where((o) =>
            o.type == StreamingType.subscription ||
            o.type == StreamingType.free)
        .toList();
  }

  Widget _buildStreamingLogos(BuildContext context) {
    final theme = Theme.of(context);
    final options = _filteredStreamingOptions;
    // Deduplicate by providerId
    final seen = <String>{};
    final unique = <StreamingOption>[];
    for (final o in options) {
      if (seen.add(o.providerId)) unique.add(o);
    }

    final displayCount = unique.length > 4 ? 4 : unique.length;
    final overflow = unique.length - displayCount;

    return Row(
      children: [
        for (int i = 0; i < displayCount; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _buildProviderLogo(unique[i], theme),
        ],
        if (overflow > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$overflow',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderLogo(StreamingOption option, ThemeData theme) {
    if (option.logoPath == null) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.play_arrow, size: 12,
            color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CachedNetworkImage(
        imageUrl: 'https://image.tmdb.org/t/p/original${option.logoPath}',
        width: 18,
        height: 18,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 18,
          height: 18,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8.2 — People list: avatar, name, role label
  //       Persons ordered by roleImportance asc, companies after all persons.
  // ---------------------------------------------------------------------------

  Widget _buildPeopleList(BuildContext context) {
    final theme = Theme.of(context);
    // Sort: persons first by roleImportance asc, then companies by roleImportance asc
    final persons = work.matchedContributors
        .where((mc) => mc.contributorType == ContributorType.person)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final companies = work.matchedContributors
        .where((mc) => mc.contributorType == ContributorType.company)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final sorted = [...persons, ...companies];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: sorted.map((mc) => _buildContributorChip(context, mc)).toList(),
    );
  }

  Widget _buildContributorChip(
      BuildContext context, MatchedContributor mc) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _onContributorTap(context, mc),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: mc.profilePath != null
                ? CachedNetworkImageProvider(
                    'https://image.tmdb.org/t/p/w45${mc.profilePath}')
                : null,
            child: mc.profilePath == null
                ? Icon(
                    mc.contributorType == ContributorType.company
                        ? Icons.business
                        : Icons.person,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          // Name + role
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mc.name,
                  style: theme.textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mc.role,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 15.2 — Episode drill-down breakdown (Req 17)
  // ---------------------------------------------------------------------------

  Widget _buildEpisodeBreakdown(BuildContext context) {
    final theme = Theme.of(context);
    final episodes = work.episodeBreakdown;
    final count = episodes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        InkWell(
          onTap: () =>
              setState(() => _breakdownExpanded = !_breakdownExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  _breakdownExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count episode${count == 1 ? '' : 's'} with connections',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: episodes
                .map((ep) => _buildBreakdownEpisodeRow(context, ep))
                .toList(),
          ),
          crossFadeState: _breakdownExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildBreakdownEpisodeRow(
      BuildContext context, EpisodeBreakdownEntry episode) {
    final theme = Theme.of(context);
    final s = episode.seasonNumber.toString().padLeft(2, '0');
    final e = episode.episodeNumber.toString().padLeft(2, '0');
    final code = 'S${s}E$e';

    return InkWell(
      onTap: () => _onBreakdownEpisodeTap(context, episode),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: episode.isPeakEpisode
            ? BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(26, 4, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (episode.isPeakEpisode) ...[
                  Icon(
                    Icons.star,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  code,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _extractEpisodeName(episode.title),
                    style: theme.textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${episode.connectionCount} ${episode.connectionCount == 1 ? 'person' : 'people'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (episode.allContributors.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: episode.allContributors
                    .map((mc) => _buildContributorChip(context, mc))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onBreakdownEpisodeTap(
      BuildContext context, EpisodeBreakdownEntry episode) {
    final showId = episode.showId ?? work.tmdbId;
    final showName = episode.showName ?? work.title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvEpisodeDetailScreen(
          showId: showId,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          showName: showName,
        ),
      ),
    );
  }

  /// Extract just the episode name from a full title like
  /// "Show Name - S01E02 - Episode Name". Returns the last segment.
  String _extractEpisodeName(String fullTitle) {
    final parts = fullTitle.split(' - ');
    if (parts.length >= 3) {
      // Return everything after the second " - " (the episode name part)
      return parts.sublist(2).join(' - ');
    }
    return fullTitle;
  }

  // ---------------------------------------------------------------------------
  // 8.5 — Collection Indicator
  // ---------------------------------------------------------------------------

  Widget _buildCollectionIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final collectionOrderRepo = ref.watch(collectionOrderRepositoryProvider);
    final order = collectionOrderRepo.getOrder(work.collectionId!);
    if (order == null) return const SizedBox.shrink();

    // Look up collection name from watchlist entry
    final watchlistRepo = ref.watch(watchlistRepositoryProvider);
    final collectionEntry =
        watchlistRepo.getWork(work.collectionId!, WorkType.movie);
    final collectionName = collectionEntry?.title ?? 'Collection';

    return Positioned(
      bottom: 2,
      right: 2,
      child: Tooltip(
        message: collectionName,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            Icons.library_books,
            size: 14,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8.6 — Navigation
  // ---------------------------------------------------------------------------

  void _onCardTap(BuildContext context) {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (work.type == WorkType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            movieId: work.tmdbId,
            movieTitle: work.title,
          ),
        ),
      );
    } else if (work.type == WorkType.tvShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TvShowDetailScreen(
            showId: work.tmdbId,
            showTitle: work.title,
          ),
        ),
      );
    }
  }

  void _onContributorTap(BuildContext context, MatchedContributor mc) {
    // If this work has an episode breakdown, toggle it instead of navigating
    if (work.episodeBreakdown.isNotEmpty) {
      setState(() => _breakdownExpanded = !_breakdownExpanded);
      return;
    }
    final contributorRepo = ref.read(contributorRepositoryProvider);
    final contributor = contributorRepo.getContributor(mc.contributorId);
    if (contributor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContributorDetailScreen(contributor: contributor),
      ),
    );
  }
}
