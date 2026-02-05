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
}
