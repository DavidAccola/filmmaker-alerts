import 'package:flutter/material.dart';
import '../../data/models/contributor.dart';
import '../../core/constants.dart';
import 'adaptive_tooltip_text.dart';

void showSuccessSnackBar(
  BuildContext context, {
  required Contributor contributor,
  required List<String> roles,
  required List<String> availableRoles,
  required VoidCallback onChange,
}) {
  // For movies and companies, show a simple "Following [name]" message
  // For people, show the detailed role information
  String message;
  bool showChangeButton = false;
  Duration timerDuration = const Duration(seconds: 3);

  if (contributor.type == ContributorType.movie || contributor.type == ContributorType.company) {
    // Movies and companies get simple follow message
    message = "Following ${contributor.name}";
  } else {
    // Detailed role message for people
    final bool isSingleRoleMatch = roles.length == 1 && availableRoles.length == 1;
    final roleString = roles.join(", ");
    final countString = isSingleRoleMatch ? "" : "(${roles.length}/${availableRoles.length} roles)";
    
    message = "Following ${contributor.name} as $roleString $countString".trim();
    showChangeButton = !isSingleRoleMatch;
    timerDuration = Duration(seconds: isSingleRoleMatch ? 3 : 4);
  }
  
  // We set a long duration for the SnackBar itself so it doesn't auto-dismiss.
  // The lifecycle is completely controlled by our _TimerSnackBarContent widget.
  const snackBarDuration = Duration(hours: 1);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: snackBarDuration,
      content: _TimerSnackBarContent(message: message, duration: timerDuration),
      action: showChangeButton 
          ? SnackBarAction(
              label: 'CHANGE',
              onPressed: onChange,
            )
          : null,
    ),
  );
}

void showRemovalSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  const snackBarDuration = Duration(hours: 1);
  const timerDuration = Duration(seconds: 4);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: snackBarDuration,
      content: _TimerSnackBarContent(message: message, duration: timerDuration),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: onUndo,
      ),
    ),
  );
}

class _TimerSnackBarContent extends StatefulWidget {
  final String message;
  final Duration duration;

  const _TimerSnackBarContent({
    required this.message,
    required this.duration,
  });

  @override
  State<_TimerSnackBarContent> createState() => _TimerSnackBarContentState();
}

class _TimerSnackBarContentState extends State<_TimerSnackBarContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Trigger a standard dismissal (animated)
        ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _controller.stop();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _controller.forward();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveTooltipText(
            widget.message,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: _isHovering ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0 - _controller.value, // Counts down from full to empty
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    ),
                    minHeight: 4, 
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
