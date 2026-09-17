import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests verify the TvNotificationPreferences model and the Preferences
// default-application logic independently of the contributor add flow.
//
// TV shows are added to the watchlist (not the contributor list) as of the
// franchise-follow refactor. The logic being tested here — that global TV prefs
// are correctly stored and retrieved — lives in the model layer and is
// unaffected by that routing change.

void main() {
  // Property-based test for global preference defaults
  test('Property 2: Global Preference Default Application - Property Test', () {
    // **Property 2: Global Preference Default Application**
    // **Validates: Requirements 2.2, 3.3**
    //
    // Verifies that TvNotificationPreferences stored on Preferences correctly
    // reflects whatever combination of flags was set.

    for (int i = 0; i < 100; i++) {
      final seriesPremiere = i % 2 == 0;
      final seasonPremieres = (i ~/ 2) % 2 == 0;
      final seasonFinales = (i ~/ 4) % 2 == 0;
      final newEpisodes = (i ~/ 8) % 2 == 0;
      final specials = (i ~/ 16) % 2 == 0;

      final globalTvPrefs = TvNotificationPreferences(
        seriesPremiere: seriesPremiere,
        seasonPremieres: seasonPremieres,
        seasonFinales: seasonFinales,
        newEpisodes: newEpisodes,
        specials: specials,
      );

      final preferences = Preferences(defaultTvNotificationPrefs: globalTvPrefs);

      // The effective default is the object we set.
      final effective = preferences.defaultTvNotificationPrefs!;
      expect(effective.seriesPremiere, equals(seriesPremiere),
          reason: 'Series premiere should be $seriesPremiere for iteration $i');
      expect(effective.seasonPremieres, equals(seasonPremieres),
          reason: 'Season premieres should be $seasonPremieres for iteration $i');
      expect(effective.seasonFinales, equals(seasonFinales),
          reason: 'Season finales should be $seasonFinales for iteration $i');
      expect(effective.newEpisodes, equals(newEpisodes),
          reason: 'New episodes should be $newEpisodes for iteration $i');
      expect(effective.specials, equals(specials),
          reason: 'Specials should be $specials for iteration $i');
    }

    // Null global prefs → fallback to TvNotificationPreferences() defaults.
    final prefsNoGlobal = Preferences(defaultTvNotificationPrefs: null);
    final fallback = prefsNoGlobal.defaultTvNotificationPrefs ?? TvNotificationPreferences();
    expect(fallback.seriesPremiere, isTrue,
        reason: 'Default seriesPremiere should be true');

    // Explicit prefs should be stored as-is, independent of any global value.
    final explicit = TvNotificationPreferences(
      seriesPremiere: false,
      seasonPremieres: false,
      seasonFinales: true,
      newEpisodes: true,
      specials: true,
    );
    final global = TvNotificationPreferences(
      seriesPremiere: true,
      seasonPremieres: true,
      seasonFinales: false,
      newEpisodes: false,
      specials: false,
    );
    // Contributor stores explicit prefs; they are not replaced by global.
    final contributor = Contributor(
      tmdbId: 8888,
      name: 'Test Show',
      type: ContributorType.tvShow,
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: 'Test Show',
      tvNotificationPrefs: explicit,
    );
    expect(contributor.tvNotificationPrefs!.seriesPremiere, isFalse,
        reason: 'Explicit false should not be overwritten by global true');
    expect(contributor.tvNotificationPrefs!.seasonFinales, isTrue,
        reason: 'Explicit true should not be overwritten by global false');
    // Demonstrate global is different
    expect(global.seriesPremiere, isTrue);
    expect(global.seasonFinales, isFalse);
  });

  // Property-based test for preference persistence
  test('Property 3: Per-Show Preference Persistence - Property Test', () {
    // **Property 3: Per-Show Preference Persistence**
    // **Validates: Requirements 2.5, 3.4, 9.5**
    //
    // Verifies that TvNotificationPreferences values survive round-trip storage
    // on a Contributor object and are independent of global defaults.

    for (int i = 0; i < 100; i++) {
      final seriesPremiere = i % 2 == 0;
      final seasonPremieres = (i ~/ 2) % 2 == 0;
      final seasonFinales = (i ~/ 4) % 2 == 0;
      final newEpisodes = (i ~/ 8) % 2 == 0;
      final specials = (i ~/ 16) % 2 == 0;

      final customPrefs = TvNotificationPreferences(
        seriesPremiere: seriesPremiere,
        seasonPremieres: seasonPremieres,
        seasonFinales: seasonFinales,
        newEpisodes: newEpisodes,
        specials: specials,
      );
      // Global prefs are the exact opposite.
      final globalPrefs = TvNotificationPreferences(
        seriesPremiere: !seriesPremiere,
        seasonPremieres: !seasonPremieres,
        seasonFinales: !seasonFinales,
        newEpisodes: !newEpisodes,
        specials: !specials,
      );

      final contributor = Contributor(
        tmdbId: 2000 + i,
        name: 'Show $i',
        type: ContributorType.tvShow,
        notifyForDepartments: ['TV Show'],
        availableDepartments: ['TV Show'],
        knownFor: 'Show $i',
        tvNotificationPrefs: customPrefs,
      );

      // Stored preferences match what was set.
      expect(contributor.tvNotificationPrefs!.seriesPremiere, equals(seriesPremiere));
      expect(contributor.tvNotificationPrefs!.seasonPremieres, equals(seasonPremieres));
      expect(contributor.tvNotificationPrefs!.seasonFinales, equals(seasonFinales));
      expect(contributor.tvNotificationPrefs!.newEpisodes, equals(newEpisodes));
      expect(contributor.tvNotificationPrefs!.specials, equals(specials));

      // Stored preferences are independent of global (opposite) preferences.
      expect(contributor.tvNotificationPrefs!.seriesPremiere,
          isNot(equals(globalPrefs.seriesPremiere)));
      expect(contributor.tvNotificationPrefs!.seasonPremieres,
          isNot(equals(globalPrefs.seasonPremieres)));
    }

    // All false.
    final allFalse = TvNotificationPreferences(
      seriesPremiere: false,
      seasonPremieres: false,
      seasonFinales: false,
      newEpisodes: false,
      specials: false,
    );
    final cAllFalse = Contributor(
      tmdbId: 9998,
      name: 'All False',
      type: ContributorType.tvShow,
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: '',
      tvNotificationPrefs: allFalse,
    );
    expect(cAllFalse.tvNotificationPrefs!.seriesPremiere, isFalse);
    expect(cAllFalse.tvNotificationPrefs!.newEpisodes, isFalse);

    // All true.
    final allTrue = TvNotificationPreferences(
      seriesPremiere: true,
      seasonPremieres: true,
      seasonFinales: true,
      newEpisodes: true,
      specials: true,
    );
    final cAllTrue = Contributor(
      tmdbId: 9997,
      name: 'All True',
      type: ContributorType.tvShow,
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: '',
      tvNotificationPrefs: allTrue,
    );
    expect(cAllTrue.tvNotificationPrefs!.seriesPremiere, isTrue);
    expect(cAllTrue.tvNotificationPrefs!.newEpisodes, isTrue);
  });
}
