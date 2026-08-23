# Tasks: Stale Connections Data on App Resume

## Task 1: Convert `_AppLifecycleWrapper` to `ConsumerStatefulWidget` and invalidate providers on resume
- [x] 1.1 In `lib/main.dart`, change `_AppLifecycleWrapper` from `StatefulWidget` to `ConsumerStatefulWidget` and `_AppLifecycleWrapperState` from `State<_AppLifecycleWrapper>` with `WidgetsBindingObserver` to `ConsumerState<_AppLifecycleWrapper>` with `WidgetsBindingObserver` (requirement 2.1)
- [x] 1.2 In `_AppLifecycleWrapperState.didChangeAppLifecycleState`, add `ref.invalidate(contributorsProvider)`, `ref.invalidate(watchlistEntriesProvider)`, and `ref.invalidate(connectionsDataProvider)` after the existing image cache clearing in the `AppLifecycleState.resumed` branch (requirements 2.1, 2.2)
- [x] 1.3 Verify the `paused` and `detached` branches are unchanged (requirement 3.4)
- [x] 1.4 Run `dart analyze lib/main.dart` to confirm no compile errors or warnings
