import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';

class CreditExpansionSection extends StatefulWidget {
  final List<Work> works;
  final bool hidePopularity;
  final bool hideRatings;
  final Function(Work)? onWorkTap;
  final Function(Work)? onAddToWatchlist;

  const CreditExpansionSection({
    super.key,
    required this.works,
    this.hidePopularity = false,
    this.hideRatings = false,
    this.onWorkTap,
    this.onAddToWatchlist,
  });

  @override
  State<CreditExpansionSection> createState() => _CreditExpansionSectionState();
}

class _CreditExpansionSectionState extends State<CreditExpansionSection> {
  late Map<String, List<Work>> groupedByDept;
  final Set<String> expandedDepts = {};
  final Set<String> expandedShows = {};

  @override
  void initState() {
    super.initState();
    _processWorks();
  }

  @override
  void didUpdateWidget(CreditExpansionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.works != widget.works) {
      _processWorks();
    }
  }

  void _processWorks() {
    debugPrint('[CreditExpansionSection] Processing ${widget.works.length} works');
    groupedByDept = TvShowDisplayLogic.groupWorksByDepartment(widget.works);
    debugPrint('[CreditExpansionSection] Grouped into departments: ${groupedByDept.keys.toList()}');
    
    // Expand the first department by default if there's only one or few
    if (groupedByDept.keys.isNotEmpty && expandedDepts.isEmpty) {
      expandedDepts.add(groupedByDept.keys.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedDepts = groupedByDept.keys.toList()..sort();

    return Column(
      children: sortedDepts.map((dept) {
        final worksInDept = groupedByDept[dept]!;
        final isDeptExpanded = expandedDepts.contains(dept);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Department Header
              Material(
                color: theme.colorScheme.surfaceContainerHigh,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isDeptExpanded) {
                        expandedDepts.remove(dept);
                      } else {
                        expandedDepts.add(dept);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isDeptExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dept,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${worksInDept.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (isDeptExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildWorksList(worksInDept),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWorksList(List<Work> works) {
    // Separate into Shows (with potentially multiple episodes) and Movies/Single items
    final Map<String, List<Work>> tvGroups = TvShowDisplayLogic.groupEpisodesByShow(
      works.where((w) => w.type == WorkType.tvEpisode).toList(),
    );
    
    final List<Work> nonEpisodeWorks = works.where((w) => w.type != WorkType.tvEpisode).toList()
      ..sort((a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });

    return Column(
      children: [
        // TV Groups first
        ...tvGroups.entries.map((entry) {
          final showTitle = entry.key;
          final episodes = entry.value;
          final isShowExpanded = expandedShows.contains(showTitle);

          return Column(
            children: [
              _buildShowHeader(showTitle, episodes, isShowExpanded),
              if (isShowExpanded)
                Column(
                  children: episodes.map((ep) => _buildWorkItem(ep, isEpisode: true)).toList(),
                ),
            ],
          );
        }),
        // Then individual works (Movies, etc)
        ...nonEpisodeWorks.map((work) => _buildWorkItem(work)),
      ],
    );
  }

  Widget _buildShowHeader(String title, List<Work> episodes, bool isExpanded) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              expandedShows.remove(title);
            } else {
              expandedShows.add(title);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Show poster in header if expanded
              if (isExpanded && episodes.isNotEmpty && episodes.first.posterPath != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w200${episodes.first.posterPath}',
                      width: 30,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkItem(Work work, {bool isEpisode = false}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => widget.onWorkTap?.call(work),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isEpisode ? 40 : 16, 
          vertical: 8
        ),
        child: Row(
          children: [
            if (isEpisode)
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'S${work.seasonNumber?.toString().padLeft(2, '0')}E${work.episodeNumber?.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (work.posterPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: 'https://image.tmdb.org/t/p/w200${work.posterPath}',
                  width: 32,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 32,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.movie, size: 16),
              ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEpisode ? _extractEpisodeTitle(work.title) : work.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (work.releaseDate != null)
                    Text(
                      DateFormat('yyyy').format(work.releaseDate!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            if (!widget.hideRatings && work.tmdbRating != null && work.tmdbRating! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    work.tmdbRating!.toStringAsFixed(1),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),

            if (widget.onAddToWatchlist != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () => widget.onAddToWatchlist?.call(work),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40),
                tooltip: 'Add to Watchlist',
              ),
          ],
        ),
      ),
    );
  }

  String _extractEpisodeTitle(String title) {
    final parts = title.split(' - ');
    if (parts.length >= 3) return parts.sublist(2).join(' - ');
    if (parts.length == 2) return parts[1];
    return title;
  }
}
