import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';
import 'adaptive_tooltip_text.dart';

/// Widget for displaying TV show creator credits
class TvShowCreditsWidget extends StatelessWidget {
  final Work show;
  final bool hidePopularity;
  final bool hideRatings;
  final VoidCallback? onTap;
  final VoidCallback? onAddToWatchlist;

  const TvShowCreditsWidget({
    super.key,
    required this.show,
    this.hidePopularity = false,
    this.hideRatings = false,
    this.onTap,
    this.onAddToWatchlist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  show.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w300${show.posterPath}',
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
                ],
              ),
            ),
            
            // Show information
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  AdaptiveTooltipText(
                    '📺 ${show.title}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Release date
                  if (show.releaseDate != null)
                    Text(
                      _formatReleaseDate(show.releaseDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  
                  // Rating and popularity row
                  if ((!hideRatings && show.tmdbRating != null) || 
                      (!hidePopularity && show.popularity != null) ||
                      onAddToWatchlist != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // TMDB Rating
                          if (!hideRatings && show.tmdbRating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  show.tmdbRating!.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          
                          // Spacer between rating and popularity
                          if (!hideRatings && show.tmdbRating != null && 
                              !hidePopularity && show.popularity != null)
                            const SizedBox(width: 12),
                          
                          // Popularity
                          if (!hidePopularity && show.popularity != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  show.popularity!.toInt().toString(),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          
                          const Spacer(),
                          
                          // Watchlist button
                          if (onAddToWatchlist != null)
                            IconButton(
                              onPressed: onAddToWatchlist,
                              icon: const Icon(Icons.add),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: 'Add to Watchlist',
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
    );
  }

  String _formatReleaseDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
