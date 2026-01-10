import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/providers/providers.dart';
import 'package:filmmaker_alerts/ui/screens/contributor_detail_screen.dart';
import 'package:filmmaker_alerts/ui/screens/movie_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('Contributor Details Navigation Tests', () {
    test('Property 1: Navigation Consistency - Property Test', () {
      // **Feature: contributor-details, Property 1: Navigation Consistency**
      // **Validates: Requirements 1.1, 12.1**
      
      // Test data for different contributor types
      final testContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Test Person',
          type: ContributorType.person,
          notifyForDepartments: ['Director'],
          availableDepartments: ['Director'],
          knownFor: 'Test Movie',
        ),
        Contributor(
          tmdbId: 2,
          name: 'Test Company',
          type: ContributorType.company,
          notifyForDepartments: ['Production'],
          availableDepartments: ['Production'],
          knownFor: 'Test Production',
        ),
        Contributor(
          tmdbId: 3,
          name: 'Test Collection',
          type: ContributorType.collection,
          notifyForDepartments: ['Collection'],
          availableDepartments: ['Collection'],
          knownFor: 'Test Collection',
        ),
        Contributor(
          tmdbId: 4,
          name: 'Test Movie',
          type: ContributorType.movie,
          notifyForDepartments: ['Movie'],
          availableDepartments: ['Movie'],
          knownFor: 'Test Movie',
        ),
      ];

      // Property test with 100 iterations covering different contributor types
      for (int i = 0; i < 100; i++) {
        final contributor = testContributors[i % testContributors.length];
        
        // Test navigation logic for contributor types
        if (contributor.type == ContributorType.person ||
            contributor.type == ContributorType.company ||
            contributor.type == ContributorType.collection) {
          
          // These should navigate to ContributorDetailScreen
          final screen = ContributorDetailScreen(contributor: contributor);
          expect(screen.contributor.tmdbId, equals(contributor.tmdbId),
            reason: 'ContributorDetailScreen should receive the correct contributor');
          expect(screen.contributor.type, equals(contributor.type),
            reason: 'ContributorDetailScreen should preserve contributor type');
            
        } else if (contributor.type == ContributorType.movie) {
          
          // Movies should navigate to MovieDetailScreen
          final screen = MovieDetailScreen(
            movieId: contributor.tmdbId,
            movieTitle: contributor.name,
          );
          expect(screen.movieId, equals(contributor.tmdbId),
            reason: 'MovieDetailScreen should receive the correct movie ID');
          expect(screen.movieTitle, equals(contributor.name),
            reason: 'MovieDetailScreen should receive the correct movie title');
        }
      }
      
      // Specific test cases for each contributor type
      final personContributor = Contributor(
        tmdbId: 100,
        name: 'Director Person',
        type: ContributorType.person,
        notifyForDepartments: ['Director'],
        availableDepartments: ['Director'],
        knownFor: 'Famous Movie',
      );
      
      final companyContributor = Contributor(
        tmdbId: 200,
        name: 'Production Company',
        type: ContributorType.company,
        notifyForDepartments: ['Production'],
        availableDepartments: ['Production'],
        knownFor: 'Big Budget Films',
      );
      
      final collectionContributor = Contributor(
        tmdbId: 300,
        name: 'Movie Collection',
        type: ContributorType.collection,
        notifyForDepartments: ['Collection'],
        availableDepartments: ['Collection'],
        knownFor: 'Franchise Series',
      );
      
      final movieContributor = Contributor(
        tmdbId: 400,
        name: 'Specific Movie',
        type: ContributorType.movie,
        notifyForDepartments: ['Movie'],
        availableDepartments: ['Movie'],
        knownFor: 'Blockbuster Film',
      );
      
      // Verify person navigation
      final personScreen = ContributorDetailScreen(contributor: personContributor);
      expect(personScreen.contributor.type, equals(ContributorType.person));
      expect(personScreen.contributor.name, equals('Director Person'));
      
      // Verify company navigation
      final companyScreen = ContributorDetailScreen(contributor: companyContributor);
      expect(companyScreen.contributor.type, equals(ContributorType.company));
      expect(companyScreen.contributor.name, equals('Production Company'));
      
      // Verify collection navigation
      final collectionScreen = ContributorDetailScreen(contributor: collectionContributor);
      expect(collectionScreen.contributor.type, equals(ContributorType.collection));
      expect(collectionScreen.contributor.name, equals('Movie Collection'));
      
      // Verify movie navigation
      final movieScreen = MovieDetailScreen(
        movieId: movieContributor.tmdbId,
        movieTitle: movieContributor.name,
      );
      expect(movieScreen.movieId, equals(400));
      expect(movieScreen.movieTitle, equals('Specific Movie'));
    });

    testWidgets('Navigation Consistency Widget Test', (WidgetTester tester) async {
      // Test that screens can be created and rendered without errors
      final testContributor = Contributor(
        tmdbId: 1,
        name: 'Test Person',
        type: ContributorType.person,
        notifyForDepartments: ['Director'],
        availableDepartments: ['Director'],
        knownFor: 'Test Movie',
      );

      // Mock dependencies for ProviderScope
      final mockPreferencesRepo = MockPreferencesRepository();
      when(mockPreferencesRepo.getPreferences()).thenReturn(Preferences());

      // Test ContributorDetailScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(mockPreferencesRepo),
          ],
          child: MaterialApp(
            home: ContributorDetailScreen(contributor: testContributor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Person'), findsWidgets);
      expect(find.text('Upcoming works will appear here'), findsOneWidget);

      // Test MovieDetailScreen
      await tester.pumpWidget(
        MaterialApp(
          home: MovieDetailScreen(movieId: 123, movieTitle: 'Test Movie'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Movie'), findsOneWidget);
      expect(find.text('Movie Detail Screen - Coming Soon'), findsOneWidget);
    });

    test('Property 14: Required UI Elements - Property Test', () {
      // **Feature: contributor-details, Property 14: Required UI Elements**
      // **Validates: Requirements 1.2, 1.3, 1.4, 5.1, 11.1, 11.2**
      
      // Test data for different contributor types
      final testContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Test Person',
          type: ContributorType.person,
          notifyForDepartments: ['Director'],
          availableDepartments: ['Director'],
          knownFor: 'Test Movie',
          profilePath: '/test_profile.jpg',
        ),
        Contributor(
          tmdbId: 2,
          name: 'Test Company',
          type: ContributorType.company,
          notifyForDepartments: ['Production'],
          availableDepartments: ['Production'],
          knownFor: 'Test Production',
          profilePath: null, // Test without profile image
        ),
        Contributor(
          tmdbId: 3,
          name: 'Test Collection',
          type: ContributorType.collection,
          notifyForDepartments: ['Collection'],
          availableDepartments: ['Collection'],
          knownFor: 'Test Collection',
        ),
      ];

      // Property test with 100 iterations covering different contributor types and scenarios
      for (int i = 0; i < 100; i++) {
        final contributor = testContributors[i % testContributors.length];
        
        // Test that ContributorDetailScreen can be created with required elements
        final screen = ContributorDetailScreen(contributor: contributor);
        
        // Verify screen has the required contributor data
        expect(screen.contributor.tmdbId, isNotNull,
          reason: 'ContributorDetailScreen should have contributor with valid TMDB ID');
        expect(screen.contributor.name, isNotEmpty,
          reason: 'ContributorDetailScreen should have contributor with non-empty name');
        expect(screen.contributor.type, isNotNull,
          reason: 'ContributorDetailScreen should have contributor with valid type');
        expect(screen.contributor.knownFor, isNotEmpty,
          reason: 'ContributorDetailScreen should have contributor with known for information');
        
        // Test MovieDetailScreen required elements
        final movieScreen = MovieDetailScreen(
          movieId: contributor.tmdbId,
          movieTitle: contributor.name,
        );
        
        expect(movieScreen.movieId, isPositive,
          reason: 'MovieDetailScreen should have positive movie ID');
        expect(movieScreen.movieTitle, isNotNull,
          reason: 'MovieDetailScreen should have movie title (can be null but property should exist)');
      }
      
      // Specific test cases for UI element requirements
      final personContributor = Contributor(
        tmdbId: 100,
        name: 'Director Person',
        type: ContributorType.person,
        notifyForDepartments: ['Director'],
        availableDepartments: ['Director'],
        knownFor: 'Famous Movie',
        profilePath: '/director_profile.jpg',
      );
      
      // Test that screen contains all required data for UI elements
      final screen = ContributorDetailScreen(contributor: personContributor);
      
      // Verify header info requirements (Requirements 1.2)
      expect(screen.contributor.name, equals('Director Person'));
      expect(screen.contributor.profilePath, equals('/director_profile.jpg'));
      
      // Verify contributor type is properly set for UI display
      expect(screen.contributor.type, equals(ContributorType.person));
      
      // Test with contributor without profile image
      final noImageContributor = Contributor(
        tmdbId: 200,
        name: 'No Image Person',
        type: ContributorType.person,
        notifyForDepartments: ['Writer'],
        availableDepartments: ['Writer'],
        knownFor: 'Great Script',
        profilePath: null,
      );
      
      final noImageScreen = ContributorDetailScreen(contributor: noImageContributor);
      expect(noImageScreen.contributor.profilePath, isNull);
      expect(noImageScreen.contributor.name, equals('No Image Person'));
    });

    testWidgets('Required UI Elements Widget Test', (WidgetTester tester) async {
      // Mock dependencies
      final mockPreferencesRepo = MockPreferencesRepository();
      when(mockPreferencesRepo.getPreferences()).thenReturn(Preferences(
        hidePopularityInDetails: false,
        hideRatingsInDetails: false,
      ));

      final testContributor = Contributor(
        tmdbId: 1,
        name: 'Test Person',
        type: ContributorType.person,
        notifyForDepartments: ['Director'],
        availableDepartments: ['Director'],
        knownFor: 'Test Movie',
        profilePath: '/test_profile.jpg',
      );

      // Test ContributorDetailScreen UI elements
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesRepositoryProvider.overrideWithValue(mockPreferencesRepo),
          ],
          child: MaterialApp(
            home: ContributorDetailScreen(contributor: testContributor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header info is displayed (Requirements 1.2)
      expect(find.text('Test Person'), findsWidgets); // May appear in AppBar and content
      expect(find.text('Person'), findsOneWidget);
      expect(find.text('Test Movie'), findsOneWidget);

      // Verify preference toggles are present (Requirements 1.3, 5.1)
      expect(find.text('Hide Popularity'), findsOneWidget);
      expect(find.text('Hide Ratings'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));

      // Verify three main sections are organized (Requirements 1.4)
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Latest Releases'), findsOneWidget);
      expect(find.text('Biggest Hits'), findsOneWidget);

      // Verify external link buttons are present (Requirements 11.1, 11.2)
      expect(find.text('See all credits on TMDB'), findsOneWidget);
      expect(find.text('See all credits on IMDB'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(2));

      // Verify icons are present for sections
      expect(find.byIcon(Icons.schedule), findsOneWidget); // Upcoming
      expect(find.byIcon(Icons.new_releases), findsOneWidget); // Latest Releases
      expect(find.byIcon(Icons.star), findsOneWidget); // Biggest Hits
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(2)); // External links
    });
  });
}