import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ShelfWithArrows extends StatefulWidget {
  final Widget Function(BuildContext, ScrollController) builder;
  final double height;

  const ShelfWithArrows({super.key, required this.builder, required this.height});

  @override
  State<ShelfWithArrows> createState() => _ShelfWithArrowsState();
}

class _ShelfWithArrowsState extends State<ShelfWithArrows> {
  final ScrollController _controller = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListener();
    });
    _controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_controller.hasClients) return;
    if (mounted) {
      setState(() {
        _showLeftArrow = _controller.offset > 10;
        _showRightArrow = _controller.offset < _controller.position.maxScrollExtent - 10;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scroll(double direction) {
    if (_controller.hasClients) {
      final double screenWidth = MediaQuery.of(context).size.width;
      final double scrollAmount = screenWidth * 0.8; // Scroll 80% of screen width
      final double targetOffset = _controller.offset + (direction * scrollAmount);
      
      _controller.animateTo(
        targetOffset.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            child: widget.builder(context, _controller),
          ),

          // Left Arrow
          if (_showLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  height: 60,
                  width: 45,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
                      onTap: () => _scroll(-1),
                      child: Icon(
                        Icons.chevron_left, 
                        color: theme.colorScheme.primary, 
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Right Arrow
          if (_showRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  height: 60,
                  width: 45,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
                      onTap: () => _scroll(1),
                      child: Icon(
                        Icons.chevron_right, 
                        color: theme.colorScheme.primary, 
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
