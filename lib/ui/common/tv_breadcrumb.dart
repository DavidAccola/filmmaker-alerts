import 'package:flutter/material.dart';

/// Represents a single item in the breadcrumb navigation
class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final bool isClickable;

  BreadcrumbItem({
    required this.label,
    this.onTap,
    this.isClickable = false,
  });
}

/// Reusable breadcrumb widget for TV show navigation with intelligent truncation
class TvBreadcrumb extends StatefulWidget {
  final List<BreadcrumbItem> items;
  final double maxWidth;
  final TextStyle? textStyle;
  final Color? primaryColor;
  final Color? defaultColor;
  final Color? delimiterColor;

  const TvBreadcrumb({
    super.key,
    required this.items,
    required this.maxWidth,
    this.textStyle,
    this.primaryColor,
    this.defaultColor,
    this.delimiterColor,
  });

  @override
  State<TvBreadcrumb> createState() => _TvBreadcrumbState();
}

class _TvBreadcrumbState extends State<TvBreadcrumb> {
  late int _truncationLevel;
  final Map<String, double> _textWidthCache = {};

  @override
  void initState() {
    super.initState();
    _truncationLevel = _getTruncationLevel();
  }

  @override
  void didUpdateWidget(TvBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.items != widget.items) {
      _truncationLevel = _getTruncationLevel();
    }
  }

  /// Measures text width using TextPainter
  double _measureTextWidth(String text, TextStyle style) {
    if (_textWidthCache.containsKey(text)) {
      return _textWidthCache[text]!;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final width = textPainter.width;
    _textWidthCache[text] = width;
    return width;
  }

  /// Determines which truncation level to apply based on available width
  int _getTruncationLevel() {
    final style = widget.textStyle ?? const TextStyle();
    
    // Try each truncation level in order
    for (int level = 0; level <= 4; level++) {
      final text = _buildBreadcrumbText(level);
      final width = _measureTextWidth(text, style);
      
      // Add padding for safety (20 pixels)
      if (width + 20 <= widget.maxWidth) {
        return level;
      }
    }
    
    // If all levels exceed width, use maximum truncation
    return 4;
  }

  /// Constructs the breadcrumb string for the given truncation level
  String _buildBreadcrumbText(int level) {
    if (widget.items.isEmpty) return '';

    switch (level) {
      case 0:
        // Primary format: full labels
        return widget.items.map((item) => item.label).join(' > ');
      
      case 1:
        // Level 1: abbreviated labels (S# instead of Season #, E# instead of Episode #)
        return widget.items.map((item) {
          if (item.label.startsWith('Season ')) {
            final num = item.label.replaceFirst('Season ', '');
            return 'S$num';
          } else if (item.label.startsWith('Series ')) {
            final num = item.label.replaceFirst('Series ', '');
            return 'S$num';
          } else if (item.label.startsWith('Episode ')) {
            final parts = item.label.split(':');
            final num = parts[0].replaceFirst('Episode ', '').trim();
            return 'E$num';
          }
          return item.label;
        }).join(' > ');
      
      case 2:
        // Level 2: further abbreviated (omit episode name)
        return widget.items.map((item) {
          if (item.label.startsWith('Season ')) {
            final num = item.label.replaceFirst('Season ', '');
            return 'S$num';
          } else if (item.label.startsWith('Series ')) {
            final num = item.label.replaceFirst('Series ', '');
            return 'S$num';
          } else if (item.label.startsWith('Episode ')) {
            final parts = item.label.split(':');
            final num = parts[0].replaceFirst('Episode ', '').trim();
            return 'E$num';
          }
          return item.label;
        }).join(' > ');
      
      case 3:
        // Level 3: omit episode name entirely
        final filtered = widget.items.where((item) {
          return !item.label.startsWith('Episode ');
        }).toList();
        
        return filtered.map((item) {
          if (item.label.startsWith('Season ')) {
            final num = item.label.replaceFirst('Season ', '');
            return 'S$num';
          } else if (item.label.startsWith('Series ')) {
            final num = item.label.replaceFirst('Series ', '');
            return 'S$num';
          }
          return item.label;
        }).join(' > ');
      
      case 4:
      default:
        // Level 4: truncate show name with ellipsis
        final filtered = widget.items.where((item) {
          return !item.label.startsWith('Episode ');
        }).toList();
        
        if (filtered.isEmpty) return '';
        
        final showName = filtered[0].label;
        final truncatedShow = _truncateShowName(showName);
        
        final rest = filtered.skip(1).map((item) {
          if (item.label.startsWith('Season ')) {
            final num = item.label.replaceFirst('Season ', '');
            return 'S$num';
          } else if (item.label.startsWith('Series ')) {
            final num = item.label.replaceFirst('Series ', '');
            return 'S$num';
          }
          return item.label;
        }).toList();
        
        return [truncatedShow, ...rest].join(' > ');
    }
  }

  /// Truncates show name to fit within available width
  String _truncateShowName(String showName) {
    if (showName.length <= 10) return showName;
    
    // Binary search for the right truncation point
    int left = 1;
    int right = showName.length - 1;
    String result = showName.substring(0, 10) + '...';
    
    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final candidate = showName.substring(0, mid) + '...';
      
      if (candidate.length <= 15) {
        result = candidate;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    
    return result;
  }

  /// Builds the interactive breadcrumb widget with tap handlers
  Widget _buildBreadcrumbWidget() {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
    final defaultColor = widget.defaultColor ?? theme.colorScheme.onSurface;
    final delimiterColor = widget.delimiterColor ?? theme.colorScheme.onSurfaceVariant;
    final style = widget.textStyle ?? theme.textTheme.titleMedium;

    final breadcrumbText = _buildBreadcrumbText(_truncationLevel);
    final parts = breadcrumbText.split(' > ');
    
    final widgets = <Widget>[];
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final item = widget.items[i];
      
      if (item.isClickable && item.onTap != null) {
        widgets.add(
          InkWell(
            onTap: () {
              try {
                item.onTap!();
              } catch (e) {
                debugPrint('Error in breadcrumb navigation: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigation error')),
                  );
                }
              }
            },
            child: Text(
              part,
              style: style?.copyWith(color: primaryColor) ??
                  TextStyle(color: primaryColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } else {
        widgets.add(
          Text(
            part,
            style: style?.copyWith(color: defaultColor) ??
                TextStyle(color: defaultColor),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
      
      if (i < parts.length - 1) {
        widgets.add(
          Text(
            ' > ',
            style: style?.copyWith(color: delimiterColor) ??
                TextStyle(color: delimiterColor),
          ),
        );
      }
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widgets,
        mainAxisSize: MainAxisSize.min,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBreadcrumbWidget();
  }
}
