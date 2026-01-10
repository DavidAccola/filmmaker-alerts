import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';
import '../../logic/work_sorting_logic.dart';
import 'adaptive_tooltip_text.dart';

class GroupedTvShowWidget extends StatefulWidget {
  final String showTitle;
  final List<Work> episodes;
  final bool hidePopularity;
  final bool hideRatings;
  final VoidCallback? onTap;
  final void Function(Work)? onEpisodeWatchlist;

  const GroupedTvShowWidget({
    super.key,
    required this.showTitle,
    required this.episodes,
    this.hidePopularity = false,
    this.hideRatings = false,
    this.onTap,
    this.onEpisodeWatchlist,
  });

  @override
  State<GroupedTvShowWidget> createState() => _GroupedTvShowWidgetState();
}

class _GroupedTvShowWidgetState extends State<GroupedTvShowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstEpisode = widget.episodes.last;
    final latestEpisode = widget.episodes.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster image area
              SizedBox(
                height: 230,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPoster(theme, latestEpisode),
                    // Overlay when hovered
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Episodes',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.episodes.length,
                                itemBuilder: (context, index) {
                                  final ep = widget.episodes[index];
                                  final epInfo = TvShowDisplayLogic.formatEpisodeInfo(ep);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      epInfo,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge for episode count (only if > 1)
                    if (widget.episodes.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.episodes.length} EP',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Show details
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveTooltipText(
                      '📺 ${widget.showTitle}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest: ${DateFormat('MMM d').format(latestEpisode.releaseDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    
                    // Roles Row (Truncated with tooltip)
                    if (latestEpisode.contributorRoles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AdaptiveTooltipText(
                          WorkSortingLogic.sortRoles(latestEpisode.contributorRoles).map((r) => r.role).join(', '),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    // Rating row
                    if ((!widget.hideRatings && latestEpisode.tmdbRating != null) || 
                        widget.onEpisodeWatchlist != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (!widget.hideRatings && latestEpisode.tmdbRating != null) ...[
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                latestEpisode.tmdbRating!.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                            const Spacer(),
                            if (widget.onEpisodeWatchlist != null)
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () => widget.onEpisodeWatchlist!(latestEpisode),
                                  tooltip: 'Add latest to watchlist',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoster(ThemeData theme, Work work) {
    if (work.posterPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.white),
          CachedNetworkImage(
            imageUrl: 'https://image.tmdb.org/t/p/w300${work.posterPath}',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
            errorWidget: (context, url, error) => _buildPlaceholder(theme),
          ),
        ],
      );
    }
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.tv, size: 40)),
    );
  }
}
