import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/contributor.dart';
import '../common/adaptive_tooltip_text.dart';
import '../common/snackbar_utils.dart';

class ContributorCard extends StatefulWidget {
  final Contributor contributor;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback? onEditRoles;

  const ContributorCard({
    super.key,
    required this.contributor,
    required this.onTap,
    required this.onRemove,
    this.onEditRoles,
  });

  @override
  State<ContributorCard> createState() => _ContributorCardState();
}

class _ContributorCardState extends State<ContributorCard> {
  bool _showLatestPoster = false;
  bool _isHovered = false;
  int _keyCounter = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestWork = widget.contributor.latestWork;

    // Default to Profile, but show Poster when hovering "Latest" info (only for people)
    final isPerson = widget.contributor.type == ContributorType.person;
    final mainImagePath = (isPerson && _showLatestPoster && latestWork?.posterPath != null)
        ? latestWork!.posterPath
        : widget.contributor.profilePath;

    String formatDate(String dateStr) {
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('MMMM d, yyyy').format(date).replaceAll(' ', '\u00A0');
      } catch (_) {
        return dateStr;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        elevation: _isHovered ? 8 : 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate width available for text (Card width - Image width - Paddings)
            // Image width is 90, Padding is 12*2 = 24. Total = 114
            final textColumnWidth = (constraints.maxWidth - 114).clamp(0.0, double.infinity);
            
            // On small screens (list mode, not grid mode), put "Latest:" on its own line
            final screenWidth = MediaQuery.of(context).size.width;
            final isSmallScreen = screenWidth < 600;

            // Prepare for smart wrapping measurement
            Widget? latestWorkWidget;
            if (latestWork != null) {
              const textStyle = TextStyle(fontSize: 12);
              final latestLabelStyle = TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              );
              const titleStyle = TextStyle(fontWeight: FontWeight.w600);
              final dateStyle = TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              );

              // NEW: Differentiated layout for Movies vs People vs TV Shows
              final isMovie = widget.contributor.type == ContributorType.movie || widget.contributor.type == ContributorType.collection;
              final isTvShow = widget.contributor.type == ContributorType.tvShow;

              if (isMovie) {
                // MOVIE LAYOUT: Similar to the legacy Electron app
                final origDate = latestWork.originalReleaseDate;
                final latestDate = latestWork.latestReleaseDate;
                final origType = latestWork.originalReleaseType;
                final latestType = latestWork.latestReleaseType;

                List<Widget> releaseLines = [];

                if (origDate != null && latestDate != null && origDate != latestDate) {
                  releaseLines.add(
                    AdaptiveTooltipText.rich(
                      customTooltip: '${origType ?? 'Original'}: ${formatDate(origDate)}',
                      maxWidth: textColumnWidth,
                      TextSpan(
                        style: dateStyle,
                        children: [
                          TextSpan(
                            text: '${origType ?? 'Original'}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: formatDate(origDate)),
                        ],
                      ),
                    ),
                  );
                  releaseLines.add(
                    AdaptiveTooltipText.rich(
                      customTooltip: '${latestType ?? 'Latest'}: ${formatDate(latestDate)}',
                      maxWidth: textColumnWidth,
                      TextSpan(
                        style: dateStyle,
                        children: [
                          TextSpan(
                            text: '${latestType ?? 'Latest'}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: formatDate(latestDate)),
                        ],
                      ),
                    ),
                  );
                } else if (latestDate != null) {
                  releaseLines.add(
                    AdaptiveTooltipText.rich(
                      customTooltip: '${latestType ?? 'Release'}: ${formatDate(latestDate)}',
                      maxWidth: textColumnWidth,
                      TextSpan(
                        style: dateStyle,
                        children: [
                          TextSpan(
                            text: '${latestType ?? 'Release'}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: formatDate(latestDate)),
                        ],
                      ),
                    ),
                  );
                } else {
                  releaseLines.add(
                    AdaptiveTooltipText.rich(
                      customTooltip: 'Release: ${formatDate(latestWork.releaseDate)}',
                      maxWidth: textColumnWidth,
                      TextSpan(
                        style: dateStyle,
                        children: [
                          const TextSpan(text: 'Release: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: formatDate(latestWork.releaseDate)),
                        ],
                      ),
                    ),
                  );
                }

                latestWorkWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: releaseLines,
                );
              } else if (isTvShow) {
                // TV SHOW LAYOUT: Latest: Episode Name - S#E# (Date)
                final formattedDate = formatDate(latestWork.releaseDate);
                
                if (isSmallScreen) {
                  // On small screens, put "Latest:" on its own line
                  latestWorkWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(text: 'Latest:', style: latestLabelStyle.copyWith(fontSize: 12))),
                      AdaptiveTooltipText(
                        latestWork.title,
                        style: titleStyle.copyWith(fontSize: 12),
                        maxWidth: textColumnWidth,
                      ),
                      if (formattedDate.isNotEmpty)
                        Text.rich(TextSpan(text: '($formattedDate)', style: dateStyle)),
                    ],
                  );
                } else {
                  final titleSpan = TextSpan(
                    style: textStyle,
                    children: [
                      TextSpan(text: 'Latest: ', style: latestLabelStyle),
                      TextSpan(text: latestWork.title, style: titleStyle),
                    ],
                  );

                  final detailsSpan = TextSpan(
                    style: dateStyle,
                    children: [
                      if (formattedDate.isNotEmpty)
                        TextSpan(text: '($formattedDate)'),
                    ],
                  );

                  // Try a single line first
                  final fullRichSpan = TextSpan(
                    style: textStyle,
                    children: [
                      titleSpan,
                      const TextSpan(text: ' '),
                      detailsSpan,
                    ],
                  );

                  final tp = TextPainter(
                    text: fullRichSpan,
                    maxLines: 1,
                    textDirection: ui.TextDirection.ltr,
                  )..layout(maxWidth: textColumnWidth);

                  if (tp.didExceedMaxLines) {
                    // Split into two lines
                    latestWorkWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdaptiveTooltipText.rich(
                          titleSpan,
                          customTooltip: latestWork.title,
                          maxWidth: textColumnWidth,
                        ),
                        AdaptiveTooltipText.rich(
                          detailsSpan,
                          maxWidth: textColumnWidth,
                        ),
                      ],
                    );
                  } else {
                    latestWorkWidget = AdaptiveTooltipText.rich(
                      fullRichSpan,
                      customTooltip: '${latestWork.title} (${formatDate(latestWork.releaseDate)})',
                      maxWidth: textColumnWidth,
                    );
                  }
                }
              } else {
                // PERSON LAYOUT: Latest: Title (Date)
                final formattedDate = formatDate(latestWork.releaseDate);
                final jobOrDept = latestWork.job ?? latestWork.department;
                
                if (isSmallScreen) {
                  // On small screens, put "Latest:" on its own line
                  latestWorkWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(text: 'Latest:', style: latestLabelStyle.copyWith(fontSize: 12))),
                      AdaptiveTooltipText(
                        latestWork.title,
                        style: titleStyle.copyWith(fontSize: 12),
                        maxWidth: textColumnWidth,
                      ),
                      if (formattedDate.isNotEmpty || jobOrDept.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            style: dateStyle,
                            children: [
                              if (formattedDate.isNotEmpty)
                                TextSpan(text: '($formattedDate)'),
                              if (formattedDate.isNotEmpty && jobOrDept.isNotEmpty)
                                const TextSpan(text: ' - '),
                              if (jobOrDept.isNotEmpty)
                                TextSpan(
                                  text: jobOrDept,
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                } else {
                  final titleSpan = TextSpan(
                    style: textStyle,
                    children: [
                      TextSpan(text: 'Latest: ', style: latestLabelStyle),
                      TextSpan(text: latestWork.title, style: titleStyle),
                    ],
                  );

                  final detailsSpan = TextSpan(
                    style: dateStyle,
                    children: [
                      if (formattedDate.isNotEmpty)
                        TextSpan(text: '($formattedDate)'),
                      if (formattedDate.isNotEmpty && jobOrDept.isNotEmpty)
                        const TextSpan(text: ' - '),
                      if (jobOrDept.isNotEmpty)
                        TextSpan(
                          text: jobOrDept,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  );

                  // We try a single line first
                  final fullRichSpan = TextSpan(
                    style: textStyle,
                    children: [
                      titleSpan,
                      const TextSpan(text: ' '),
                      detailsSpan,
                    ],
                  );

                  // Use TextPainter to handle the split decision instead of LayoutBuilder
                  final tp = TextPainter(
                    text: fullRichSpan,
                    maxLines: 1,
                    textDirection: ui.TextDirection.ltr,
                  )..layout(maxWidth: textColumnWidth);

                  if (tp.didExceedMaxLines) {
                    // Split into two lines
                    latestWorkWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdaptiveTooltipText.rich(
                          titleSpan,
                          customTooltip: latestWork.title,
                          maxWidth: textColumnWidth,
                        ),
                        AdaptiveTooltipText.rich(
                          detailsSpan,
                          maxWidth: textColumnWidth,
                        ),
                      ],
                    );
                  } else {
                    latestWorkWidget = AdaptiveTooltipText.rich(
                      fullRichSpan,
                      customTooltip: '${latestWork.title} (${formatDate(latestWork.releaseDate)})',
                      maxWidth: textColumnWidth,
                    );
                  }
                }
              }
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster/Profile Image
                  SizedBox(
                    width: 90,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            key: ValueKey('${widget.contributor.tmdbId}_${mainImagePath ?? 'placeholder'}_$_keyCounter'),
                            width: 90,
                            height: double.infinity,
                            color: widget.contributor.type == ContributorType.company 
                                ? (theme.brightness == Brightness.dark ? Colors.grey[300] : Colors.white)
                                : theme.colorScheme.surfaceContainerHighest, // Background for 'contain' fit
                            child: mainImagePath != null
                                ? Padding(
                                    padding: widget.contributor.type == ContributorType.company 
                                        ? const EdgeInsets.symmetric(horizontal: 8)
                                        : EdgeInsets.zero,
                                    child: CachedNetworkImage(
                                      imageUrl: 'https://image.tmdb.org/t/p/w200$mainImagePath',
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => Shimmer.fromColors(
                                        baseColor: theme.colorScheme.surfaceContainerHighest,
                                        highlightColor: theme.colorScheme.surface,
                                        child: Container(
                                          color: theme.colorScheme.surface,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.person, size: 30),
                                  ),
                          ),
                        ),
                        // Notification snooze indicator (upper-left)
                        if (widget.contributor.notificationsSnoozed)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.notifications_off,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Main Info Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AdaptiveTooltipText(
                                      widget.contributor.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                      maxWidth: textColumnWidth - 48,
                                    ),
                                    if (widget.contributor.knownFor.isNotEmpty && 
                                        widget.contributor.type != ContributorType.movie && 
                                        widget.contributor.type != ContributorType.collection &&
                                        widget.contributor.type != ContributorType.company)
                                      AdaptiveTooltipText(
                                        widget.contributor.knownFor,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          letterSpacing: 0,
                                        ),
                                        maxWidth: textColumnWidth - 48,
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'toggle_notifications') {
                                    widget.contributor.notificationsSnoozed = !widget.contributor.notificationsSnoozed;
                                    widget.contributor.save();
                                    setState(() {});
                                    
                                    final message = widget.contributor.notificationsSnoozed
                                        ? 'Notifications paused for ${widget.contributor.name}'
                                        : 'Notifications resumed for ${widget.contributor.name}';
                                    showSimpleSnackBar(context, message);
                                  } else if (value == 'remove') {
                                    widget.onRemove();
                                  } else if (value == 'edit_roles') {
                                    widget.onEditRoles?.call();
                                  } else if (value == 'edit_tv_prefs') {
                                    widget.onEditRoles?.call();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle_notifications',
                                    child: Text(widget.contributor.notificationsSnoozed ? 'Resume Notifications' : 'Pause Notifications'),
                                  ),
                                  if (widget.contributor.type == ContributorType.person)
                                    const PopupMenuItem(
                                      value: 'edit_roles',
                                      child: Text('Edit Roles'),
                                    ),
                                  if (widget.contributor.type == ContributorType.tvShow)
                                    const PopupMenuItem(
                                      value: 'edit_tv_prefs',
                                      child: Text('Edit TV Preferences'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (latestWork != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Divider(height: 1),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 40),
                              child: MouseRegion(
                                onEnter: (_) {
                                  // Only enable poster switching for people, not movies/TV shows
                                  if (isPerson && !_showLatestPoster && widget.contributor.latestWork?.posterPath != null) {
                                    setState(() {
                                      _showLatestPoster = true;
                                      _keyCounter++;
                                    });
                                  }
                                },
                                onExit: (_) {
                                  if (isPerson && _showLatestPoster) {
                                    setState(() {
                                      _showLatestPoster = false;
                                      _keyCounter++;
                                    });
                                  }
                                },
                                child: Container(
                                  color: Colors.transparent, // Background to ensure hit testing on blank areas
                                  alignment: Alignment.topLeft,
                                  child: latestWorkWidget!,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}
