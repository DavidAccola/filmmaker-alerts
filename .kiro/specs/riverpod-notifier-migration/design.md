# Design Document: Riverpod Notifier Migration

## Overview

This design document describes the technical approach for migrating the filmmaker_alerts Flutter application from Riverpod's legacy `StateProvider` pattern to the modern `Notifier`/`NotifierProvider` pattern. The migration is a straightforward refactoring that replaces 4 simple state providers with their Notifier equivalents while updating all consuming UI code.

The migration follows Riverpod 3 best practices for simple state management, using synchronous `Notifier` classes (not `AsyncNotifier`) since all 4 providers manage simple, synchronous UI state.

**Research Confirmation**: The official Riverpod documentation confirms that `StateProvider` should be migrated to `Notifier` with `NotifierProvider`. The manual declaration syntax is `NotifierProvider<NotifierClass, StateType>(NotifierClass.new)`, and the `build()` method returns the initial state value.

## Architecture

### Current Architecture (Before Migration)

```
┌─────────────────────────────────────────────────────────────┐
│                    providers.dart                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ import 'package:flutter_riverpod/legacy.dart';          ││
│  │                                                          ││
│  │ selectedTabProvider = StateProvider<int>((ref) => 0)    ││
│  │ homeTabProvider = StateProvider<int>((ref) => 0)        ││
│  │ watchlistScrollTargetProvider = StateProvider<int?>     ││
│  │ fabRaisedProvider = StateProvider<bool>((ref) => false) ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    UI Consumers                              │
│  Read:  ref.watch(provider)                                 │
│  Write: ref.read(provider.notifier).state = value           │
└─────────────────────────────────────────────────────────────┘
```

### Target Architecture (After Migration)

```
┌─────────────────────────────────────────────────────────────┐
│                    providers.dart                            │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ // No legacy import                                      ││
│  │                                                          ││
│  │ class SelectedTabNotifier extends Notifier<int>         ││
│  │ class HomeTabNotifier extends Notifier<int>             ││
│  │ class WatchlistScrollTargetNotifier extends Notifier    ││
│  │ class FabRaisedNotifier extends Notifier<bool>          ││
│  │                                                          ││
│  │ selectedTabProvider = NotifierProvider<...>             ││
│  │ homeTabProvider = NotifierProvider<...>                 ││
│  │ watchlistScrollTargetProvider = NotifierProvider<...>   ││
│  │ fabRaisedProvider = NotifierProvider<...>               ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    UI Consumers                              │
│  Read:  ref.watch(provider)           (unchanged)           │
│  Write: ref.read(provider.notifier).setTab(value)           │
│         ref.read(provider.notifier).setTarget(value)        │
│         ref.read(provider.notifier).setRaised(value)        │
│         ref.read(provider.notifier).clear()                 │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### Notifier Classes

Each Notifier class follows the same simple pattern for synchronous state management:

```dart
class ExampleNotifier extends Notifier<StateType> {
  @override
  StateType build() {
    return initialValue;
  }
  
  void updateMethod(StateType newValue) {
    state = newValue;
  }
}
```

### SelectedTabNotifier

Manages the main navigation tab index (0 = Home, 1 = History, 2 = Settings).

```dart
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void setTab(int index) {
    state = index;
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);
```

### HomeTabNotifier

Manages the home screen tab index (0 = People, 1 = Watchlist).

```dart
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void setTab(int index) {
    state = index;
  }
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);
```

### WatchlistScrollTargetNotifier

Manages the TMDB ID of a watchlist item to scroll to, or null if no scroll target.

```dart
class WatchlistScrollTargetNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  
  void setTarget(int? tmdbId) {
    state = tmdbId;
  }
  
  void clear() {
    state = null;
  }
}

final watchlistScrollTargetProvider = NotifierProvider<WatchlistScrollTargetNotifier, int?>(
  WatchlistScrollTargetNotifier.new,
);
```

### FabRaisedNotifier

Manages whether the FAB should be raised to accommodate snackbars.

```dart
class FabRaisedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setRaised(bool raised) {
    state = raised;
  }
}

final fabRaisedProvider = NotifierProvider<FabRaisedNotifier, bool>(
  FabRaisedNotifier.new,
);
```

### UI Consumer API Changes

The read pattern changes from direct state assignment to method calls:

| Before (Legacy) | After (Notifier) |
|-----------------|------------------|
| `ref.read(selectedTabProvider.notifier).state = 1` | `ref.read(selectedTabProvider.notifier).setTab(1)` |
| `ref.read(homeTabProvider.notifier).state = 1` | `ref.read(homeTabProvider.notifier).setTab(1)` |
| `ref.read(watchlistScrollTargetProvider.notifier).state = id` | `ref.read(watchlistScrollTargetProvider.notifier).setTarget(id)` |
| `ref.read(watchlistScrollTargetProvider.notifier).state = null` | `ref.read(watchlistScrollTargetProvider.notifier).clear()` |
| `ref.read(fabRaisedProvider.notifier).state = true` | `ref.read(fabRaisedProvider.notifier).setRaised(true)` |

The watch pattern remains unchanged:
- `ref.watch(selectedTabProvider)` → returns `int`
- `ref.watch(homeTabProvider)` → returns `int`
- `ref.watch(watchlistScrollTargetProvider)` → returns `int?`
- `ref.watch(fabRaisedProvider)` → returns `bool`

## Data Models

This migration does not introduce new data models. The state types remain unchanged:

| Provider | State Type | Initial Value |
|----------|------------|---------------|
| selectedTabProvider | `int` | `0` |
| homeTabProvider | `int` | `0` |
| watchlistScrollTargetProvider | `int?` | `null` |
| fabRaisedProvider | `bool` | `false` |

## Files Requiring Changes

### Provider Definition File
- `lib/providers/providers.dart` - Define 4 Notifier classes and update provider declarations

### UI Consumer Files
- `lib/main.dart` - Update selectedTabProvider usage
- `lib/ui/screens/main_screen.dart` - Update selectedTabProvider usage
- `lib/ui/screens/home_screen.dart` - Update homeTabProvider, watchlistScrollTargetProvider, fabRaisedProvider usage
- `lib/ui/screens/watchlist_screen.dart` - Update fabRaisedProvider usage
- `lib/ui/screens/search_results_screen.dart` - Update homeTabProvider, watchlistScrollTargetProvider usage
- `lib/ui/common/watchlist_button.dart` - Update homeTabProvider, watchlistScrollTargetProvider usage



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, most acceptance criteria in this migration are structural (code organization, API usage) rather than behavioral. These are verified through compilation and code review. However, the Notifier state mutation behavior can be tested as properties.

### Property 1: State Mutation Correctness

*For any* Notifier instance and *for any* valid state value, calling the state mutation method with that value SHALL result in the notifier's state being equal to the provided value.

**Validates: Requirements 2.2, 3.2, 4.2, 5.2**

This property covers:
- `SelectedTabNotifier.setTab(index)` → `state == index`
- `HomeTabNotifier.setTab(index)` → `state == index`
- `WatchlistScrollTargetNotifier.setTarget(tmdbId)` → `state == tmdbId`
- `FabRaisedNotifier.setRaised(raised)` → `state == raised`

### Property 2: Clear Method Resets to Null

*For any* `WatchlistScrollTargetNotifier` instance with *any* current state value, calling `clear()` SHALL result in the state being `null`.

**Validates: Requirements 4.3**

## Error Handling

This migration involves straightforward state management with no error conditions to handle:

1. **Type Safety**: Dart's type system ensures only valid types can be passed to state mutation methods
2. **Null Safety**: The `WatchlistScrollTargetNotifier` uses `int?` to explicitly handle the nullable case
3. **No Async Operations**: All notifiers are synchronous, eliminating async error handling concerns
4. **No External Dependencies**: The notifiers don't interact with external services or repositories

The migration preserves the existing error-free behavior of the StateProvider pattern.

## Testing Strategy

### Unit Tests

Unit tests should verify:

1. **Initial State Values** (Examples):
   - `SelectedTabNotifier.build()` returns `0`
   - `HomeTabNotifier.build()` returns `0`
   - `WatchlistScrollTargetNotifier.build()` returns `null`
   - `FabRaisedNotifier.build()` returns `false`

2. **State Mutation Methods** (Examples):
   - `setTab(2)` updates state to `2`
   - `setTarget(12345)` updates state to `12345`
   - `setRaised(true)` updates state to `true`
   - `clear()` resets state to `null`

### Property-Based Tests

Property-based tests should verify the correctness properties using the `flutter_test` package with custom generators:

1. **Property 1: State Mutation Correctness**
   - Generate random valid state values
   - Call mutation method with generated value
   - Assert state equals the provided value
   - **Feature: riverpod-notifier-migration, Property 1: State Mutation Correctness**

2. **Property 2: Clear Method Resets to Null**
   - Generate random initial state values for WatchlistScrollTargetNotifier
   - Set state to generated value
   - Call clear()
   - Assert state is null
   - **Feature: riverpod-notifier-migration, Property 2: Clear Method Resets to Null**

### Integration Verification

Since this is a refactoring migration, the primary verification is:

1. **Compilation Success**: The application compiles without errors after migration
2. **Manual Smoke Test**: Basic navigation and UI interactions work as expected

### Test Configuration

- Property-based tests should run minimum 100 iterations
- Use Dart's `Random` class for generating test values
- Test values for tab indices: 0-10 range (covers realistic navigation scenarios)
- Test values for TMDB IDs: positive integers in realistic range (1-999999)
