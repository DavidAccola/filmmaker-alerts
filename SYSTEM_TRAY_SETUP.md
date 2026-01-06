# System Tray Setup for Windows

This document explains how the system tray functionality works on Windows.

## Overview

The Windows version of Filmmaker Alerts now supports running in the system tray. When you close the window, the app minimizes to the system tray instead of exiting completely. You can click the tray icon to show the window again.

## Features

- **Minimize to Tray**: Closing the window minimizes the app to the system tray
- **Tray Icon**: Click the tray icon to show/hide the window
- **Context Menu**: Right-click the tray icon for a context menu with Show/Exit options
- **Background Notifications**: The app continues to receive notifications while minimized

## Implementation Details

### Dependencies Used

- **tray_manager: ^0.2.0** - Handles system tray icon and context menu
- **window_manager: ^0.3.0** - Manages window show/hide/focus operations

### Files Modified/Created

1. **pubspec.yaml**
   - Added `tray_manager: ^0.2.0` and `window_manager: ^0.3.0` dependencies

2. **lib/data/services/system_tray_service.dart** (REWRITTEN)
   - Uses `tray_manager` and `window_manager` APIs
   - Implements `TrayListener` for handling tray events
   - Manages tray icon, tooltip, and context menu
   - Handles window show/hide operations

3. **lib/providers/providers.dart**
   - Added `systemTrayServiceProvider` for dependency injection

4. **lib/main.dart**
   - Initializes `window_manager` with proper window options
   - Initializes system tray service on Windows startup

5. **lib/ui/screens/main_screen.dart**
   - Added `PopScope` to intercept window close events
   - Routes close events to minimize-to-tray on Windows

### How It Works

1. **Window Manager Initialization**: `window_manager` is initialized in `main()` with window options
2. **Tray Initialization**: `SystemTrayService.init()` creates the tray icon and context menu
3. **Event Handling**: The service implements `TrayListener` to handle tray icon clicks and menu selections
4. **Window Close**: `PopScope` in `main_screen.dart` intercepts close events and calls `minimizeToTray()`
5. **Tray Interactions**:
   - Left-click tray icon: Shows and focuses the window
   - Right-click tray icon: Shows context menu
   - "Show Window" menu item: Shows and focuses the window
   - "Exit" menu item: Closes the application

## Asset Requirements

The system tray uses an icon from `assets/images/app_icon.png`. This file should exist in your assets folder.

## Building for Windows

To build the Windows app with system tray support:

```bash
flutter build windows
```

The built executable will be located at:
```
build/windows/runner/Release/filmmaker_alerts.exe
```

## Testing

To test the system tray functionality:

1. Run the app: `flutter run -d windows`
2. Close the window - it should minimize to the tray
3. Click the tray icon to show the window again
4. Right-click the tray icon to see the context menu
5. Select "Exit" from the menu to close the app

## Troubleshooting

### Tray icon not appearing
- Check debug logs for initialization errors
- Ensure `assets/images/app_icon.png` exists
- Verify the app is running on Windows

### Window not showing when clicking tray icon
- Check the debug logs for window manager errors
- Try right-clicking the tray icon and selecting "Show Window"
- Ensure `window_manager` initialized successfully

### App not minimizing to tray
- Verify you're running on Windows
- Check that `PopScope` is properly wrapping the main content
- Look for errors in the debug console related to `SystemTrayService`

## Debug Logging

The system tray service provides detailed debug logging:
- `[SystemTray] Initializing tray manager...` - Initialization started
- `[SystemTray] System tray initialized successfully` - Initialization completed
- `[SystemTray] Tray icon clicked` - User clicked tray icon
- `[SystemTray] Menu item clicked: [key]` - User selected menu item
- `[SystemTray] Window minimized to tray` - Window hidden
- `[SystemTray] Window restored from tray` - Window shown

## Future Enhancements

Possible improvements:
- Add notification badge to tray icon showing pending notifications
- Add quick actions to tray context menu (e.g., "Check Now")
- Add settings option to disable minimize-to-tray behavior
- Add keyboard shortcuts for window operations
- Add tray icon animation for active notifications
