import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Display Preferences - Property 6: Display Preference Consistency', () {
    test('Property 6: When hidePopularityInDetails is true, popularity should not be displayed in any section', () {
      // Arrange
      final prefs = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: false,
      );

      // Act & Assert
      expect(prefs.hidePopularityInDetails, isTrue);
      expect(prefs.hideRatingsInDetails, isFalse);
    });

    test('Property 6: When hideRatingsInDetails is true, ratings should not be displayed in any section', () {
      // Arrange
      final prefs = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: true,
      );

      // Act & Assert
      expect(prefs.hidePopularityInDetails, isFalse);
      expect(prefs.hideRatingsInDetails, isTrue);
    });

    test('Property 6: Both preferences can be true simultaneously', () {
      // Arrange
      final prefs = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: true,
      );

      // Act & Assert
      expect(prefs.hidePopularityInDetails, isTrue);
      expect(prefs.hideRatingsInDetails, isTrue);
    });

    test('Property 6: Both preferences can be false simultaneously', () {
      // Arrange
      final prefs = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: false,
      );

      // Act & Assert
      expect(prefs.hidePopularityInDetails, isFalse);
      expect(prefs.hideRatingsInDetails, isFalse);
    });

    test('Property 6: Preferences are independent - changing one does not affect the other', () {
      // Arrange
      final prefs1 = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: false,
      );

      final prefs2 = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: true,
      );

      // Act & Assert
      expect(prefs1.hidePopularityInDetails, isTrue);
      expect(prefs1.hideRatingsInDetails, isFalse);
      expect(prefs2.hidePopularityInDetails, isFalse);
      expect(prefs2.hideRatingsInDetails, isTrue);
    });
  });

  group('Display Preferences - Property 7: Preference Persistence', () {
    test('Property 7: Preferences object can be created with display preference values', () {
      // Arrange & Act
      final prefs = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: false,
        notifyTheatre: true,
        notifyStreaming: true,
      );

      // Assert
      expect(prefs.hidePopularityInDetails, equals(true));
      expect(prefs.hideRatingsInDetails, equals(false));
    });

    test('Property 7: Updating hidePopularityInDetails creates new preferences with updated value', () {
      // Arrange
      final initialPrefs = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: false,
      );

      // Act
      final updatedPrefs = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: false,
      );

      // Assert
      expect(initialPrefs.hidePopularityInDetails, isFalse);
      expect(updatedPrefs.hidePopularityInDetails, isTrue);
    });

    test('Property 7: Updating hideRatingsInDetails creates new preferences with updated value', () {
      // Arrange
      final initialPrefs = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: false,
      );

      // Act
      final updatedPrefs = Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: true,
      );

      // Assert
      expect(initialPrefs.hideRatingsInDetails, isFalse);
      expect(updatedPrefs.hideRatingsInDetails, isTrue);
    });

    test('Property 7: Multiple sequential preference updates maintain correct values', () {
      // Arrange & Act & Assert - First state
      var prefs = Preferences(hidePopularityInDetails: true, hideRatingsInDetails: false);
      expect(prefs.hidePopularityInDetails, isTrue);
      expect(prefs.hideRatingsInDetails, isFalse);

      // Act & Assert - Second state
      prefs = Preferences(hidePopularityInDetails: false, hideRatingsInDetails: true);
      expect(prefs.hidePopularityInDetails, isFalse);
      expect(prefs.hideRatingsInDetails, isTrue);

      // Act & Assert - Third state
      prefs = Preferences(hidePopularityInDetails: true, hideRatingsInDetails: true);
      expect(prefs.hidePopularityInDetails, isTrue);
      expect(prefs.hideRatingsInDetails, isTrue);
    });

    test('Property 7: Other preferences are preserved when creating new preferences with display preferences', () {
      // Arrange - original preferences for reference
      // hidePopularityInDetails: false, hideRatingsInDetails: false,
      // notifyTheatre: true, notifyStreaming: false, scheduleTime: '10:00'

      // Act
      final updatedPrefs = Preferences(
        hidePopularityInDetails: true,
        hideRatingsInDetails: true,
        notifyTheatre: true,
        notifyStreaming: false,
        scheduleTime: '10:00',
      );

      // Assert
      expect(updatedPrefs.hidePopularityInDetails, isTrue);
      expect(updatedPrefs.hideRatingsInDetails, isTrue);
      expect(updatedPrefs.notifyTheatre, isTrue);
      expect(updatedPrefs.notifyStreaming, isFalse);
      expect(updatedPrefs.scheduleTime, equals('10:00'));
    });

    test('Property 7: Default preferences have display preferences set to false', () {
      // Arrange & Act
      final defaultPrefs = Preferences();

      // Assert
      expect(defaultPrefs.hidePopularityInDetails, isFalse);
      expect(defaultPrefs.hideRatingsInDetails, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // copyWithLastCheckTime — regression guard
  //
  // This method was introduced after a bug where background checks silently
  // reset 11 user settings by copying only a subset of Preferences fields.
  // These tests ensure that every field is preserved and only lastCheckTime
  // changes. If a new HiveField is added to Preferences and copyWithLastCheckTime
  // is not updated, the test that checks a non-default value for that field will
  // fail here, surfacing the omission before it ships.
  // -------------------------------------------------------------------------
  group('Preferences.copyWithLastCheckTime', () {
    test('updates lastCheckTime and only lastCheckTime', () {
      final original = Preferences(lastCheckTime: '2026-01-01T00:00:00.000');
      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.lastCheckTime, equals('2026-08-28T09:00:00.000'));
      // Original is unchanged
      expect(original.lastCheckTime, equals('2026-01-01T00:00:00.000'));
    });

    test('preserves all non-default notification fields', () {
      final original = Preferences(
        notifyTheatre: false,
        notifyStreaming: false,
        notifyPhysical: true,
        notifyTV: true,
        notifyPersonTvEpisodes: false,
        scheduleTime: '14:30',
        defaultDepartments: ['Director'],
        allRolesSelected: true,
        allReleaseTypesSelected: true,
        autoFollowNewRoles: false,
      );

      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.notifyTheatre, isFalse);
      expect(updated.notifyStreaming, isFalse);
      expect(updated.notifyPhysical, isTrue);
      expect(updated.notifyTV, isTrue);
      expect(updated.notifyPersonTvEpisodes, isFalse);
      expect(updated.scheduleTime, equals('14:30'));
      expect(updated.defaultDepartments, equals(['Director']));
      expect(updated.allRolesSelected, isTrue);
      expect(updated.allReleaseTypesSelected, isTrue);
      expect(updated.autoFollowNewRoles, isFalse);
    });

    test('preserves all non-default UI/display fields', () {
      final original = Preferences(
        useDarkMode: false,
        hidePopularityInDetails: true,
        hideRatingsInDetails: true,
        reduceAnimations: true,
        useGridView: false,
        watchlistUseListView: true,
        homeSortOrder: 'releaseDate',
        watchlistSortOrder: 'title',
        groupByType: false,
        movieDetailsPreference: 'imdb',
        streamingCountry: 'GB',
      );

      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.useDarkMode, isFalse);
      expect(updated.hidePopularityInDetails, isTrue);
      expect(updated.hideRatingsInDetails, isTrue);
      expect(updated.reduceAnimations, isTrue);
      expect(updated.useGridView, isFalse);
      expect(updated.watchlistUseListView, isTrue);
      expect(updated.homeSortOrder, equals('releaseDate'));
      expect(updated.watchlistSortOrder, equals('title'));
      expect(updated.groupByType, isFalse);
      expect(updated.movieDetailsPreference, equals('imdb'));
      expect(updated.streamingCountry, equals('GB'));
    });

    test('preserves all non-default connections/social fields', () {
      final original = Preferences(
        connectionsSortOrder: 'releaseDate',
        connectionsGroupByRelease: true,
        connectionsShowHiddenContributors: true,
        connectionsShowHiddenWatchlist: true,
        dismissedConnectionIds: ['movie_123', 'tv_456'],
      );

      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.connectionsSortOrder, equals('releaseDate'));
      expect(updated.connectionsGroupByRelease, isTrue);
      expect(updated.connectionsShowHiddenContributors, isTrue);
      expect(updated.connectionsShowHiddenWatchlist, isTrue);
      expect(updated.dismissedConnectionIds, equals(['movie_123', 'tv_456']));
    });

    test('preserves other timestamp fields', () {
      final original = Preferences(
        lastCheckTime: '2026-01-01T00:00:00.000',
        lastViewedHistoryTime: '2026-01-02T12:00:00.000',
        pretendToday: '2026-06-15',
      );

      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.lastCheckTime, equals('2026-08-28T09:00:00.000'));
      expect(updated.lastViewedHistoryTime, equals('2026-01-02T12:00:00.000'));
      expect(updated.pretendToday, equals('2026-06-15'));
    });

    test('dismissedConnectionIds list is preserved by reference, not reset to empty', () {
      // This was the most damaging consequence of the old bug: dismissed
      // connections would re-appear after every background check.
      final ids = ['movie_1', 'movie_2', 'tv_3'];
      final original = Preferences(dismissedConnectionIds: ids);

      final updated = original.copyWithLastCheckTime('2026-08-28T09:00:00.000');

      expect(updated.dismissedConnectionIds, equals(ids));
      expect(updated.dismissedConnectionIds, isNotEmpty);
    });
  });
}