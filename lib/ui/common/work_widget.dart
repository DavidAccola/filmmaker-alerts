import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/work_sorting_logic.dart';
import 'adaptive_tooltip_text.dart';

class WorkWidget extends StatelessWidget {
  final Work work;
  final bool hidePopularity;
  final bool hideRatings;
  final VoidCallback? onTap;
  final VoidCallback? onAddToWatchlist;

  const WorkWidget({
    super.key,
    required this.work,
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
            // Poster image with Type Icon
            // Poster image area
            SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fallback white background for transparent posters (logos)
                  Container(color: Colors.white),
                  work.posterPath != null
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
                        ),
                ],
              ),
            ),
            
            // Work information
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  AdaptiveTooltipText(
                    '${work.type == WorkType.movie ? '🎬' : '📺'} ${work.title}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Release date
                  if (work.releaseDate != null)
                    Text(
                      _formatReleaseDate(work.releaseDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10, // Consistent font size for dates
                      ),
                    ),
                  
                  // Release type indicator
                  if (work.releaseType != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildReleaseTypeChip(context, work.releaseType!),
                    ),
                  
                  // Roles Row (Truncated with tooltip)
                  if (work.contributorRoles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AdaptiveTooltipText(
                        WorkSortingLogic.sortRoles(work.contributorRoles).map((r) => r.role).join(', '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10, // Consistent font size for roles
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  
                  // Rating and popularity row
                  if ((!hideRatings && work.tmdbRating != null) || 
                      (!hidePopularity && work.popularity != null) ||
                      onAddToWatchlist != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // TMDB Rating
                          if (!hideRatings && work.tmdbRating != null)
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
                                  work.tmdbRating!.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          
                          // Spacer between rating and popularity
                          if (!hideRatings && work.tmdbRating != null && 
                              !hidePopularity && work.popularity != null)
                            const SizedBox(width: 12),
                          
                          // Popularity
                          if (!hidePopularity && work.popularity != null)
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
                                  work.popularity!.toInt().toString(),
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

  String _getReleaseEmoji(ReleaseType? type) {
    if (work.type == WorkType.tvEpisode || work.type == WorkType.tvShow) return '';
    if (type == null) return '🗓️';
    switch (type) {
      case ReleaseType.theatrical:
        return '🍿';
      case ReleaseType.streaming:
      case ReleaseType.digital:
        return '💻';
      case ReleaseType.physical:
        return '📀';
    }
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