import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';

/// Widget for displaying TV episodes directed by a contributor
class DirectedEpisodesWidget extends StatefulWidget {
  final List<Work> episodes;
  final bool hidePopularity;
  final bool hideRatings;
  final Function(Work)? onEpisodeTap;
  final Function(Work)? onAddToWatchlist;

  const DirectedEpisodesWidget({
    super.key,
    required this.episodes,
    this.hidePopularity = false,
    this.hideRatings = false,
    this.onEpisodeTap,
    this.onAddToWatchlist,
  });

  @override
  State<DirectedEpisodesWidget> createState() => _DirectedEpisodesWidgetState();
}

class _DirectedEpisodesWidgetState extends State<DirectedEpisodesWidget> {
  late Map<String, List<Work>> groupedEpisodes;
  late List<String> expandedShows;

  @override
  void initState() {
    super.initState();
    groupedEpisodes = TvShowDisplayLogic.groupEpisodesByShow(widget.episodes);
    expandedShows = [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (groupedEpisodes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Text(
          'No directed episodes',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: groupedEpisodes.entries.map((entry) {
        final showTitle = entry.key;
        final episodes = entry.value;
        final isExpanded = expandedShows.contains(showTitle);

        return Column(
          children: [
            // Show header (expandable)
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      expandedShows.remove(showTitle);
                    } else {
                      expandedShows.add(showTitle);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${episodes.length} episode${episodes.length != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Episodes list (expandable)
            if (isExpanded)
              Column(
                children: episodes.map((episode) {
                  return _buildEpisodeItem(context, episode);
                }).toList(),
              ),
            
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEpisodeItem(BuildContext context, Work episode) {
    final theme = Theme.of(context);
    final episodeInfo = TvShowDisplayLogic.formatEpisodeInfo(episode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onEpisodeTap?.call(episode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Episode number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  episodeInfo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Episode details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Episode title
                    Text(
                      episode.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Air date
                    if (episode.releaseDate != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(episode.releaseDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Rating
              if (!widget.hideRatings && episode.tmdbRating != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        episode.tmdbRating!.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              
              // Watchlist button
              if (widget.onAddToWatchlist != null)
                IconButton(
                  onPressed: () => widget.onAddToWatchlist?.call(episode),
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
        ),
      ),
    );
  }
}
