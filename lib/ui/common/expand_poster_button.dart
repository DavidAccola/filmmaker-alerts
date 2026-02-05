import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Button that appears on hover to expand poster to fullscreen
class ExpandPosterButton extends StatefulWidget {
  final String? posterPath;
  final String title;
  final bool isCardHovered;
  final double iconSize;

  const ExpandPosterButton({
    super.key,
    required this.posterPath,
    required this.title,
    required this.isCardHovered,
    this.iconSize = 20,
  });

  @override
  State<ExpandPosterButton> createState() => _ExpandPosterButtonState();
}

class _ExpandPosterButtonState extends State<ExpandPosterButton> {
  Timer? _hoverTimer;
  bool _showButton = false;

  @override
  void didUpdateWidget(ExpandPosterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCardHovered != oldWidget.isCardHovered) {
      if (widget.isCardHovered) {
        // Start timer when hover begins - 500ms (double the watchlist button delay)
        _hoverTimer = Timer(const Duration(milliseconds: 500), () {
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If already hovering when widget is built/updated, ensure button shows
    if (widget.isCardHovered && !_showButton) {
      _hoverTimer?.cancel();
      _hoverTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _showButton = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if there's no poster
    if (widget.posterPath == null || widget.posterPath!.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _showButton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_showButton,
        child: Tooltip(
          message: 'View full poster',
          waitDuration: Duration.zero,
          showDuration: const Duration(seconds: 3),
          child: Container(
            decoration: BoxDecoration(
              // Subtle dark background to ensure visibility on light posters
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              onPressed: () => _showFullscreenPoster(context),
              icon: Icon(
                Icons.fullscreen,
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
              iconSize: widget.iconSize,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: widget.iconSize + 8,
                minHeight: widget.iconSize + 8,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullscreenPoster(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => FullscreenPosterDialog(
        posterPath: widget.posterPath!,
        title: widget.title,
      ),
    );
  }
}


/// Fullscreen dialog to display poster at maximum resolution with zoom support
class FullscreenPosterDialog extends StatefulWidget {
  final String posterPath;
  final String title;

  const FullscreenPosterDialog({
    super.key,
    required this.posterPath,
    required this.title,
  });

  @override
  State<FullscreenPosterDialog> createState() => _FullscreenPosterDialogState();
}

class _FullscreenPosterDialogState extends State<FullscreenPosterDialog> {
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;
  static const double _zoomScale = 2.5;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    final position = details.localPosition;
    
    if (_isZoomed) {
      // Zoom out - animate back to identity
      _animateToMatrix(Matrix4.identity());
      setState(() => _isZoomed = false);
    } else {
      // Zoom in - center on tap position
      final matrix = Matrix4.identity()
        ..setEntry(0, 3, -position.dx * (_zoomScale - 1))
        ..setEntry(1, 3, -position.dy * (_zoomScale - 1))
        ..setEntry(0, 0, _zoomScale)
        ..setEntry(1, 1, _zoomScale)
        ..setEntry(2, 2, _zoomScale);
      _animateToMatrix(matrix);
      setState(() => _isZoomed = true);
    }
  }

  void _animateToMatrix(Matrix4 target) {
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 200),
    );
    
    final startMatrix = _transformationController.value.clone();
    final animation = Matrix4Tween(begin: startMatrix, end: target).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
    
    animation.addListener(() {
      _transformationController.value = animation.value;
    });
    
    controller.forward().then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    // Use original resolution for fullscreen view
    final highResUrl = 'https://image.tmdb.org/t/p/original${widget.posterPath}';
    // SystemMouseCursors.zoomIn/zoomOut don't work on Windows (Flutter issue #99323)
    // Use different cursors to indicate zoom state:
    // - When not zoomed: use 'click' to indicate clickable
    // - When zoomed: use 'move' to indicate you can pan, or click to zoom out
    final cursor = _isZoomed ? SystemMouseCursors.move : SystemMouseCursors.click;
    
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled; // Consume the event to prevent propagation
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Barrier to close dialog when clicking outside the poster
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Poster image with zoom/pan support
            MouseRegion(
              cursor: cursor,
              child: GestureDetector(
                onTapDown: _toggleZoom,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 32,
                    maxHeight: MediaQuery.of(context).size.height - 32,
                  ),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 3.5,
                    onInteractionEnd: (details) {
                      // Update zoom state based on current scale
                      final scale = _transformationController.value.getMaxScaleOnAxis();
                      setState(() => _isZoomed = scale > 1.1);
                    },
                    child: CachedNetworkImage(
                      imageUrl: highResUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        width: 300,
                        height: 450,
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 300,
                        height: 450,
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Close button in top-right corner
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            
            // Title at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
