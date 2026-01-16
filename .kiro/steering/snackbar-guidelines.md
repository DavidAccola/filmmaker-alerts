# Snackbar Guidelines

## Rule: Always use custom snackbar functions with fade animations

All snackbars in this project must use the custom functions from `lib/ui/common/snackbar_utils.dart` to ensure consistent fade in/out animations and styling.

### For simple messages (errors, confirmations, status updates):
Use `showSimpleSnackBar()`:
```dart
import '../common/snackbar_utils.dart';

showSimpleSnackBar(context, 'Your message here');
// Optional: specify duration (default is 2 seconds)
showSimpleSnackBar(context, 'Message', duration: const Duration(seconds: 3));
```

### For simple messages with FAB repositioning (in screens with FloatingActionButton):
Use `showSimpleSnackBar()` with the `onSnackBarVisibilityChanged` callback:
```dart
showSimpleSnackBar(
  context,
  'Your message here',
  onSnackBarVisibilityChanged: (isVisible) {
    setState(() {
      _fabBottomPadding = isVisible ? 70.0 : 0.0;
    });
  },
);
```

### For success messages when following contributors:
Use `showSuccessSnackBar()`:
```dart
showSuccessSnackBar(
  context,
  contributor: contributor,
  roles: selectedRoles,
  availableRoles: allRoles,
  onChange: () { /* handle role change */ },
  tvNotificationPrefs: tvPrefs, // optional, for TV shows
  onSnackBarVisibilityChanged: (isVisible) { /* handle FAB animation */ }, // optional
);
```

### For removal/undo messages:
Use `showRemovalSnackBar()`:
```dart
showRemovalSnackBar(
  context,
  message: 'Removed ${contributor.name}',
  onUndo: () { /* handle undo */ },
  onSnackBarVisibilityChanged: (isVisible) { /* handle FAB animation */ }, // optional
);
```

## Features of custom snackbars:
- ✅ Fade in animation (250ms) when appearing
- ✅ Fade out animation (250ms) when dismissing
- ✅ 4px timer bar at the top (for timed snackbars)
- ✅ Timer bar fades in/out when paused/resumed (on hover)
- ✅ Timer bar hides completely when paused
- ✅ Hover adds half the used time back
- ✅ Consistent Material design styling
- ✅ Proper color theming (dark/light mode)

## FAB Repositioning Pattern:
When a screen has a FloatingActionButton that should move up to avoid snackbars:

1. Add a state variable to track FAB padding:
```dart
double _fabBottomPadding = 0.0;
```

2. Wrap the FAB with AnimatedPadding and AnimatedOpacity:
```dart
floatingActionButton: AnimatedOpacity(
  opacity: _fabBottomPadding > 0 ? 0.7 : 1.0,
  duration: const Duration(milliseconds: 200),
  child: AnimatedPadding(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    padding: EdgeInsets.only(bottom: _fabBottomPadding),
    child: FloatingActionButton(
      // ... FAB content
    ),
  ),
),
```

3. Pass the callback to all snackbars shown from that screen:
```dart
showSimpleSnackBar(
  context,
  'Message',
  onSnackBarVisibilityChanged: (isVisible) {
    setState(() {
      _fabBottomPadding = isVisible ? 70.0 : 0.0;
    });
  },
);
```

## DO NOT use:
- ❌ `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`
- ❌ Direct SnackBar widgets
- ❌ Any snackbar implementation that doesn't use the custom functions

## Import statement:
Always include this import in files that show snackbars:
```dart
import '../common/snackbar_utils.dart';
```
