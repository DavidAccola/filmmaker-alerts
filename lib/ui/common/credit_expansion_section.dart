import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';

class CreditExpansionSection extends StatefulWidget {
  final String title;
  final List<Work> works;
  final bool hideRatings;
  final IconData? icon;
  final Function(Work)? onWorkTap;
  final Function(Work)? onAddToWatchlist;

  const CreditExpansionSection({
    super.key,
    required this.title,
    required this.works,
    this.hideRatings = false,
    this.icon,
    this.onWorkTap,
    this.onAddToWatchlist,
  });

  @override
  State<CreditExpansionSection> createState() => _CreditExpansionSectionState();
}

class _CreditExpansionSectionState extends State<CreditExpansionSection> {
  late Map<String, List<Work>> groupedByDept;
  bool _isExpanded = false;
  bool _groupByRole = true;
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
    debugPrint('[CreditExpansionSection] Processing ${widget.works.length} works for ${widget.title}');
    groupedByDept = TvShowDisplayLogic.groupWorksByDepartment(widget.works);
    


    debugPrint('[CreditExpansionSection] Grouped into departments: ${groupedByDept.keys.toList()}');
    
    // DEBUG: Diagnose Legion Writing credits
    if (widget.title.contains('Television')) {
       final writing = groupedByDept['Writing'] ?? [];
       final legionWorks = writing.where((w) => w.title.contains('Legion')).toList();
       debugPrint('[DEBUG] Legion works in Writing section: ${legionWorks.length}');
       for(var w in legionWorks) {
          debugPrint('   - ${w.title} (${w.type})');
       }
       
       // Also check raw works
       final rawLegion = widget.works.where((w) => w.title.contains('Legion')).toList();
       debugPrint('[DEBUG] Total Legion raw works: ${rawLegion.length}');
       for(var w in rawLegion) {
          if (w.type == WorkType.tvEpisode) {
             // Check if it has a writing role
             final writingRoles = w.contributorRoles.where((r) => r.role.toLowerCase().contains('writer') || r.department == 'Writing').toList();
             if (writingRoles.isNotEmpty) {
                // debugPrint('   - Raw Episode has writing: ${w.title}');
             }
          }
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedDepts = groupedByDept.keys.toList()..sort((a, b) {
      int score(String s) {
        if (s == 'Cast') return 2;
        if (s == 'General') return 1;
        return 0;
      }
      final sa = score(a);
      final sb = score(b);
      if (sa != sb) return sa.compareTo(sb);
      return a.compareTo(b);
    });

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Main Section Header (Collapsible)
          Material(
            color: theme.colorScheme.surfaceContainer,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.works.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more, 
                      color: theme.colorScheme.onSurfaceVariant
                    ),
                  ],
                ),
              ),
            ),
          ),



          // Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // View Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Group by Role', style: theme.textTheme.labelSmall),
                        Switch(
                          value: _groupByRole,
                          onChanged: (val) {
                            setState(() {
                              _groupByRole = val;
                            });
                          },
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),

                  if (_groupByRole)
                    ...sortedDepts.map((dept) {
                      final worksInDept = groupedByDept[dept]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              dept.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          _buildWorksList(worksInDept, dept),
                        ],
                      );
                    }).toList()
                  else
                    _buildChronologicalList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChronologicalList() {
    // Flatten all works
    final allWorks = widget.works;
    
    // Group by unique Show/Movie (using title as key for simplicity in TV)
    final Map<String, Work> uniqueWorks = {};
    final Map<String, List<Work>> episodesMap = {};

    for (var w in allWorks) {
      String key;
      if (w.type == WorkType.tvEpisode) {
        key = TvShowDisplayLogic.extractShowTitle(w.title);
      } else {
        key = w.title;
      }
      
      // Keep the "best" work object (prefer Show over Episode for metadata)
      if (!uniqueWorks.containsKey(key)) {
        uniqueWorks[key] = w;
      } else if (uniqueWorks[key]!.type == WorkType.tvEpisode && w.type == WorkType.tvShow) {
        uniqueWorks[key] = w;
      }
      
      // Collect episodes if this is an episode or if we decide to list them
      if (w.type == WorkType.tvEpisode) {
        episodesMap.putIfAbsent(key, () => []).add(w);
      }
    }

    final sortedKeys = uniqueWorks.keys.toList()
      ..sort((a, b) {
        final wa = uniqueWorks[a]!;
        final wb = uniqueWorks[b]!;
        if (wa.releaseDate == null && wb.releaseDate == null) return 0;
        if (wa.releaseDate == null) return 1;
        if (wb.releaseDate == null) return -1;
        return wb.releaseDate!.compareTo(wa.releaseDate!);
      });

    return Column(
      children: sortedKeys.map((key) {
        var work = uniqueWorks[key]!;
        final episodes = episodesMap[key] ?? [];
        
        // Ensure work is treated as Show if it has episodes, even if we only caught an episode object
        if (work.type == WorkType.tvEpisode) {
           work = work.copyWith(
             type: WorkType.tvShow,
             title: key,
             // Keep release date but remove specific episode details for the Header
             seasonNumber: null,
             episodeNumber: null,
           );
        }

        episodes.sort((a, b) {
            if (a.seasonNumber != b.seasonNumber) {
              return (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
            }
            return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
        });

        // Check single episode case for chronological view too
        if (episodes.length == 1) {
            final ep = episodes.first;
            final combinedTitle = "$key (S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')} - ${_extractEpisodeTitle(ep.title)})";
            return _buildWorkItem(
              work.copyWith(title: combinedTitle),
              children: null
            );
        }

        return _buildWorkItem(
          work, 
          children: episodes.map((ep) => _buildWorkItem(ep, isEpisode: true)).toList()
        );
      }).toList(),
    );
  }

  Widget _buildWorksList(List<Work> works, [String? filterDept]) {
    
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

    // Strategy: 
    // 1. Iterate through TV groups. If a nonEpisodeWork matches the show title, use it as the "Header" work.
    //    If not, synthesize a header work from the first episode.
    // 2. Render remaining nonEpisodeWorks.

    final List<Widget> renderedGroups = [];

    // Sort groups by air date of first episode if possible, or title
    final sortedGroupKeys = tvGroups.keys.toList(); // Could sort by date here if desired

    for (final showTitle in sortedGroupKeys) {
      final episodes = tvGroups[showTitle]!;
      
      // Try to find matching Show Work
      Work? showWork;
      final matchIndex = nonEpisodeWorks.indexWhere((w) => w.title == showTitle);
      if (matchIndex != -1) {
        showWork = nonEpisodeWorks[matchIndex];
        nonEpisodeWorks.removeAt(matchIndex);
      } else {
        // Synthesize header from first episode
        final firstEp = episodes.first;
        showWork = firstEp.copyWith(
          type: WorkType.tvShow,
          title: showTitle,
          seasonNumber: null,
          episodeNumber: null,
          // Keep other metadata like poster, date
        );
      }

      
      // Check single episode special case
      if (episodes.length == 1) {
          final ep = episodes.first;
          final combinedTitle = "$showTitle (S${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')} - ${_extractEpisodeTitle(ep.title)})";
          
          renderedGroups.add(
            _buildWorkItem(
              showWork!.copyWith(title: combinedTitle),
              children: null, // No details row
              currentDepartmentFilter: filterDept,
            )
          );
      } else {
          renderedGroups.add(
            _buildWorkItem(
              showWork!, 
              children: episodes.map((ep) => _buildWorkItem(ep, isEpisode: true, currentDepartmentFilter: filterDept)).toList(), // Pass filter to children too
              currentDepartmentFilter: filterDept,
            )
          );
      }
    }

    return Column(
      children: [
        // Merged TV Groups
        ...renderedGroups,
        
        // Remaining standalone works
        ...nonEpisodeWorks.map((work) => _buildWorkItem(work, currentDepartmentFilter: filterDept)),
      ],
    );
  }



  Widget _buildWorkItem(Work work, {bool isEpisode = false, List<Widget>? children, String? currentDepartmentFilter}) {
    final theme = Theme.of(context);
    
    // Logic to sort and filter roles
    List<String> rawRoles;
    if (currentDepartmentFilter != null) {
      // In Grouped Mode: Show only roles for this department
      rawRoles = work.contributorRoles
        .where((r) {
            // Check mapping
            if (currentDepartmentFilter == 'Cast' && (r.department == null || r.department!.isEmpty || r.role == 'Acting' || r.role == 'Cast')) return true;
             // Use relaxed matching or strict? 
             final dept = r.department ?? (work.type == WorkType.movie ? 'Movie' : 'TV'); // basic fallback
             // We can rely on TvShowDisplayLogic logic but deeper...
             // Simplified: if filter is 'Directing', accept 'Director', 'Directing'
             if (currentDepartmentFilter == 'Directing' && (r.role.contains('Director') || r.department == 'Directing')) return true;
             if (currentDepartmentFilter == 'Writing' && (r.role.contains('Writer') || r.department == 'Writing' || r.role.contains('Screenplay'))) return true;
             if (currentDepartmentFilter == 'Creator' && (r.role.contains('Creator') || r.role.contains('Created'))) return true;
             if (currentDepartmentFilter == 'Production' && (r.department == 'Production' || r.role.contains('Producer'))) return true;
             // Default match
             return (r.department == currentDepartmentFilter);
        })
        .map((r) => r.role)
        .toList();
    } else {
       rawRoles = work.contributorRoles.map((r) => r.role).toList();
    }
    
    // Remove generic "TV"/"Movie" roles if we have better ones
    rawRoles = rawRoles.where((r) => !['tv', 'movie', 'tv show', 'general'].contains(r.toLowerCase())).toList();
    
    // Sort Roles
    rawRoles.sort((a, b) {
       int score(String role) {
          final r = role.toLowerCase();
          if (r.contains('creator') || r.contains('created')) return 0;
          if (r.contains('director') || r.contains('directing')) return 1;
          if (r.contains('producer') || r.contains('production')) return 2;
          if (r.contains('writer') || r.contains('writing') || r.contains('screenplay')) return 3;
          if (r.contains('self') || r.contains('cameo') || r.contains('host')) return 99; // Cast last
           // Try to detect Cast names? Usually specialized
          return 4; // Others alphabetical
       }
       final sa = score(a);
       final sb = score(b);
       if (sa != sb) return sa.compareTo(sb);
       return a.compareTo(b);
    });

    // Separator logic for Cast
    // If chronological (no filter), we might have Crew AND Cast.
    // Check if we switched from score < 10 to score 99
    final List<TextSpan> roleSpans = [];
    bool hasCastSeparator = false;

    if (rawRoles.isNotEmpty) {
       // dedupe
       final uniqueRoles = <String>[];
       for(var r in rawRoles) { if(!uniqueRoles.contains(r)) uniqueRoles.add(r); }
       
       for (int i = 0; i < uniqueRoles.length; i++) {
          final role = uniqueRoles[i];
          // Check if this is a cast role (simple heuristic for now: lowest priority in our sort)
          bool isCast = role.toLowerCase().contains('self') || role.toLowerCase().contains('cameo') || role.toLowerCase().contains('host'); // imperfect but fits known data
          // Better: If we have multiple types and sorting put them at end...
          // If we want a generic separator before the "Cast" block
          
          if (currentDepartmentFilter == null && !hasCastSeparator && i > 0) {
             // Heuristic: If previous was Crew and this is Cast?
             // Or just simple comma join, keeping it simple as requested: "Do a bullet... before the list of Cast roles"
             // Let's assume the last block of roles are Cast if they aren't the standard Crew ones.
          }
          if (i > 0) roleSpans.add(const TextSpan(text: ', '));
          
          if (currentDepartmentFilter == null && !hasCastSeparator && isCast && i > 0) {
             roleSpans.add(const TextSpan(text: '• ', style: TextStyle(fontWeight: FontWeight.bold)));
             hasCastSeparator = true; 
          }
          roleSpans.add(TextSpan(text: role));
       }
    }

    final rolesText = rawRoles.toSet().join(', '); // Fallback simple join for now to ensure safety, span logic is complex without precise Cast detection
    // Let's refine the join:
    String finalRolesString = "";
    if (rawRoles.isNotEmpty) {
        List<String> crew = [];
        List<String> cast = [];
        for (var r in rawRoles.toSet()) {
            final lower = r.toLowerCase();
             if (lower.contains('creator') || lower.contains('director') || lower.contains('producer') || lower.contains('writer') || lower.contains('screenplay')) {
                 crew.add(r);
             } else {
                 cast.add(r);
             }
        }
        if (crew.isNotEmpty) finalRolesString += crew.join(', ');
        if (cast.isNotEmpty) {
            if (crew.isNotEmpty) finalRolesString += " • ";
            finalRolesString += cast.join(', ');
        }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onWorkTap?.call(work),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isEpisode ? 32 : 16,  // More indentation for episodes
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
                          fontWeight: FontWeight.bold, // Bold title
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // YEAR Row (less emphasized)
                      if (work.releaseDate != null)
                        Text(
                          _formatDateRange(work),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      // ROLES Row (more important)
                      if (finalRolesString.isNotEmpty && !isEpisode)
                       Padding(
                         padding: const EdgeInsets.only(top: 2.0),
                         child: Text(
                            finalRolesString,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                       ),
                    ],
                  ),
                ),

                if (!widget.hideRatings && work.tmdbRating != null && work.voteCount != null && work.voteCount! > 0 && work.tmdbRating! > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
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
        ),
        if (children != null)
          ...children,
      ],
    );
  }

  String _extractEpisodeTitle(String title) {
    final parts = title.split(' - ');
    if (parts.length >= 3) return parts.sublist(2).join(' - ');
    if (parts.length == 2) return parts[1];
    return title;
  }
  
  String _formatDateRange(Work work) {
    if (work.releaseDate == null) return '';
    
    final startYear = DateFormat('yyyy').format(work.releaseDate!);
    
    // Debug logging for specific shows
    if (work.title.contains('Legion') || work.title.contains('Fargo')) {
      debugPrint('[DEBUG UI] ${work.title}: type=${work.type}, releaseDate=${work.releaseDate}, endDate=${work.endDate}');
    }
    
    // For TV shows with an end date, show range
    if (work.type == WorkType.tvShow && work.endDate != null) {
      final endYear = DateFormat('yyyy').format(work.endDate!);
      // Only show range if years are different
      if (startYear != endYear) {
        return '$startYear-$endYear';
      }
    }
    
    return startYear;
  }
}
