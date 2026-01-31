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
);
```

### For removal/undo messages:
Use `showRemovalSnackBar()`:
```dart
showRemovalSnackBar(
  context,
  message: 'Removed ${contributor.name}',
  onUndo: () { /* handle undo */ },
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
- ✅ Fixed positioning at bottom edge (doesn't interfere with FAB)

## DO NOT use:
- ❌ `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`
- ❌ Direct SnackBar widgets
- ❌ Any snackbar implementation that doesn't use the custom functions

## Import statement:
Always include this import in files that show snackbars:
```dart
import '../common/snackbar_utils.dart';
```
