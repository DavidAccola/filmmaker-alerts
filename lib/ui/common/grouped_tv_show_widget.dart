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
  final bool hideRatings;
  final VoidCallback? onTap;
  final void Function(Work)? onEpisodeWatchlist;
  final bool applyAgeStyling;
  final bool showDate;
  final bool showRating;
  final bool useShortDateFormat;

  const GroupedTvShowWidget({
    super.key,
    required this.showTitle,
    required this.episodes,
    this.hideRatings = false,
    this.onTap,
    this.onEpisodeWatchlist,
    this.applyAgeStyling = false,
    this.showDate = true,
    this.showRating = true,
    this.useShortDateFormat = false,
  });

  @override
  State<GroupedTvShowWidget> createState() => _GroupedTvShowWidgetState();
}

class _GroupedTvShowWidgetState extends State<GroupedTvShowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestEpisode = widget.episodes.first;

    // Check if show is more than 3 years old
    bool isOld = false;
    if (widget.applyAgeStyling && latestEpisode.releaseDate != null) {
      // Use Jan 1st of the current year for a "year-based" 3-year logic if preferred, 
      // but sticking to precise 3 years as requested.
      final now = DateTime.now();
      final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));
      isOld = latestEpisode.releaseDate!.isBefore(threeYearsAgo);
    }

    // Apply grayscale if old and not hovered
    final bool applyGrayscale = isOld && !_isHovered;

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
                    _buildPoster(theme, latestEpisode, applyGrayscale),

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
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Ratings in Bottom-Left
                    if (widget.showRating && !widget.hideRatings && latestEpisode.tmdbRating != null && latestEpisode.voteCount != null && latestEpisode.voteCount! > 0 && !(latestEpisode.tmdbRating == 0.0 && latestEpisode.releaseDate != null && latestEpisode.releaseDate!.isAfter(DateTime.now())))
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
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
                        ),
                      ),

                    // Media Type Icon in Bottom-Right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
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
                        color: Colors.black.withValues(alpha: 0.7),
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
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
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
                        if (widget.showDate)
                          Expanded(
                            child: Text(
                              () {
                                final date = latestEpisode.releaseDate!;
                                final now = DateTime.now();
                                
                                if (widget.useShortDateFormat) {
                                  return 'Latest: ${DateFormat('MM/dd/yyyy').format(date)}';
                                }

                                final twoYearsAgo = now.subtract(const Duration(days: 365 * 2));
                                if (date.isBefore(twoYearsAgo)) {
                                  return 'Latest: ${date.year}';
                                }
                                if (date.year == now.year) {
                                  return 'Latest: ${DateFormat('MMM d').format(date)}';
                                }
                                return 'Latest: ${DateFormat('MMM d, yyyy').format(date)}';
                              }(),
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

  Widget _buildPoster(ThemeData theme, Work work, bool applyGrayscale) {
    Widget image;
    if (work.posterPath != null) {
      image = Stack(
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
    } else {
      image = _buildPlaceholder(theme);
    }

    if (applyGrayscale) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: image,
      );
    }
    return image;
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.tv, size: 40)),
    );
  }
}
