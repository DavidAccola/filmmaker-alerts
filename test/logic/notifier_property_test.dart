import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filmmaker_alerts/providers/providers.dart';

/// Property-based tests for Riverpod Notifier classes.
///
/// These tests verify correctness properties across many random inputs
/// to ensure the Notifier implementations behave correctly for all valid values.
void main() {
  const int iterations = 100;
  final random = Random();

  group('Property 1: State Mutation Correctness', () {
    /// **Validates: Requirements 2.2, 3.2, 4.2, 5.2**
    ///
    /// For any Notifier instance and for any valid state value,
    /// calling the state mutation method with that value SHALL result
    /// in the notifier's state being equal to the provided value.

    test('SelectedTabNotifier.setTab(index) results in state == index', () {
      /// **Validates: Requirements 2.2**
      for (int i = 0; i < iterations; i++) {
        // Generate random tab index in range 0-10 (covers realistic navigation scenarios)
        final index = random.nextInt(11);

        // Create a fresh container for each iteration
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Get the notifier and call setTab
        final notifier = container.read(selectedTabProvider.notifier);
        notifier.setTab(index);

        // Verify state equals the provided value
        final state = container.read(selectedTabProvider);
        expect(
          state,
          equals(index),
          reason: 'Iteration $i: setTab($index) should result in state == $index, but got $state',
        );
      }
    });

    test('HomeTabNotifier.setTab(index) results in state == index', () {
      /// **Validates: Requirements 3.2**
      for (int i = 0; i < iterations; i++) {
        // Generate random tab index in range 0-10 (covers realistic navigation scenarios)
        final index = random.nextInt(11);

        // Create a fresh container for each iteration
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Get the notifier and call setTab
        final notifier = container.read(homeTabProvider.notifier);
        notifier.setTab(index);

        // Verify state equals the provided value
        final state = container.read(homeTabProvider);
        expect(
          state,
          equals(index),
          reason: 'Iteration $i: setTab($index) should result in state == $index, but got $state',
        );
      }
    });

    test('WatchlistScrollTargetNotifier.setTarget(tmdbId) results in state == tmdbId', () {
      /// **Validates: Requirements 4.2**
      for (int i = 0; i < iterations; i++) {
        // Generate random TMDB ID in realistic range (1-999999)
        // Also test null values (50% chance)
        final int? tmdbId = random.nextBool() ? random.nextInt(999999) + 1 : null;

        // Create a fresh container for each iteration
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Get the notifier and call setTarget
        final notifier = container.read(watchlistScrollTargetProvider.notifier);
        notifier.setTarget(tmdbId);

        // Verify state equals the provided value
        final state = container.read(watchlistScrollTargetProvider);
        expect(
          state,
          equals(tmdbId),
          reason: 'Iteration $i: setTarget($tmdbId) should result in state == $tmdbId, but got $state',
        );
      }
    });

    test('FabRaisedNotifier.setRaised(raised) results in state == raised', () {
      /// **Validates: Requirements 5.2**
      for (int i = 0; i < iterations; i++) {
        // Generate random boolean value
        final raised = random.nextBool();

        // Create a fresh container for each iteration
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Get the notifier and call setRaised
        final notifier = container.read(fabRaisedProvider.notifier);
        notifier.setRaised(raised);

        // Verify state equals the provided value
        final state = container.read(fabRaisedProvider);
        expect(
          state,
          equals(raised),
          reason: 'Iteration $i: setRaised($raised) should result in state == $raised, but got $state',
        );
      }
    });
  });

  group('Property 2: Clear Method Resets to Null', () {
    /// **Validates: Requirements 4.3**
    ///
    /// For any WatchlistScrollTargetNotifier instance with any current state value,
    /// calling clear() SHALL result in the state being null.

    test('WatchlistScrollTargetNotifier.clear() results in state == null', () {
      /// **Validates: Requirements 4.3**
      for (int i = 0; i < iterations; i++) {
        // Generate random initial TMDB ID in realistic range (1-999999)
        // Also test starting from null state (25% chance)
        final int? initialTmdbId = random.nextInt(4) == 0 ? null : random.nextInt(999999) + 1;

        // Create a fresh container for each iteration
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Get the notifier and set initial state
        final notifier = container.read(watchlistScrollTargetProvider.notifier);
        notifier.setTarget(initialTmdbId);

        // Call clear()
        notifier.clear();

        // Verify state is null
        final state = container.read(watchlistScrollTargetProvider);
        expect(
          state,
          isNull,
          reason: 'Iteration $i: clear() after setTarget($initialTmdbId) should result in state == null, but got $state',
        );
      }
    });
  });
}
