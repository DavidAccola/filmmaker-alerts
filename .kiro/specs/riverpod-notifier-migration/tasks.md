# Implementation Plan: Riverpod Notifier Migration

## Overview

This plan migrates 4 StateProviders to the modern Notifier/NotifierProvider pattern, updates all UI consumers, and removes the legacy import. Tasks are ordered to ensure incremental progress with early validation.

## Tasks

- [x] 1. Create Notifier classes in providers.dart
  - [x] 1.1 Create SelectedTabNotifier class
    - Define class extending `Notifier<int>` with `build()` returning 0
    - Add `setTab(int index)` method
    - _Requirements: 2.1, 2.2_
  
  - [x] 1.2 Create HomeTabNotifier class
    - Define class extending `Notifier<int>` with `build()` returning 0
    - Add `setTab(int index)` method
    - _Requirements: 3.1, 3.2_
  
  - [x] 1.3 Create WatchlistScrollTargetNotifier class
    - Define class extending `Notifier<int?>` with `build()` returning null
    - Add `setTarget(int? tmdbId)` method
    - Add `clear()` method
    - _Requirements: 4.1, 4.2, 4.3_
  
  - [x] 1.4 Create FabRaisedNotifier class
    - Define class extending `Notifier<bool>` with `build()` returning false
    - Add `setRaised(bool raised)` method
    - _Requirements: 5.1, 5.2_

- [x] 2. Replace StateProvider declarations with NotifierProvider
  - [x] 2.1 Replace selectedTabProvider declaration
    - Change from `StateProvider<int>` to `NotifierProvider<SelectedTabNotifier, int>`
    - Use `SelectedTabNotifier.new` constructor reference
    - _Requirements: 2.3_
  
  - [x] 2.2 Replace homeTabProvider declaration
    - Change from `StateProvider<int>` to `NotifierProvider<HomeTabNotifier, int>`
    - Use `HomeTabNotifier.new` constructor reference
    - _Requirements: 3.3_
  
  - [x] 2.3 Replace watchlistScrollTargetProvider declaration
    - Change from `StateProvider<int?>` to `NotifierProvider<WatchlistScrollTargetNotifier, int?>`
    - Use `WatchlistScrollTargetNotifier.new` constructor reference
    - _Requirements: 4.4_
  
  - [x] 2.4 Replace fabRaisedProvider declaration
    - Change from `StateProvider<bool>` to `NotifierProvider<FabRaisedNotifier, bool>`
    - Use `FabRaisedNotifier.new` constructor reference
    - _Requirements: 5.3_
  
  - [x] 2.5 Remove legacy import
    - Delete `import 'package:flutter_riverpod/legacy.dart';`
    - _Requirements: 1.1, 1.2_

- [x] 3. Checkpoint - Verify providers compile
  - Ensure providers.dart compiles without errors before updating UI consumers
  - Run `flutter analyze` to check for issues

- [x] 4. Update UI consumers - main navigation
  - [x] 4.1 Update main.dart
    - Change `ref.read(selectedTabProvider.notifier).state = 1` to `ref.read(selectedTabProvider.notifier).setTab(1)`
    - _Requirements: 6.6_
  
  - [x] 4.2 Update main_screen.dart
    - Change `ref.read(selectedTabProvider.notifier).state = index` to `ref.read(selectedTabProvider.notifier).setTab(index)`
    - Keep `ref.watch(selectedTabProvider)` unchanged
    - _Requirements: 6.1_

- [x] 5. Update UI consumers - home screen
  - [x] 5.1 Update home_screen.dart homeTabProvider usage
    - Change `ref.read(homeTabProvider.notifier).state = index` to `ref.read(homeTabProvider.notifier).setTab(index)`
    - Keep `ref.watch(homeTabProvider)` unchanged
    - _Requirements: 6.2_
  
  - [x] 5.2 Update home_screen.dart watchlistScrollTargetProvider usage
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = id` to `ref.read(watchlistScrollTargetProvider.notifier).setTarget(id)`
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = null` to `ref.read(watchlistScrollTargetProvider.notifier).clear()`
    - Keep `ref.watch(watchlistScrollTargetProvider)` unchanged
    - _Requirements: 6.2_
  
  - [x] 5.3 Update home_screen.dart fabRaisedProvider usage
    - Change `ref.read(fabRaisedProvider.notifier).state = raised` to `ref.read(fabRaisedProvider.notifier).setRaised(raised)`
    - Keep `ref.watch(fabRaisedProvider)` unchanged
    - _Requirements: 6.2_

- [x] 6. Update UI consumers - other screens
  - [x] 6.1 Update watchlist_screen.dart
    - Change `ref.read(fabRaisedProvider.notifier).state = raised` to `ref.read(fabRaisedProvider.notifier).setRaised(raised)`
    - _Requirements: 6.3_
  
  - [x] 6.2 Update search_results_screen.dart
    - Change `ref.read(homeTabProvider.notifier).state = 1` to `ref.read(homeTabProvider.notifier).setTab(1)`
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = id` to `ref.read(watchlistScrollTargetProvider.notifier).setTarget(id)`
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = null` to `ref.read(watchlistScrollTargetProvider.notifier).clear()`
    - _Requirements: 6.4_
  
  - [x] 6.3 Update watchlist_button.dart
    - Change `ref.read(homeTabProvider.notifier).state = 1` to `ref.read(homeTabProvider.notifier).setTab(1)`
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = id` to `ref.read(watchlistScrollTargetProvider.notifier).setTarget(id)`
    - Change `ref.read(watchlistScrollTargetProvider.notifier).state = null` to `ref.read(watchlistScrollTargetProvider.notifier).clear()`
    - _Requirements: 6.5_

- [x] 7. Final checkpoint - Verify full compilation
  - Run `flutter analyze` to ensure no errors or warnings
  - Run `flutter build` to verify the app compiles successfully
  - _Requirements: 7.1_

- [x] 8. Write property tests for Notifier classes
  - [x] 8.1 Write property test for state mutation correctness
    - **Property 1: State Mutation Correctness**
    - Test that for any valid state value, calling mutation method results in state equaling that value
    - Cover all 4 notifiers: SelectedTabNotifier, HomeTabNotifier, WatchlistScrollTargetNotifier, FabRaisedNotifier
    - **Validates: Requirements 2.2, 3.2, 4.2, 5.2**
  
  - [x] 8.2 Write property test for clear method
    - **Property 2: Clear Method Resets to Null**
    - Test that for any WatchlistScrollTargetNotifier state, calling clear() results in null state
    - **Validates: Requirements 4.3**

## Notes

- All tasks are required for comprehensive validation
- The `ref.watch()` calls remain unchanged - only `ref.read().notifier` mutations need updating
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation before proceeding
