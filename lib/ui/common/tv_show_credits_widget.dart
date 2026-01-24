import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';
import 'adaptive_tooltip_text.dart';
import 'watchlist_button.dart';

/// Widget for displaying TV show creator credits
class TvShowCreditsWidget extends StatefulWidget {
  final Work show;
  final bool hideRatings;
  final VoidCallback? onTap;
  final VoidCallback? onAddToWatchlist;

  const TvShowCreditsWidget({
    super.key,
    required this.show,
    this.hideRatings = false,
    this.onTap,
    this.onAddToWatchlist,
  });

  @override
  State<TvShowCreditsWidget> createState() => _TvShowCreditsWidgetState();
}

class _TvShowCreditsWidgetState extends State<TvShowCreditsWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                    widget.show.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w300${widget.show.posterPath}',
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
                                child: Icon(Icons.tv, size: 40),
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.tv, size: 40),
                            ),
                          ),
                    
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
                            if (!widget.hideRatings && widget.show.tmdbRating != null && widget.show.voteCount != null && widget.show.voteCount! > 0 && !(widget.show.tmdbRating == 0.0 && widget.show.releaseDate != null && widget.show.releaseDate!.isAfter(DateTime.now())))
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
                                    widget.show.tmdbRating!.toStringAsFixed(1),
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

                    // Watchlist Button - using new WatchlistButton component with center positioning and blue highlight
                    if (widget.onAddToWatchlist != null)
                      WatchlistButton(
                        tmdbId: widget.show.tmdbId,
                        workType: widget.show.type,
                        workTitle: widget.show.title,
                        posterPath: widget.show.posterPath,
                        releaseDate: widget.show.releaseDate,
                        releaseType: widget.show.releaseType ?? ReleaseType.streaming,
                        position: WatchlistButtonStyle.center,
                        showOnHoverOnly: true,
                        iconSize: 20,
                        isHovered: _isHovered,
                      ),
                  ],
                ),
              ),
              
              // Show information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Area with consistent height for up to 2 lines
                    SizedBox(
                      height: 32,
                      child: AdaptiveTooltipText(
                        widget.show.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Release date
                    if (widget.show.releaseDate != null)
                      Text(
                        _formatReleaseDate(widget.show.releaseDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
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
    return DateFormat('MMM d, yyyy').format(date);
  }
}
