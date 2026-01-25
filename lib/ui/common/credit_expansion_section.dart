import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/tv_show_display_logic.dart';
import 'watchlist_button.dart';

class CreditExpansionSection extends StatefulWidget {
  final String title;
  final List<Work> works;
  final bool hideRatings;
  final IconData? icon;
  final Function(Work)? onWorkTap;
  final Function(Work)? onAddToWatchlist;
  final bool splitByStage;

  const CreditExpansionSection({
    super.key,
    required this.title,
    required this.works,
    this.hideRatings = false,
    this.icon,
    this.onWorkTap,
    this.onAddToWatchlist,
    this.splitByStage = true,
  });

  @override
  State<CreditExpansionSection> createState() => _CreditExpansionSectionState();
}

class _CreditExpansionSectionState extends State<CreditExpansionSection> {
  late Map<String, List<Work>> groupedByDept;
  bool _isExpanded = false;
  bool _groupByRole = true;
  final Set<String> expandedShows = {};
  final GlobalKey _sectionKey = GlobalKey();

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
    if (widget.splitByStage) {
      groupedByDept = TvShowDisplayLogic.groupWorksByDepartmentAndStage(widget.works);
    } else {
      groupedByDept = TvShowDisplayLogic.groupWorksByDepartment(widget.works);
    }

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

  /// Sorts departments for TV/Movie credits (without stage splitting)
  /// Order: Creator, Directing, Writing, Production, Other departments (alphabetical), General, Cast
  List<String> _sortDepartmentsForCredits(List<String> depts) {
    const priority = ['Creator', 'Directing', 'Writing', 'Production'];
    
    final sorted = depts.toList();
    sorted.sort((a, b) {
      // Cast and General go last
      if (a == 'Cast' && b == 'Cast') return 0;
      if (a == 'Cast') return 1;
      if (b == 'Cast') return -1;
      
      if (a == 'General' && b == 'General') return 0;
      if (a == 'General') return 1;
      if (b == 'General') return -1;
      
      // Priority departments first
      final aIdx = priority.indexOf(a);
      final bIdx = priority.indexOf(b);
      
      if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;
      
      // Other departments alphabetically
      return a.compareTo(b);
    });
    
    return sorted;
  }

  /// Sorts departments by Stage 1/Stage 2 priority and department order
  /// Stage 1 order: Creator, Directing, Writing, Producing, Sound, Other (alphabetical)
  /// Then Stage 2 order: Same department order
  List<String> _sortDepartments(List<String> depts) {
    const stage1Priority = ['Creator', 'Directing', 'Writing', 'Producing', 'Sound'];
    
    final stage1Depts = <String>[];
    final stage2Depts = <String>[];
    
    for (final dept in depts) {
      // Extract department name and stage from key like "Directing - Stage 1"
      final parts = dept.split(' - ');
      final stage = parts.length > 1 ? parts[1] : 'Stage 1';
      
      if (stage == 'Stage 1') {
        stage1Depts.add(dept);
      } else {
        stage2Depts.add(dept);
      }
    }
    
    // Sort stage1 by priority order
    stage1Depts.sort((a, b) {
      final aDept = a.split(' - ')[0];
      final bDept = b.split(' - ')[0];
      
      if (aDept == 'Cast') return 1;
      if (bDept == 'Cast') return -1;
      if (aDept == 'General') return 1;
      if (bDept == 'General') return -1;
      
      final aIdx = stage1Priority.indexOf(aDept);
      final bIdx = stage1Priority.indexOf(bDept);
      if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;
      return aDept.compareTo(bDept);
    });
    
    // Sort stage2 by priority order
    stage2Depts.sort((a, b) {
      final aDept = a.split(' - ')[0];
      final bDept = b.split(' - ')[0];
      
      final aIdx = stage1Priority.indexOf(aDept);
      final bIdx = stage1Priority.indexOf(bDept);
      if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;
      return aDept.compareTo(bDept);
    });
    
    return [...stage1Depts, ...stage2Depts];
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0, // Align to top
        );
      }
    });
  }

  /// Builds the preview content based on current _groupByRole state
  Widget _buildPreview() {
    if (_groupByRole) {
      // Show grouped by role preview
      final sortedDepts = widget.splitByStage 
          ? _sortDepartments(groupedByDept.keys.toList())
          : _sortDepartmentsForCredits(groupedByDept.keys.toList());
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedDepts.map((dept) {
          final worksInDept = groupedByDept[dept]!;
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    dept.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              _buildWorksList(worksInDept, dept),
            ],
          );
        }).toList(),
      );
    } else {
      // Show chronological preview
      return _buildChronologicalList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedDepts = widget.splitByStage 
        ? _sortDepartments(groupedByDept.keys.toList())
        : _sortDepartmentsForCredits(groupedByDept.keys.toList());

    return Card(
      key: _sectionKey,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Icon + Title + Group by Role toggle)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                    // Scroll to top when expanding
                    if (_isExpanded) {
                      _scrollToTop();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        // Group by Role toggle on the right
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                      ],
                    ),
                  ),
                ),

                if (_isExpanded) ...[
                  // Expanded Controls (Group by Role toggle moved to header, so remove it from here)
                  // No additional controls needed in expanded state

                  if (_groupByRole)
                    ...sortedDepts.map((dept) {
                      final worksInDept = groupedByDept[dept]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                dept.toUpperCase(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          _buildWorksList(worksInDept, dept),
                        ],
                      );
                    }).toList()
                  else
                    _buildChronologicalList(),
                    
                  // Show Less Button
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _isExpanded = false),
                      icon: const Icon(Icons.expand_less),
                      label: const Text('Show Less'),
                    ),
                  ),
                ] else ...[
                  // Collapsed State: First ~100px with fade-out gradient
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _isExpanded = true);
                        _scrollToTop();
                      },
                      child: Stack(
                        children: [
                          // Content with height constraint and gradient mask
                          // Wrapped in IgnorePointer so clicks pass through to the InkWell
                          IgnorePointer(
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Colors.white,
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 0.85, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 120),
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: _buildPreview(),
                                ),
                              ),
                            ),
                          ),
                          
                          // Show More button overlaid at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.expand_more, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Show all ${widget.works.length} credits',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChronologicalList({int? limit}) {
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
      children: sortedKeys.take(limit ?? sortedKeys.length).map((key) {
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
              ep.copyWith(
                title: combinedTitle,
                posterPath: work.posterPath, // Use show poster instead of episode still
              ),
              isEpisode: false, // Don't extract title again, show full combined title with poster
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
          
          debugPrint('[CreditExpansionSection] === SINGLE EPISODE CASE ===');
          debugPrint('[CreditExpansionSection] showTitle: "$showTitle"');
          debugPrint('[CreditExpansionSection] ep.title: "${ep.title}"');
          debugPrint('[CreditExpansionSection] ep.type: ${ep.type}');
          debugPrint('[CreditExpansionSection] ep.showId: ${ep.showId}');
          debugPrint('[CreditExpansionSection] ep.showName: "${ep.showName}"');
          debugPrint('[CreditExpansionSection] ep.seasonNumber: ${ep.seasonNumber}');
          debugPrint('[CreditExpansionSection] ep.episodeNumber: ${ep.episodeNumber}');
          debugPrint('[CreditExpansionSection] combinedTitle: "$combinedTitle"');
          
          final workToRender = ep.copyWith(title: combinedTitle);
          debugPrint('[CreditExpansionSection] workToRender.type: ${workToRender.type}');
          debugPrint('[CreditExpansionSection] workToRender.title: "${workToRender.title}"');
          debugPrint('[CreditExpansionSection] workToRender.showId: ${workToRender.showId}');
          debugPrint('[CreditExpansionSection] workToRender.showName: "${workToRender.showName}"');
          debugPrint('[CreditExpansionSection] Calling _buildWorkItem with isEpisode: true');
          
          renderedGroups.add(
            _buildWorkItem(
              workToRender,
              isEpisode: true,
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
    return _CreditWorkItem(
      work: work,
      isEpisode: isEpisode,
      children: children,
      currentDepartmentFilter: currentDepartmentFilter,
      hideRatings: widget.hideRatings,
      onWorkTap: widget.onWorkTap,
      onAddToWatchlist: widget.onAddToWatchlist,
    );
  }

  String _extractEpisodeTitle(String title) {
    final parts = title.split(' - ');
    if (parts.length >= 3) return parts.sublist(2).join(' - ');
    if (parts.length == 2) return parts[1];
    return title;
  }
}

class _CreditWorkItem extends StatefulWidget {
  final Work work;
  final bool isEpisode;
  final List<Widget>? children;
  final String? currentDepartmentFilter;
  final bool hideRatings;
  final Function(Work)? onWorkTap;
  final Function(Work)? onAddToWatchlist;

  const _CreditWorkItem({
    required this.work,
    this.isEpisode = false,
    this.children,
    this.currentDepartmentFilter,
    required this.hideRatings,
    this.onWorkTap,
    this.onAddToWatchlist,
  });

  @override
  State<_CreditWorkItem> createState() => _CreditWorkItemState();
}

class _CreditWorkItemState extends State<_CreditWorkItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final work = widget.work;
    final isEpisode = widget.isEpisode;
    final children = widget.children;
    final currentDepartmentFilter = widget.currentDepartmentFilter;

    if (work.title.contains('Interior Chinatown')) {
      debugPrint('[_CreditWorkItem] === INTERIOR CHINATOWN RENDER ===');
      debugPrint('[_CreditWorkItem] work.type: ${work.type}');
      debugPrint('[_CreditWorkItem] work.title: "${work.title}"');
      debugPrint('[_CreditWorkItem] isEpisode parameter: $isEpisode');
      debugPrint('[_CreditWorkItem] work.showId: ${work.showId}');
      debugPrint('[_CreditWorkItem] work.showName: "${work.showName}"');
      debugPrint('[_CreditWorkItem] work.seasonNumber: ${work.seasonNumber}');
      debugPrint('[_CreditWorkItem] work.episodeNumber: ${work.episodeNumber}');
    }

    // Logic to sort and filter roles
    List<String> rawRoles;
    if (currentDepartmentFilter != null) {
      rawRoles = work.contributorRoles
        .where((r) {
             if (currentDepartmentFilter == 'Cast' && (r.department == null || r.department!.isEmpty || r.role == 'Acting' || r.role == 'Cast')) return true;
             if (currentDepartmentFilter == 'Directing' && (r.role.contains('Director') || r.department == 'Directing')) return true;
             if (currentDepartmentFilter == 'Writing' && (r.role.contains('Writer') || r.department == 'Writing' || r.role.contains('Screenplay'))) return true;
             if (currentDepartmentFilter == 'Creator' && (r.role.contains('Creator') || r.role.contains('Created'))) return true;
             if (currentDepartmentFilter == 'Production' && (r.department == 'Production' || r.role.contains('Producer'))) return true;
             return (r.department == currentDepartmentFilter);
        })
        .map((r) => r.role)
        .toList();
    } else {
       rawRoles = work.contributorRoles.map((r) => r.role).toList();
    }
    
    rawRoles = rawRoles.where((r) => !['tv', 'movie', 'tv show', 'general'].contains(r.toLowerCase())).toList();
    
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
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: () {
              if (work.title.contains('Interior Chinatown')) {
                debugPrint('[_CreditWorkItem] === INTERIOR CHINATOWN TAP ===');
                debugPrint('[_CreditWorkItem] work.type: ${work.type}');
                debugPrint('[_CreditWorkItem] work.title: "${work.title}"');
                debugPrint('[_CreditWorkItem] isEpisode: $isEpisode');
                debugPrint('[_CreditWorkItem] work.showId: ${work.showId}');
                debugPrint('[_CreditWorkItem] work.showName: "${work.showName}"');
                debugPrint('[_CreditWorkItem] work.seasonNumber: ${work.seasonNumber}');
                debugPrint('[_CreditWorkItem] work.episodeNumber: ${work.episodeNumber}');
              }
              widget.onWorkTap?.call(work);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isEpisode ? 32 : 16,
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
                  else
                    SizedBox(
                      width: 32,
                      height: 48,
                      child: Stack(
                        children: [
                          if (work.posterPath != null)
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
                          
                          // Hover Mask + Center Watchlist Button using WatchlistButton component
                          if (widget.onAddToWatchlist != null)
                            WatchlistButton(
                              tmdbId: work.tmdbId,
                              workType: work.type,
                              workTitle: work.title,
                              posterPath: work.posterPath,
                              releaseDate: work.releaseDate,
                              releaseType: work.releaseType ?? ReleaseType.streaming,
                              position: WatchlistButtonStyle.center,
                              showOnHoverOnly: true,
                              iconSize: 20,
                              isHovered: _isHovered,
                            ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEpisode ? _extractEpisodeTitle(work.title) : work.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (work.releaseDate != null)
                          Text(
                            _formatDateRange(work),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
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
                ],
              ),
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
    if (work.type == WorkType.tvShow && work.endDate != null) {
      final endYear = DateFormat('yyyy').format(work.endDate!);
      if (startYear != endYear) {
        return '$startYear-$endYear';
      }
    }
    return startYear;
  }
}
