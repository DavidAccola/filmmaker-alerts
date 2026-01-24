import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor_detail.dart';
import '../../providers/providers.dart';
import 'snackbar_utils.dart';
import '../screens/home_screen.dart';
import 'hover_action_button.dart';

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
  final bool? isHovered; // Optional: parent can pass hover state
  final VoidCallback? onUndo; // Callback for undo action
  final VoidCallback? onView; // Callback for view action (navigate to watchlist)
  final bool showViewButton; // Whether to show View button (true for non-search screens)
  final bool applyPositioning; // Whether to apply internal Positioned wrapper (false when parent handles positioning)

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
    this.isHovered,
    this.onUndo,
    this.onView,
    this.showViewButton = true,
    this.applyPositioning = true, // Default to true for backward compatibility
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

    return watchlistAsync.when(
      data: (entries) {
        final isInWatchlist = entries.any((e) =>
            e.tmdbId == widget.tmdbId && e.type == widget.workType);

        final shouldShow = widget.showOnHoverOnly ? (widget.isHovered ?? false) : true;
        
        final button = HoverActionButton(
          onPressed: _isLoading ? () {} : () => _handleWatchlistToggle(isInWatchlist),
          icon: isInWatchlist ? Icons.check_circle : Icons.add_circle,
          tooltip: isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
          iconSize: widget.iconSize,
          isCardHovered: shouldShow,
        );

        return _positionButton(button);
      },
      loading: () => SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _positionButton(Widget button) {
    // If parent is handling positioning, just return the button
    if (!widget.applyPositioning) {
      return button;
    }
    
    // Otherwise apply internal positioning (for backward compatibility)
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
          // Determine if we should show the View button
          final shouldShowView = widget.showViewButton;
          
          // Use new watchlist snackbar with undo and optional view
          showWatchlistSnackBar(
            context,
            message: '${widget.workTitle} added to watchlist',
            onUndo: () async {
              await watchlistLogic.removeWorkFromWatchlist(
                widget.tmdbId,
                widget.workType,
              );
              ref.invalidate(watchlistEntriesProvider);
            },
            onView: shouldShowView ? (widget.onView ?? _defaultViewAction) : null,
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

  void _defaultViewAction() {
    // Default view action: navigate to watchlist tab and scroll to item
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          initialTabIndex: 1,
          scrollToWatchlistItem: widget.tmdbId,
        ),
      ),
    );
  }
}
