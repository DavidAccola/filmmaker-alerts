import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/logic/contributor_logic.dart';
import 'package:filmmaker_alerts/logic/latest_work_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

// Simple mock for LatestWorkLogic that returns null for all calls
class TestLatestWorkLogic extends LatestWorkLogic {
  TestLatestWorkLogic() : super(MockTmdbService());
  
  @override
  Future<LatestWork?> calculateLatestWork(Contributor contributor, {String? pretendToday}) async {
    return null; // Always return null for testing
  }
}

void main() {
  late ContributorLogic contributorLogic;
  late MockTmdbService mockTmdbService;
  late MockContributorRepository mockContributorRepo;
  late MockPreferencesRepository mockPreferencesRepo;
  late TestLatestWorkLogic testLatestWorkLogic;

  setUp(() {
    mockTmdbService = MockTmdbService();
    mockContributorRepo = MockContributorRepository();
    mockPreferencesRepo = MockPreferencesRepository();
    testLatestWorkLogic = TestLatestWorkLogic();

    contributorLogic = ContributorLogic(
      mockContributorRepo,
      mockTmdbService,
      testLatestWorkLogic,
      mockPreferencesRepo,
    );

    // Default stubs
    when(mockContributorRepo.addContributor(any)).thenAnswer((_) async => true);
  });

  // Property-based test for global preference defaults
  test('Property 2: Global Preference Default Application - Property Test', () async {
    // **Property 2: Global Preference Default Application**
    // **Validates: Requirements 2.2, 3.3**
    
    // Property test with 100 iterations covering different global preference combinations
    for (int i = 0; i < 100; i++) {
      // Generate different combinations of global TV preferences
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
      
      final preferences = Preferences(
        defaultTvNotificationPrefs: globalTvPrefs,
      );
      
      when(mockPreferencesRepo.getPreferences()).thenReturn(preferences);
      
      // Create a sparse TV show contributor (without explicit preferences)
      final sparseTvShow = Contributor(
        tmdbId: 1000 + i,
        name: 'Test Show $i',
        type: ContributorType.tvShow,
        profilePath: '/test$i.jpg',
        notifyForDepartments: ['TV Show'],
        availableDepartments: ['TV Show'],
        knownFor: 'Test Show $i',
        // No tvNotificationPrefs set - should use global defaults
      );
      
      // Add the TV show
      await contributorLogic.addEnrichedContributor(sparseTvShow);
      
      // Verify that addContributor was called
      final captured = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
      
      // The stored contributor should have TV preferences that match the global defaults
      expect(captured.tvNotificationPrefs, isNotNull, 
        reason: 'TV show should have notification preferences applied from global defaults');
      
      if (captured.tvNotificationPrefs != null) {
        expect(captured.tvNotificationPrefs!.seriesPremiere, equals(seriesPremiere),
          reason: 'Series premiere preference should match global default ($seriesPremiere)');
        expect(captured.tvNotificationPrefs!.seasonPremieres, equals(seasonPremieres),
          reason: 'Season premieres preference should match global default ($seasonPremieres)');
        expect(captured.tvNotificationPrefs!.seasonFinales, equals(seasonFinales),
          reason: 'Season finales preference should match global default ($seasonFinales)');
        expect(captured.tvNotificationPrefs!.newEpisodes, equals(newEpisodes),
          reason: 'New episodes preference should match global default ($newEpisodes)');
        expect(captured.tvNotificationPrefs!.specials, equals(specials),
          reason: 'Specials preference should match global default ($specials)');
      }
      
      // Reset the mock for next iteration
      reset(mockContributorRepo);
      when(mockContributorRepo.addContributor(any)).thenAnswer((_) async => true);
    }
    
    // Test specific edge cases
    
    // Test with null global preferences (should use TvNotificationPreferences defaults)
    when(mockPreferencesRepo.getPreferences()).thenReturn(Preferences(
      defaultTvNotificationPrefs: null,
    ));
    
    final sparseTvShowNullGlobal = Contributor(
      tmdbId: 9999,
      name: 'Test Show Null Global',
      type: ContributorType.tvShow,
      profilePath: '/testnull.jpg',
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: 'Test Show Null Global',
    );
    
    await contributorLogic.addEnrichedContributor(sparseTvShowNullGlobal);
    
    final capturedNull = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
    
    // Should still have preferences applied (using TvNotificationPreferences defaults)
    expect(capturedNull.tvNotificationPrefs, isNotNull,
      reason: 'TV show should have default notification preferences even when global is null');
    
    // Test with explicit preferences override (should NOT use global defaults)
    final explicitPrefs = TvNotificationPreferences(
      seriesPremiere: false,
      seasonPremieres: false,
      seasonFinales: true,
      newEpisodes: true,
      specials: true,
    );
    
    final globalPrefs = TvNotificationPreferences(
      seriesPremiere: true,
      seasonPremieres: true,
      seasonFinales: false,
      newEpisodes: false,
      specials: false,
    );
    
    when(mockPreferencesRepo.getPreferences()).thenReturn(Preferences(
      defaultTvNotificationPrefs: globalPrefs,
    ));
    
    final sparseTvShowExplicit = Contributor(
      tmdbId: 8888,
      name: 'Test Show Explicit',
      type: ContributorType.tvShow,
      profilePath: '/testexplicit.jpg',
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: 'Test Show Explicit',
      tvNotificationPrefs: explicitPrefs, // Explicit preferences provided
    );
    
    await contributorLogic.addEnrichedContributor(sparseTvShowExplicit);
    
    final capturedExplicit = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
    
    // Should use explicit preferences, NOT global defaults
    expect(capturedExplicit.tvNotificationPrefs, isNotNull);
    if (capturedExplicit.tvNotificationPrefs != null) {
      expect(capturedExplicit.tvNotificationPrefs!.seriesPremiere, equals(false),
        reason: 'Should use explicit preference (false), not global default (true)');
      expect(capturedExplicit.tvNotificationPrefs!.seasonPremieres, equals(false),
        reason: 'Should use explicit preference (false), not global default (true)');
      expect(capturedExplicit.tvNotificationPrefs!.seasonFinales, equals(true),
        reason: 'Should use explicit preference (true), not global default (false)');
      expect(capturedExplicit.tvNotificationPrefs!.newEpisodes, equals(true),
        reason: 'Should use explicit preference (true), not global default (false)');
      expect(capturedExplicit.tvNotificationPrefs!.specials, equals(true),
        reason: 'Should use explicit preference (true), not global default (false)');
    }
  });

  // Property-based test for preference persistence
  test('Property 3: Per-Show Preference Persistence - Property Test', () async {
    // **Property 3: Per-Show Preference Persistence**
    // **Validates: Requirements 2.5, 3.4, 9.5**
    
    // Property test with 100 iterations covering different preference combinations
    for (int i = 0; i < 100; i++) {
      // Generate different combinations of TV preferences for the show
      final seriesPremiere = i % 2 == 0;
      final seasonPremieres = (i ~/ 2) % 2 == 0;
      final seasonFinales = (i ~/ 4) % 2 == 0;
      final newEpisodes = (i ~/ 8) % 2 == 0;
      final specials = (i ~/ 16) % 2 == 0;
      
      final customTvPrefs = TvNotificationPreferences(
        seriesPremiere: seriesPremiere,
        seasonPremieres: seasonPremieres,
        seasonFinales: seasonFinales,
        newEpisodes: newEpisodes,
        specials: specials,
      );
      
      // Set up different global preferences (should not affect stored preferences)
      final globalTvPrefs = TvNotificationPreferences(
        seriesPremiere: !seriesPremiere, // Opposite of custom
        seasonPremieres: !seasonPremieres,
        seasonFinales: !seasonFinales,
        newEpisodes: !newEpisodes,
        specials: !specials,
      );
      
      final preferences = Preferences(
        defaultTvNotificationPrefs: globalTvPrefs,
      );
      
      when(mockPreferencesRepo.getPreferences()).thenReturn(preferences);
      
      // Create a TV show contributor with custom preferences
      final tvShowWithCustomPrefs = Contributor(
        tmdbId: 2000 + i,
        name: 'Custom Prefs Show $i',
        type: ContributorType.tvShow,
        profilePath: '/custom$i.jpg',
        notifyForDepartments: ['TV Show'],
        availableDepartments: ['TV Show'],
        knownFor: 'Custom Prefs Show $i',
        tvNotificationPrefs: customTvPrefs, // Custom preferences set
      );
      
      // Store the TV show
      await contributorLogic.addEnrichedContributor(tvShowWithCustomPrefs);
      
      // Verify that addContributor was called and capture the stored contributor
      final storedContributor = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
      
      // Now simulate retrieval - mock the repository to return the stored contributor
      when(mockContributorRepo.getContributor(2000 + i)).thenReturn(storedContributor);
      
      // Retrieve the contributor
      final retrievedContributor = mockContributorRepo.getContributor(2000 + i);
      
      // Verify that the retrieved contributor has identical preferences to what was stored
      expect(retrievedContributor, isNotNull, 
        reason: 'Contributor should be retrievable after storage');
      
      expect(retrievedContributor!.tvNotificationPrefs, isNotNull,
        reason: 'TV show should have notification preferences after retrieval');
      
      if (retrievedContributor.tvNotificationPrefs != null) {
        // The retrieved preferences should match the original custom preferences exactly
        expect(retrievedContributor.tvNotificationPrefs!.seriesPremiere, equals(seriesPremiere),
          reason: 'Series premiere preference should persist exactly as stored ($seriesPremiere)');
        expect(retrievedContributor.tvNotificationPrefs!.seasonPremieres, equals(seasonPremieres),
          reason: 'Season premieres preference should persist exactly as stored ($seasonPremieres)');
        expect(retrievedContributor.tvNotificationPrefs!.seasonFinales, equals(seasonFinales),
          reason: 'Season finales preference should persist exactly as stored ($seasonFinales)');
        expect(retrievedContributor.tvNotificationPrefs!.newEpisodes, equals(newEpisodes),
          reason: 'New episodes preference should persist exactly as stored ($newEpisodes)');
        expect(retrievedContributor.tvNotificationPrefs!.specials, equals(specials),
          reason: 'Specials preference should persist exactly as stored ($specials)');
        
        // Verify that stored preferences are independent of global preferences
        expect(retrievedContributor.tvNotificationPrefs!.seriesPremiere, isNot(equals(globalTvPrefs.seriesPremiere)),
          reason: 'Stored preferences should be independent of global preferences');
        expect(retrievedContributor.tvNotificationPrefs!.seasonPremieres, isNot(equals(globalTvPrefs.seasonPremieres)),
          reason: 'Stored preferences should be independent of global preferences');
        expect(retrievedContributor.tvNotificationPrefs!.seasonFinales, isNot(equals(globalTvPrefs.seasonFinales)),
          reason: 'Stored preferences should be independent of global preferences');
        expect(retrievedContributor.tvNotificationPrefs!.newEpisodes, isNot(equals(globalTvPrefs.newEpisodes)),
          reason: 'Stored preferences should be independent of global preferences');
        expect(retrievedContributor.tvNotificationPrefs!.specials, isNot(equals(globalTvPrefs.specials)),
          reason: 'Stored preferences should be independent of global preferences');
      }
      
      // Reset the mock for next iteration
      reset(mockContributorRepo);
      when(mockContributorRepo.addContributor(any)).thenAnswer((_) async => true);
    }
    
    // Test edge cases
    
    // Test with all preferences false
    final allFalsePrefs = TvNotificationPreferences(
      seriesPremiere: false,
      seasonPremieres: false,
      seasonFinales: false,
      newEpisodes: false,
      specials: false,
    );
    
    final tvShowAllFalse = Contributor(
      tmdbId: 9998,
      name: 'All False Show',
      type: ContributorType.tvShow,
      profilePath: '/allfalse.jpg',
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: 'All False Show',
      tvNotificationPrefs: allFalsePrefs,
    );
    
    await contributorLogic.addEnrichedContributor(tvShowAllFalse);
    final storedAllFalse = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
    when(mockContributorRepo.getContributor(9998)).thenReturn(storedAllFalse);
    
    final retrievedAllFalse = mockContributorRepo.getContributor(9998);
    expect(retrievedAllFalse!.tvNotificationPrefs!.seriesPremiere, equals(false));
    expect(retrievedAllFalse.tvNotificationPrefs!.seasonPremieres, equals(false));
    expect(retrievedAllFalse.tvNotificationPrefs!.seasonFinales, equals(false));
    expect(retrievedAllFalse.tvNotificationPrefs!.newEpisodes, equals(false));
    expect(retrievedAllFalse.tvNotificationPrefs!.specials, equals(false));
    
    // Test with all preferences true
    final allTruePrefs = TvNotificationPreferences(
      seriesPremiere: true,
      seasonPremieres: true,
      seasonFinales: true,
      newEpisodes: true,
      specials: true,
    );
    
    final tvShowAllTrue = Contributor(
      tmdbId: 9997,
      name: 'All True Show',
      type: ContributorType.tvShow,
      profilePath: '/alltrue.jpg',
      notifyForDepartments: ['TV Show'],
      availableDepartments: ['TV Show'],
      knownFor: 'All True Show',
      tvNotificationPrefs: allTruePrefs,
    );
    
    await contributorLogic.addEnrichedContributor(tvShowAllTrue);
    final storedAllTrue = verify(mockContributorRepo.addContributor(captureAny)).captured.last as Contributor;
    when(mockContributorRepo.getContributor(9997)).thenReturn(storedAllTrue);
    
    final retrievedAllTrue = mockContributorRepo.getContributor(9997);
    expect(retrievedAllTrue!.tvNotificationPrefs!.seriesPremiere, equals(true));
    expect(retrievedAllTrue.tvNotificationPrefs!.seasonPremieres, equals(true));
    expect(retrievedAllTrue.tvNotificationPrefs!.seasonFinales, equals(true));
    expect(retrievedAllTrue.tvNotificationPrefs!.newEpisodes, equals(true));
    expect(retrievedAllTrue.tvNotificationPrefs!.specials, equals(true));
  });
}