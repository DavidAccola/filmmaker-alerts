import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adaptive_tooltip_text.dart';
import '../../providers/providers.dart';

class ContributorHoverCard extends ConsumerStatefulWidget {
  final int tmdbId;
  final String name;
  final String? profilePath;
  final String subtitle;
  final String? character;
  final bool isFollowed;
  final VoidCallback onTap;
  final VoidCallback onFollow;
  final double width;

  const ContributorHoverCard({
    super.key,
    required this.tmdbId,
    required this.name,
    this.profilePath,
    required this.subtitle,
    this.character,
    required this.isFollowed,
    required this.onTap,
    required this.onFollow,
    this.width = 100, // Reduced from 120 to match "Size from TV" preference closer
  });

  @override
  ConsumerState<ContributorHoverCard> createState() => _ContributorHoverCardState();
}

class _ContributorHoverCardState extends ConsumerState<ContributorHoverCard> {
  bool _isHovered = false;
  Timer? _hoverTimer;
  bool _showButton = false;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    setState(() => _isHovered = isHovered);
    
    if (isHovered) {
      // Start timer when hover begins
      _hoverTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _showButton = true);
        }
      });
    } else {
      // Cancel timer and hide immediately when hover ends
      _hoverTimer?.cancel();
      setState(() => _showButton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check follow status in real-time from the repository
    final contributorsAsync = ref.watch(contributorsProvider);
    final isActuallyFollowed = contributorsAsync.maybeWhen(
      data: (contributors) => contributors.any((c) => c.tmdbId == widget.tmdbId),
      orElse: () => widget.isFollowed,
    );
    
    
    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile image
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: widget.profilePath != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w200${widget.profilePath}',
                                fit: BoxFit.cover,
                              errorWidget: (ctx, url, err) => const Icon(Icons.person, size: 40),
                              ),
                            )
                          : const Center(child: Icon(Icons.person, size: 40)),
                    ),
                    
                    // Follow/Checkmark button in upper-right corner
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: (_showButton || isActuallyFollowed) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !_showButton && !isActuallyFollowed,
                          child: Tooltip(
                            message: (_showButton || isActuallyFollowed) ? (isActuallyFollowed ? 'Followed' : 'Follow') : '',
                            waitDuration: Duration.zero, // Show immediately once button is visible
                            child: IconButton(
                              icon: Icon(
                                isActuallyFollowed ? Icons.check_circle : Icons.add_circle,
                                size: 20,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                widget.onFollow();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Name and subtitle
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptiveTooltipText(
                      widget.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 11, // Slightly smaller font for compact feel
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    AdaptiveTooltipText(
                      widget.subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                    ),
                    if (widget.character != null && widget.character!.isNotEmpty && widget.character != widget.subtitle)
                       AdaptiveTooltipText(
                        widget.character!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        maxLines: 1,
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
}
