import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/work_sorting_logic.dart';
import 'adaptive_tooltip_text.dart';
import 'watchlist_button.dart';
import 'expand_poster_button.dart';

enum WatchlistButtonPosition {
  bottomRight,
  topLeft,
  topRight,
  center,
}

class WorkWidget extends StatefulWidget {
  final Work work;
  final bool hideRatings;
  final VoidCallback? onTap;
  final VoidCallback? onAddToWatchlist;
  final bool applyAgeStyling;
  final bool showDate;
  final bool showRating;
  final bool useShortDateFormat;
  final bool showDateInPoster;
  final bool showWatchlistOnHover;
  final WatchlistButtonPosition watchlistButtonPosition;
  final String? hoverTitle;
  final String? titleOverride; // Used to show Show Title instead of full Episode Title
  final bool useNewWatchlistButton; // Use the new WatchlistButton component
  final bool hideRoles; // Suppress role labels under the title
  final bool companyRoleFormat; // For company detail sections: hide "Production", parenthesize "Produced by X"

  const WorkWidget({
    super.key,
    required this.work,
    this.hideRatings = false,
    this.onTap,
    this.onAddToWatchlist,
    this.applyAgeStyling = false,
    this.showDate = true,
    this.showRating = true,
    this.useShortDateFormat = false,
    this.showDateInPoster = false,
    this.showWatchlistOnHover = false,
    this.watchlistButtonPosition = WatchlistButtonPosition.bottomRight,
    this.hoverTitle,
    this.titleOverride,
    this.useNewWatchlistButton = true,
    this.hideRoles = false,
    this.companyRoleFormat = false,
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
                child: Icon(Symbols.movie, size: 40),
              ),
            ),
          )
        : Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Symbols.movie, size: 40),
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
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
  
                    // Date or Rating in Bottom-Left
                    if ((widget.showDateInPoster && work.releaseDate != null) || (!widget.showDateInPoster && widget.showRating && !widget.hideRatings && work.tmdbRating != null && work.voteCount != null && work.voteCount! > 0))
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: widget.showDateInPoster 
                            ? Text(
                                _formatReleaseDate(work.releaseDate!),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              )
                            : Row(
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
                        child: Icon(
                          work.type == WorkType.movie ? Symbols.movie : Symbols.tv_gen,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Hover Overlay for Title
                    if (widget.hoverTitle != null)
                      AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.7),
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: Text(
                            widget.hoverTitle!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // Watchlist Button - using new WatchlistButton component
                    if (widget.useNewWatchlistButton)
                      WatchlistButton(
                        tmdbId: work.tmdbId,
                        workType: work.type,
                        workTitle: work.title,
                        posterPath: work.posterPath,
                        releaseDate: work.releaseDate,
                        releaseType: work.releaseType ?? ReleaseType.streaming,
                        position: widget.watchlistButtonPosition == WatchlistButtonPosition.topLeft
                            ? WatchlistButtonStyle.topLeft
                            : widget.watchlistButtonPosition == WatchlistButtonPosition.topRight
                                ? WatchlistButtonStyle.topRight
                                : widget.watchlistButtonPosition == WatchlistButtonPosition.center
                                    ? WatchlistButtonStyle.center
                                    : WatchlistButtonStyle.bottomRight,
                        showOnHoverOnly: widget.showWatchlistOnHover,
                        isHovered: _isHovered,
                      ),

                    // Expand Poster Button - appears in upper-left of poster
                    Positioned(
                      top: 4,
                      left: 4,
                      child: ExpandPosterButton(
                        posterPath: work.posterPath,
                        title: work.title,
                        isCardHovered: _isHovered,
                        iconSize: 20,
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
                        widget.titleOverride ?? work.title,
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
                              if (widget.showDate)
                                if (work.releaseDate != null)
                                  Text(
                                    _formatReleaseDate(work.releaseDate!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  )
                                else
                                  const Tooltip(
                                    message: 'To be announced',
                                    child: Text(
                                      'TBA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                        

                      ],
                    ),
                    
                    if (work.contributorRoles.isNotEmpty && !widget.hideRoles)
                      Builder(builder: (context) {
                        String roleText;
                        if (widget.companyRoleFormat) {
                          // For company detail sections (Upcoming/Latest/Biggest):
                          // 1st billed: show nothing
                          // Others: show "(Producer X of Y, Produced by Z)"
                          final producerLabel = WorkSortingLogic.getProducerLabel(work);
                          if (producerLabel == null) return const SizedBox.shrink(); // 1st billed
                          final producedByRole = work.contributorRoles
                              .map((r) => r.role)
                              .firstWhere((r) => r.startsWith('Produced by '), orElse: () => '');
                          if (producedByRole.isNotEmpty) {
                            roleText = '($producerLabel, $producedByRole)';
                          } else {
                            roleText = '($producerLabel)';
                          }
                        } else {
                          roleText = WorkSortingLogic.sortRoles(work.contributorRoles).map((r) => r.role).join(', ');
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: AdaptiveTooltipText(
                            roleText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                          ),
                        );
                      }),
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
    if (widget.useShortDateFormat) {
      return DateFormat('MM/dd/yyyy').format(date);
    }
    final now = DateTime.now();
    // Requirements:
    // > 3 years old: YYYY
    // 2-3 years old: MMM d, yyyy
    // This year: MMM d
    
    final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));
    if (date.isBefore(threeYearsAgo)) {
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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