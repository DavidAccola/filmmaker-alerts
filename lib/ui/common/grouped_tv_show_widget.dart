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

                    // Bottom Gradient Overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Ratings and Popularity in Bottom-Left
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.hideRatings && latestEpisode.tmdbRating != null && !(latestEpisode.tmdbRating == 0.0 && latestEpisode.releaseDate != null && latestEpisode.releaseDate!.isAfter(DateTime.now())))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    latestEpisode.tmdbRating!.toStringAsFixed(1),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            if (!widget.hidePopularity && latestEpisode.popularity != null && !(latestEpisode.popularity == 0.0 && latestEpisode.releaseDate != null && latestEpisode.releaseDate!.isAfter(DateTime.now())))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    size: 14,
                                    color: theme.colorScheme.primaryContainer,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    latestEpisode.popularity!.toInt().toString(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Media Type Icon in Bottom-Right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.tv,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

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
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Area with consistent height for up to 2 lines
                    SizedBox(
                      height: 32,
                      child: AdaptiveTooltipText(
                        widget.showTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Latest: ${DateFormat('MMM d').format(latestEpisode.releaseDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (widget.onEpisodeWatchlist != null)
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () => widget.onEpisodeWatchlist!(latestEpisode),
                              tooltip: 'Add latest to watchlist',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    
                    // Roles Row (Truncated with tooltip)
                    if (latestEpisode.contributorRoles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
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
