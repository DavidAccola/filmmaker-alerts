import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/watchlist_entry.dart';
import '../../providers/providers.dart';
import 'snackbar_utils.dart';

enum WatchlistButtonStyle {
  topRight,    // Top right corner (default)
  topLeft,     // Top left corner
  center,      // Centered (for TV credits)
  bottomRight, // Bottom right corner
}

class WatchlistButton extends ConsumerStatefulWidget {
  final int tmdbId;
  final WorkType workType;
  final String workTitle;
  final String? posterPath;
  final DateTime? releaseDate;
  final ReleaseType releaseType;
  final WatchlistButtonStyle position;
  final bool showOnHoverOnly;
  final double iconSize;
  final VoidCallback? onAdded;

  const WatchlistButton({
    super.key,
    required this.tmdbId,
    required this.workType,
    required this.workTitle,
    this.posterPath,
    this.releaseDate,
    this.releaseType = ReleaseType.streaming,
    this.position = WatchlistButtonStyle.topRight,
    this.showOnHoverOnly = true,
    this.iconSize = 24,
    this.onAdded,
  });

  @override
  ConsumerState<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends ConsumerState<WatchlistButton> {
  bool _isHovered = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistEntriesProvider);
    final theme = Theme.of(context);

    return watchlistAsync.when(
      data: (entries) {
        final isInWatchlist = entries.any((e) =>
            e.tmdbId == widget.tmdbId && e.type == widget.workType);

        final shouldShow = !widget.showOnHoverOnly || _isHovered;

        if (widget.showOnHoverOnly && !shouldShow) {
          return const SizedBox.shrink();
        }

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: _buildButton(
            context,
            isInWatchlist,
            theme,
          ),
        );
      },
      loading: () => SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildButton(BuildContext context, bool isInWatchlist, ThemeData theme) {
    final button = AnimatedOpacity(
      opacity: (_isHovered || !widget.showOnHoverOnly) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        onPressed: _isLoading ? null : () => _handleWatchlistToggle(isInWatchlist),
        icon: Icon(
          isInWatchlist ? Icons.check_circle : Icons.add_circle,
          color: theme.colorScheme.primary,
        ),
        iconSize: widget.iconSize,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.iconSize + 8,
          minHeight: widget.iconSize + 8,
        ),
        tooltip: isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
        ),
      ),
    );

    // Position the button based on style
    switch (widget.position) {
      case WatchlistButtonStyle.topRight:
        return Positioned(
          top: 8,
          right: 8,
          child: button,
        );
      case WatchlistButtonStyle.topLeft:
        return Positioned(
          top: 8,
          left: 8,
          child: button,
        );
      case WatchlistButtonStyle.center:
        return Center(child: button);
      case WatchlistButtonStyle.bottomRight:
        return Positioned(
          bottom: 8,
          right: 8,
          child: button,
        );
    }
  }

  Future<void> _handleWatchlistToggle(bool isInWatchlist) async {
    setState(() => _isLoading = true);

    try {
      final watchlistLogic = ref.read(watchlistLogicProvider);

      if (isInWatchlist) {
        // Remove from watchlist
        await watchlistLogic.removeWorkFromWatchlist(
          widget.tmdbId,
          widget.workType,
        );

        if (mounted) {
          showSimpleSnackBar(
            context,
            '${widget.workTitle} removed from watchlist',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Add to watchlist
        await watchlistLogic.addWorkToWatchlist(
          tmdbId: widget.tmdbId,
          type: widget.workType,
          title: widget.workTitle,
          posterPath: widget.posterPath,
          releaseDate: widget.releaseDate,
          releaseType: widget.releaseType,
        );

        if (mounted) {
          showSimpleSnackBar(
            context,
            '${widget.workTitle} added to watchlist',
            duration: const Duration(seconds: 3),
          );
        }
      }

      ref.invalidate(watchlistEntriesProvider);
      widget.onAdded?.call();
    } catch (e) {
      if (mounted) {
        showSimpleSnackBar(
          context,
          'Failed to update watchlist: $e',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
