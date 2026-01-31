# Requirements Document

## Introduction

This document specifies the requirements for migrating the filmmaker_alerts Flutter application from Riverpod's legacy StateProvider pattern to the modern Notifier/NotifierProvider pattern introduced in Riverpod 3. The migration involves converting 4 UI state providers while maintaining existing functionality and ensuring the application compiles and runs correctly.

## Glossary

- **StateProvider**: Legacy Riverpod provider pattern for simple mutable state, accessed via `ref.read(provider.notifier).state = value`
- **Notifier**: Modern Riverpod 3 class-based pattern for state management with explicit state mutation methods
- **NotifierProvider**: Provider that exposes a Notifier instance and its state
- **Provider_File**: The file `lib/providers/providers.dart` containing all provider definitions
- **UI_Consumer**: Any widget or screen that reads or writes provider state using `ref.watch()` or `ref.read()`

## Requirements

### Requirement 1: Remove Legacy Import

**User Story:** As a developer, I want to remove the legacy Riverpod import, so that the codebase uses only modern Riverpod 3 APIs.

#### Acceptance Criteria

1. WHEN the migration is complete, THE Provider_File SHALL NOT contain the import `package:flutter_riverpod/legacy.dart`
2. THE Provider_File SHALL only import `package:flutter_riverpod/flutter_riverpod.dart`

### Requirement 2: Migrate selectedTabProvider

**User Story:** As a developer, I want to convert selectedTabProvider to use the Notifier pattern, so that main navigation tab state follows Riverpod 3 best practices.

#### Acceptance Criteria

1. THE Provider_File SHALL define a `SelectedTabNotifier` class extending `Notifier<int>` with initial state of 0
2. THE SelectedTabNotifier SHALL expose a `setTab(int index)` method to update the selected tab
3. THE Provider_File SHALL define `selectedTabProvider` as a `NotifierProvider<SelectedTabNotifier, int>`
4. WHEN a UI_Consumer reads the selected tab, THE UI_Consumer SHALL use `ref.watch(selectedTabProvider)` to get the current value
5. WHEN a UI_Consumer updates the selected tab, THE UI_Consumer SHALL use `ref.read(selectedTabProvider.notifier).setTab(index)`

### Requirement 3: Migrate homeTabProvider

**User Story:** As a developer, I want to convert homeTabProvider to use the Notifier pattern, so that home screen tab state (People/Watchlist) follows Riverpod 3 best practices.

#### Acceptance Criteria

1. THE Provider_File SHALL define a `HomeTabNotifier` class extending `Notifier<int>` with initial state of 0
2. THE HomeTabNotifier SHALL expose a `setTab(int index)` method to update the home tab
3. THE Provider_File SHALL define `homeTabProvider` as a `NotifierProvider<HomeTabNotifier, int>`
4. WHEN a UI_Consumer reads the home tab, THE UI_Consumer SHALL use `ref.watch(homeTabProvider)` to get the current value
5. WHEN a UI_Consumer updates the home tab, THE UI_Consumer SHALL use `ref.read(homeTabProvider.notifier).setTab(index)`

### Requirement 4: Migrate watchlistScrollTargetProvider

**User Story:** As a developer, I want to convert watchlistScrollTargetProvider to use the Notifier pattern, so that watchlist scroll targeting follows Riverpod 3 best practices.

#### Acceptance Criteria

1. THE Provider_File SHALL define a `WatchlistScrollTargetNotifier` class extending `Notifier<int?>` with initial state of null
2. THE WatchlistScrollTargetNotifier SHALL expose a `setTarget(int? tmdbId)` method to set the scroll target
3. THE WatchlistScrollTargetNotifier SHALL expose a `clear()` method to reset the target to null
4. THE Provider_File SHALL define `watchlistScrollTargetProvider` as a `NotifierProvider<WatchlistScrollTargetNotifier, int?>`
5. WHEN a UI_Consumer reads the scroll target, THE UI_Consumer SHALL use `ref.watch(watchlistScrollTargetProvider)` to get the current value
6. WHEN a UI_Consumer sets a scroll target, THE UI_Consumer SHALL use `ref.read(watchlistScrollTargetProvider.notifier).setTarget(tmdbId)`
7. WHEN a UI_Consumer clears the scroll target, THE UI_Consumer SHALL use `ref.read(watchlistScrollTargetProvider.notifier).clear()`

### Requirement 5: Migrate fabRaisedProvider

**User Story:** As a developer, I want to convert fabRaisedProvider to use the Notifier pattern, so that FAB visibility state follows Riverpod 3 best practices.

#### Acceptance Criteria

1. THE Provider_File SHALL define a `FabRaisedNotifier` class extending `Notifier<bool>` with initial state of false
2. THE FabRaisedNotifier SHALL expose a `setRaised(bool raised)` method to update the FAB raised state
3. THE Provider_File SHALL define `fabRaisedProvider` as a `NotifierProvider<FabRaisedNotifier, bool>`
4. WHEN a UI_Consumer reads the FAB raised state, THE UI_Consumer SHALL use `ref.watch(fabRaisedProvider)` to get the current value
5. WHEN a UI_Consumer updates the FAB raised state, THE UI_Consumer SHALL use `ref.read(fabRaisedProvider.notifier).setRaised(raised)`

### Requirement 6: Update All UI Consumers

**User Story:** As a developer, I want all UI files to use the new Notifier API, so that the migration is complete and consistent.

#### Acceptance Criteria

1. WHEN the migration is complete, THE main_screen.dart SHALL use the new selectedTabProvider Notifier API
2. WHEN the migration is complete, THE home_screen.dart SHALL use the new homeTabProvider, watchlistScrollTargetProvider, and fabRaisedProvider Notifier APIs
3. WHEN the migration is complete, THE watchlist_screen.dart SHALL use the new fabRaisedProvider Notifier API
4. WHEN the migration is complete, THE search_results_screen.dart SHALL use the new homeTabProvider and watchlistScrollTargetProvider Notifier APIs
5. WHEN the migration is complete, THE watchlist_button.dart SHALL use the new homeTabProvider and watchlistScrollTargetProvider Notifier APIs
6. WHEN the migration is complete, THE main.dart SHALL use the new selectedTabProvider Notifier API

### Requirement 7: Maintain Application Functionality

**User Story:** As a user, I want the application to work exactly as before after the migration, so that my experience is unchanged.

#### Acceptance Criteria

1. WHEN the migration is complete, THE application SHALL compile without errors
2. WHEN the migration is complete, THE main navigation tabs SHALL function identically to before
3. WHEN the migration is complete, THE home screen tab switching (People/Watchlist) SHALL function identically to before
4. WHEN the migration is complete, THE watchlist scroll-to-item feature SHALL function identically to before
5. WHEN the migration is complete, THE FAB repositioning for snackbars SHALL function identically to before
