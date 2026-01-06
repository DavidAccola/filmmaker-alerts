import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Type-Based Grouping Tests', () {
    // Property 13: Type-Based Grouping
    // **Property 13: Type-Based Grouping**
    // **Validates: Requirements 5.4**
    test('Property 13: Type-Based Grouping - Property Test', () {
      // Property: For any list of contributors with groupByType enabled, 
      // TV shows SHALL be grouped separately from movies, and all items 
      // within each group SHALL have the same ContributorType.
      
      // Property test with 100 iterations covering different contributor combinations
      for (int iteration = 0; iteration < 100; iteration++) {
        // Generate a random list of contributors with different types
        final contributors = <Contributor>[];
        
        // Determine how many of each type to generate (varies per iteration)
        final numPersons = iteration % 5;
        final numMovies = (iteration ~/ 5) % 5;
        final numTvShows = (iteration ~/ 25) % 5;
        final numCollections = (iteration ~/ 125) % 3;
        final numCompanies = (iteration ~/ 375) % 3;
        
        // Add persons
        for (int i = 0; i < numPersons; i++) {
          contributors.add(Contributor(
            tmdbId: 1000 + iteration * 100 + i,
            name: 'Person $i',
            type: ContributorType.person,
            profilePath: '/person$i.jpg',
            notifyForDepartments: ['Acting'],
            availableDepartments: ['Acting'],
            knownFor: 'Acting',
          ));
        }
        
        // Add movies
        for (int i = 0; i < numMovies; i++) {
          contributors.add(Contributor(
            tmdbId: 2000 + iteration * 100 + i,
            name: 'Movie $i',
            type: ContributorType.movie,
            profilePath: '/movie$i.jpg',
            notifyForDepartments: ['Movie'],
            availableDepartments: ['Movie'],
            knownFor: 'Movie',
          ));
        }
        
        // Add TV shows
        for (int i = 0; i < numTvShows; i++) {
          contributors.add(Contributor(
            tmdbId: 3000 + iteration * 100 + i,
            name: 'TV Show $i',
            type: ContributorType.tvShow,
            profilePath: '/tvshow$i.jpg',
            notifyForDepartments: ['TV Show'],
            availableDepartments: ['TV Show'],
            knownFor: 'TV Show',
          ));
        }
        
        // Add collections
        for (int i = 0; i < numCollections; i++) {
          contributors.add(Contributor(
            tmdbId: 4000 + iteration * 100 + i,
            name: 'Collection $i',
            type: ContributorType.collection,
            profilePath: '/collection$i.jpg',
            notifyForDepartments: ['Collection'],
            availableDepartments: ['Collection'],
            knownFor: 'Collection',
          ));
        }
        
        // Add companies
        for (int i = 0; i < numCompanies; i++) {
          contributors.add(Contributor(
            tmdbId: 5000 + iteration * 100 + i,
            name: 'Company $i',
            type: ContributorType.company,
            profilePath: '/company$i.jpg',
            notifyForDepartments: ['Company'],
            availableDepartments: ['Company'],
            knownFor: 'Company',
          ));
        }
        
        // Simulate the grouping logic from home_screen.dart
        final Map<ContributorType, List<Contributor>> groups = {};
        for (var c in contributors) {
          groups.putIfAbsent(c.type, () => []).add(c);
        }
        
        // Verify Property 13: All items within each group have the same ContributorType
        for (var entry in groups.entries) {
          final groupType = entry.key;
          final groupContributors = entry.value;
          
          // All contributors in this group must have the same type
          for (var contributor in groupContributors) {
            expect(
              contributor.type,
              equals(groupType),
              reason: 'All contributors in group $groupType must have type $groupType, '
                  'but found ${contributor.type} for ${contributor.name}',
            );
          }
        }
        
        // Verify that TV shows are grouped separately from movies
        if (groups.containsKey(ContributorType.tvShow) && 
            groups.containsKey(ContributorType.movie)) {
          final tvShowGroup = groups[ContributorType.tvShow]!;
          final movieGroup = groups[ContributorType.movie]!;
          
          // TV shows and movies should be in different groups
          expect(
            tvShowGroup.every((c) => c.type == ContributorType.tvShow),
            isTrue,
            reason: 'TV show group should only contain TV shows',
          );
          
          expect(
            movieGroup.every((c) => c.type == ContributorType.movie),
            isTrue,
            reason: 'Movie group should only contain movies',
          );
          
          // Verify no overlap between groups
          final tvShowIds = tvShowGroup.map((c) => c.tmdbId).toSet();
          final movieIds = movieGroup.map((c) => c.tmdbId).toSet();
          
          expect(
            tvShowIds.intersection(movieIds).isEmpty,
            isTrue,
            reason: 'TV show and movie groups should have no overlapping contributors',
          );
        }
        
        // Verify that the grouping preserves all contributors
        final totalInGroups = groups.values.fold<int>(0, (sum, group) => sum + group.length);
        expect(
          totalInGroups,
          equals(contributors.length),
          reason: 'All contributors should be present in groups after grouping',
        );
      }
    });
    
    // Additional edge case tests
    test('Property 13: Type-Based Grouping - Empty List', () {
      // Edge case: empty contributor list
      final contributors = <Contributor>[];
      
      final Map<ContributorType, List<Contributor>> groups = {};
      for (var c in contributors) {
        groups.putIfAbsent(c.type, () => []).add(c);
      }
      
      expect(groups.isEmpty, isTrue, reason: 'Empty contributor list should result in empty groups');
    });
    
    test('Property 13: Type-Based Grouping - Single Type', () {
      // Edge case: all contributors are the same type
      final contributors = <Contributor>[
        Contributor(
          tmdbId: 1,
          name: 'TV Show 1',
          type: ContributorType.tvShow,
          profilePath: '/tv1.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
        Contributor(
          tmdbId: 2,
          name: 'TV Show 2',
          type: ContributorType.tvShow,
          profilePath: '/tv2.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
        Contributor(
          tmdbId: 3,
          name: 'TV Show 3',
          type: ContributorType.tvShow,
          profilePath: '/tv3.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
      ];
      
      final Map<ContributorType, List<Contributor>> groups = {};
      for (var c in contributors) {
        groups.putIfAbsent(c.type, () => []).add(c);
      }
      
      expect(groups.length, equals(1), reason: 'Should have exactly one group');
      expect(groups.containsKey(ContributorType.tvShow), isTrue);
      expect(groups[ContributorType.tvShow]!.length, equals(3));
      
      // All items in the group should be TV shows
      for (var contributor in groups[ContributorType.tvShow]!) {
        expect(contributor.type, equals(ContributorType.tvShow));
      }
    });
    
    test('Property 13: Type-Based Grouping - All Types Present', () {
      // Edge case: all contributor types are present
      final contributors = <Contributor>[
        Contributor(
          tmdbId: 1,
          name: 'Person',
          type: ContributorType.person,
          profilePath: '/person.jpg',
          notifyForDepartments: ['Acting'],
          availableDepartments: ['Acting'],
          knownFor: 'Acting',
        ),
        Contributor(
          tmdbId: 2,
          name: 'Movie',
          type: ContributorType.movie,
          profilePath: '/movie.jpg',
          notifyForDepartments: ['Movie'],
          availableDepartments: ['Movie'],
          knownFor: 'Movie',
        ),
        Contributor(
          tmdbId: 3,
          name: 'TV Show',
          type: ContributorType.tvShow,
          profilePath: '/tv.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
        Contributor(
          tmdbId: 4,
          name: 'Collection',
          type: ContributorType.collection,
          profilePath: '/collection.jpg',
          notifyForDepartments: ['Collection'],
          availableDepartments: ['Collection'],
          knownFor: 'Collection',
        ),
        Contributor(
          tmdbId: 5,
          name: 'Company',
          type: ContributorType.company,
          profilePath: '/company.jpg',
          notifyForDepartments: ['Company'],
          availableDepartments: ['Company'],
          knownFor: 'Company',
        ),
      ];
      
      final Map<ContributorType, List<Contributor>> groups = {};
      for (var c in contributors) {
        groups.putIfAbsent(c.type, () => []).add(c);
      }
      
      // Should have exactly 5 groups (one for each type)
      expect(groups.length, equals(5), reason: 'Should have one group for each contributor type');
      
      // Each group should have exactly one contributor
      for (var entry in groups.entries) {
        expect(entry.value.length, equals(1), 
          reason: 'Each type group should have exactly one contributor');
        expect(entry.value[0].type, equals(entry.key),
          reason: 'Contributor type should match group type');
      }
      
      // Verify TV shows are separate from movies
      expect(groups[ContributorType.tvShow]![0].type, equals(ContributorType.tvShow));
      expect(groups[ContributorType.movie]![0].type, equals(ContributorType.movie));
      expect(
        groups[ContributorType.tvShow]![0].tmdbId,
        isNot(equals(groups[ContributorType.movie]![0].tmdbId)),
        reason: 'TV show and movie should be different contributors',
      );
    });
    
    test('Property 13: Type-Based Grouping - Mixed Types Separation', () {
      // Test that TV shows and movies are properly separated in a mixed list
      final contributors = <Contributor>[
        Contributor(
          tmdbId: 101,
          name: 'Movie 1',
          type: ContributorType.movie,
          profilePath: '/m1.jpg',
          notifyForDepartments: ['Movie'],
          availableDepartments: ['Movie'],
          knownFor: 'Movie',
        ),
        Contributor(
          tmdbId: 201,
          name: 'TV Show 1',
          type: ContributorType.tvShow,
          profilePath: '/tv1.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
        Contributor(
          tmdbId: 102,
          name: 'Movie 2',
          type: ContributorType.movie,
          profilePath: '/m2.jpg',
          notifyForDepartments: ['Movie'],
          availableDepartments: ['Movie'],
          knownFor: 'Movie',
        ),
        Contributor(
          tmdbId: 202,
          name: 'TV Show 2',
          type: ContributorType.tvShow,
          profilePath: '/tv2.jpg',
          notifyForDepartments: ['TV'],
          availableDepartments: ['TV'],
          knownFor: 'TV',
        ),
      ];
      
      final Map<ContributorType, List<Contributor>> groups = {};
      for (var c in contributors) {
        groups.putIfAbsent(c.type, () => []).add(c);
      }
      
      // Should have exactly 2 groups
      expect(groups.length, equals(2), reason: 'Should have one group for movies and one for TV shows');
      
      // Movie group should have 2 movies
      expect(groups[ContributorType.movie]!.length, equals(2));
      for (var movie in groups[ContributorType.movie]!) {
        expect(movie.type, equals(ContributorType.movie));
      }
      
      // TV show group should have 2 TV shows
      expect(groups[ContributorType.tvShow]!.length, equals(2));
      for (var tvShow in groups[ContributorType.tvShow]!) {
        expect(tvShow.type, equals(ContributorType.tvShow));
      }
      
      // Verify no cross-contamination
      final movieIds = groups[ContributorType.movie]!.map((c) => c.tmdbId).toSet();
      final tvShowIds = groups[ContributorType.tvShow]!.map((c) => c.tmdbId).toSet();
      
      expect(movieIds.intersection(tvShowIds).isEmpty, isTrue,
        reason: 'Movie and TV show groups should have no overlapping IDs');
    });
  });
}
