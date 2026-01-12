import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/work_sorting_logic.dart';
import 'adaptive_tooltip_text.dart';

class WorkWidget extends StatefulWidget {
  final Work work;
  final bool hideRatings;
  final VoidCallback? onTap;
  final VoidCallback? onAddToWatchlist;
  final bool applyAgeStyling;

  const WorkWidget({
    super.key,
    required this.work,
    this.hideRatings = false,
    this.onTap,
    this.onAddToWatchlist,
    this.applyAgeStyling = false,
  });

  @override
  State<WorkWidget> createState() => _WorkWidgetState();
}

class _WorkWidgetState extends State<WorkWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final work = widget.work;
    
    // Check if work is more than 3 years old
    bool isOld = false;
    if (widget.applyAgeStyling && work.releaseDate != null) {
      final threeYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 3));
      isOld = work.releaseDate!.isBefore(threeYearsAgo);
    }

    // Apply grayscale if old and not hovered
    final bool applyGrayscale = isOld && !_isHovered;

    Widget poster = work.posterPath != null
        ? CachedNetworkImage(
            imageUrl: 'https://image.tmdb.org/t/p/w300${work.posterPath}',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.movie, size: 40),
              ),
            ),
          )
        : Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.movie, size: 40),
            ),
          );

    if (applyGrayscale) {
      poster = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: poster,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
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
                    // Fallback white background for transparent posters (logos)
                    Container(color: Colors.white),
                    poster,
                    
                    // Bottom Gradient Overlay for readability
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
  
                    // Ratings in Bottom-Left
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
                            if (!widget.hideRatings && work.tmdbRating != null && work.voteCount != null && work.voteCount! > 0 && !(work.tmdbRating == 0.0 && work.releaseDate != null && work.releaseDate!.isAfter(DateTime.now())))
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
                                    '${work.tmdbRating!.toStringAsFixed(1)} (${_formatVoteCount(work.voteCount!)})',
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
                        child: Icon(
                          work.type == WorkType.movie ? Icons.movie : Icons.tv,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Work information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Area with consistent height for up to 2 lines
                    SizedBox(
                      height: 32,
                      child: AdaptiveTooltipText(
                        work.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Release date and Watchlist button Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (work.releaseDate != null)
                                Text(
                                  _formatReleaseDate(work.releaseDate!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              
                              if (work.releaseType != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: _buildReleaseTypeChip(context, work.releaseType!),
                                ),
                            ],
                          ),
                        ),
                        
                        if (widget.onAddToWatchlist != null)
                          IconButton(
                            onPressed: widget.onAddToWatchlist,
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            tooltip: 'Add to Watchlist',
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    
                    if (work.contributorRoles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AdaptiveTooltipText(
                          WorkSortingLogic.sortRoles(work.contributorRoles).map((r) => r.role).join(', '),
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

  String _formatReleaseDate(DateTime date) {
    final now = DateTime.now();
    final twoYearsAgo = now.subtract(const Duration(days: 365 * 2));
    if (date.isBefore(twoYearsAgo)) {
      return date.year.toString();
    }
    if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatVoteCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return count.toString();
  }

  Widget _buildReleaseTypeChip(BuildContext context, ReleaseType releaseType) {
    final theme = Theme.of(context);
    String label;
    Color color;
    
    switch (releaseType) {
      case ReleaseType.theatrical:
        label = 'Theatrical';
        color = theme.colorScheme.primary;
        break;
      case ReleaseType.streaming:
        label = 'Streaming';
        color = Colors.purple;
        break;
      case ReleaseType.digital:
        label = 'Digital';
        color = Colors.blue;
        break;
      case ReleaseType.physical:
        label = 'Physical';
        color = Colors.green;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}