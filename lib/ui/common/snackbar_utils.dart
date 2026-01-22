import 'package:flutter/material.dart';
import '../../data/models/contributor.dart';
import 'adaptive_tooltip_text.dart';

/// Shows a simple snackbar with fade in/out animation.
/// Use this for basic messages throughout the app.
void showSimpleSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _SimpleSnackBarContent(
        message: message,
        duration: duration,
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
      ),
    ),
  );
}

void showSuccessSnackBar(
  BuildContext context, {
  required Contributor contributor,
  required List<String> roles,
  required List<String> availableRoles,
  required VoidCallback onChange,
  TvNotificationPreferences? tvNotificationPrefs,
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  String message;
  bool showChangeButton = false;
  Duration timerDuration = const Duration(seconds: 3);

  if (contributor.type == ContributorType.movie || contributor.type == ContributorType.company || contributor.type == ContributorType.collection) {
    message = "Following ${contributor.name}";
  } else if (contributor.type == ContributorType.tvShow && tvNotificationPrefs != null) {
    final List<String> activePrefs = [];
    if (tvNotificationPrefs.seriesPremiere) activePrefs.add('Series Premiere');
    if (tvNotificationPrefs.seasonPremieres) activePrefs.add('Season Premieres');
    if (tvNotificationPrefs.seasonFinales) activePrefs.add('Season Finales');
    if (tvNotificationPrefs.newEpisodes) activePrefs.add('New Episodes');
    if (tvNotificationPrefs.specials) activePrefs.add('Specials');
    
    final prefsString = activePrefs.join(', ');
    message = "Following ${contributor.name} for $prefsString";
    showChangeButton = true;
    timerDuration = const Duration(seconds: 4);
  } else {
    final bool isSingleRoleMatch = roles.length == 1 && availableRoles.length == 1;
    final roleString = roles.join(", ");
    final countString = isSingleRoleMatch ? "" : "(${roles.length}/${availableRoles.length} roles)";
    
    message = "Following ${contributor.name} as $roleString $countString".trim();
    showChangeButton = !isSingleRoleMatch;
    timerDuration = Duration(seconds: isSingleRoleMatch ? 3 : 4);
  }

  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _TimerSnackBarContent(
        message: message,
        duration: timerDuration,
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: showChangeButton ? 'CHANGE' : null,
        onAction: showChangeButton ? onChange : null,
      ),
    ),
  );
}

void showRemovalSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _TimerSnackBarContent(
        message: message,
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: 'UNDO',
        onAction: onUndo,
      ),
    ),
  );
}

void showAlreadyFollowedSnackBar(
  BuildContext context, {
  required String contributorName,
  required VoidCallback onUnfollow,
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _TimerSnackBarContent(
        message: '$contributorName already followed',
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: 'UNFOLLOW',
        onAction: onUnfollow,
      ),
    ),
  );
}

class _TimerSnackBarContent extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TimerSnackBarContent({
    required this.message,
    required this.duration,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_TimerSnackBarContent> createState() => _TimerSnackBarContentState();
}

class _TimerSnackBarContentState extends State<_TimerSnackBarContent> with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _fadeController;
  late AnimationController _timerBarFadeController;
  bool _isHovering = false;
  double _pausedAt = 0.0;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.0,
    );

    _timerBarFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );

    // Fade in
    _fadeController.forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismissSnackBar();
      }
    });

    _timerController.forward();
  }

  void _dismissSnackBar() {
    widget.onDismiss?.call();
    _fadeController.reverse().then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _fadeController.dispose();
    _timerBarFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? colorScheme.inverseSurface : colorScheme.inverseSurface;
    final textColor = isDark ? colorScheme.onInverseSurface : colorScheme.onInverseSurface;

    return FadeTransition(
      opacity: _fadeController,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _timerController.stop();
          _timerBarFadeController.reverse();
          _pausedAt = _timerController.value;
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _timerBarFadeController.forward();
          if (_timerController.status != AnimationStatus.completed) {
            // Add half of the used time back
            final timeToAdd = _pausedAt * 0.5;
            final newStart = (_pausedAt - timeToAdd).clamp(0.0, 1.0);
            _timerController.forward(from: newStart);
          }
        },
        child: Material(
          color: bgColor,
          elevation: 6,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer bar at the very top edge with fade animation
              AnimatedBuilder(
                animation: Listenable.merge([_timerController, _timerBarFadeController]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _timerBarFadeController,
                    child: SizedBox(
                      height: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _timerController.value,
                          child: Container(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Content row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: AdaptiveTooltipText(
                        widget.message,
                        maxLines: 2,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          widget.onAction?.call();
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.inversePrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ],
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


/// Simple snackbar content with just fade animation, no timer bar
// Watchlist-specific snackbar utilities

/// Shows snackbar when work is added to watchlist
void showAddedToWatchlistSnackBar(
  BuildContext context,
  String title, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  showSimpleSnackBar(
    context,
    '$title added to watchlist',
    duration: const Duration(seconds: 3),
    onSnackBarVisibilityChanged: onSnackBarVisibilityChanged,
  );
}

/// Shows snackbar when work is already in watchlist with REMOVE action
void showAlreadyInWatchlistSnackBar(
  BuildContext context,
  String title,
  VoidCallback onRemove, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _TimerSnackBarContent(
        message: '$title already in watchlist',
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: 'REMOVE',
        onAction: onRemove,
      ),
    ),
  );
}

/// Shows snackbar when work is removed from watchlist with UNDO action
void showRemovedFromWatchlistSnackBar(
  BuildContext context,
  String title,
  VoidCallback onUndo, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  showRemovalSnackBar(
    context,
    message: '$title removed from watchlist',
    onUndo: onUndo,
    onSnackBarVisibilityChanged: onSnackBarVisibilityChanged,
  );
}

/// Shows snackbar when status is changed
void showStatusChangedSnackBar(
  BuildContext context,
  String title,
  String statusSymbol,
  String statusText, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  showSimpleSnackBar(
    context,
    '$title marked as $statusSymbol $statusText',
    duration: const Duration(seconds: 3),
    onSnackBarVisibilityChanged: onSnackBarVisibilityChanged,
  );
}

/// Shows warning snackbar for unreleased content
void showUnreleasedWarningSnackBar(
  BuildContext context,
  String title, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _WarningSnackBarContent(
        message: '⚠️ $title hasn\'t been released yet',
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
      ),
    ),
  );
}

/// Shows snackbar when work is snoozed with UNDO action
void showSnoozedSnackBar(
  BuildContext context,
  String title,
  VoidCallback onUndo, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _TimerSnackBarContent(
        message: '$title frozen',
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: 'UNDO',
        onAction: onUndo,
      ),
    ),
  );
}

/// Shows dialog prompt when unmarking "Want to watch"
Future<String?> showWantToWatchUnmarkPrompt(
  BuildContext context,
  String title,
) async {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Which do you want to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('hide'),
            child: const Text('HIDE'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('DELETE'),
          ),
        ],
      );
    },
  );
}

/// Shows warning snackbar when reordering with filters active
void showDragReorderWarningSnackBar(
  BuildContext context,
  VoidCallback onShowAll, {
  Function(bool)? onSnackBarVisibilityChanged,
}) {
  onSnackBarVisibilityChanged?.call(true);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(hours: 1),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _WarningSnackBarContent(
        message: '⚠️ You have filters on. Reordering may jump over filtered items.',
        duration: const Duration(seconds: 4),
        onDismiss: () => onSnackBarVisibilityChanged?.call(false),
        actionLabel: 'Show all',
        onAction: onShowAll,
      ),
    ),
  );
}

class _SimpleSnackBarContent extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;

  const _SimpleSnackBarContent({
    required this.message,
    required this.duration,
    this.onDismiss,
  });

  @override
  State<_SimpleSnackBarContent> createState() => _SimpleSnackBarContentState();
}

class _SimpleSnackBarContentState extends State<_SimpleSnackBarContent> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.0,
    );

    // Fade in
    _fadeController.forward();

    // Schedule fade out and dismiss
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onDismiss?.call();
        _fadeController.reverse().then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = colorScheme.inverseSurface;
    final textColor = colorScheme.onInverseSurface;

    return FadeTransition(
      opacity: _fadeController,
      child: Material(
        color: bgColor,
        elevation: 6,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            widget.message,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }
}

/// Warning snackbar content with yellow/orange background
class _WarningSnackBarContent extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _WarningSnackBarContent({
    required this.message,
    required this.duration,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_WarningSnackBarContent> createState() => _WarningSnackBarContentState();
}

class _WarningSnackBarContentState extends State<_WarningSnackBarContent> with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _fadeController;
  late AnimationController _timerBarFadeController;
  bool _isHovering = false;
  double _pausedAt = 0.0;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.0,
    );

    _timerBarFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );

    // Fade in
    _fadeController.forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismissSnackBar();
      }
    });

    _timerController.forward();
  }

  void _dismissSnackBar() {
    widget.onDismiss?.call();
    _fadeController.reverse().then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _fadeController.dispose();
    _timerBarFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Warning colors: yellow/orange background
    final bgColor = isDark ? Colors.orange.shade900 : Colors.orange.shade100;
    final textColor = isDark ? Colors.orange.shade50 : Colors.orange.shade900;
    final timerBarColor = isDark ? Colors.orange.shade300 : Colors.orange.shade700;

    return FadeTransition(
      opacity: _fadeController,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _timerController.stop();
          _timerBarFadeController.reverse();
          _pausedAt = _timerController.value;
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _timerBarFadeController.forward();
          if (_timerController.status != AnimationStatus.completed) {
            // Add half of the used time back
            final timeToAdd = _pausedAt * 0.5;
            final newStart = (_pausedAt - timeToAdd).clamp(0.0, 1.0);
            _timerController.forward(from: newStart);
          }
        },
        child: Material(
          color: bgColor,
          elevation: 6,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer bar at the very top edge with fade animation
              AnimatedBuilder(
                animation: Listenable.merge([_timerController, _timerBarFadeController]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _timerBarFadeController,
                    child: SizedBox(
                      height: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _timerController.value,
                          child: Container(
                            color: timerBarColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Content row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: AdaptiveTooltipText(
                        widget.message,
                        maxLines: 2,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          widget.onAction?.call();
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ],
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
