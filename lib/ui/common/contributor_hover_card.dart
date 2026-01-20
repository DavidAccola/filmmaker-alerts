import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'adaptive_tooltip_text.dart';

class ContributorHoverCard extends StatefulWidget {
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
  State<ContributorHoverCard> createState() => _ContributorHoverCardState();
}

class _ContributorHoverCardState extends State<ContributorHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: widget.isFollowed
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
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
                                errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
                              ),
                            )
                          : const Center(child: Icon(Icons.person, size: 40)),
                    ),
                    
                    // Follow/Checkmark button in upper-right corner
                    Positioned(
                      top: 4,
                      right: 4,
                      child: widget.isFollowed
                          ? Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.check,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                size: 28,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: widget.onFollow,
                              tooltip: 'Follow',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
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
                        fontWeight: widget.isFollowed ? FontWeight.bold : FontWeight.w500,
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
