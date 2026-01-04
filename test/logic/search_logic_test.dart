import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/logic/search_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late SearchLogic searchLogic;
  late MockTmdbService mockTmdbService;

  setUp(() {
    mockTmdbService = MockTmdbService();
    searchLogic = SearchLogic(mockTmdbService);
  });

  group('SearchLogic Company Sorting', () {
    test('Prioritizes companies with higher popularity top works (Disney Case)', () async {
      // 1. Mock Search Results: DisneyToon (id: 1) is first, WDAS (id: 2) is 7th (index 6).
      // This tests that we enrich at least 7 items.
      final rawResults = List.generate(10, (index) {
        if (index == 0) return {'id': 1, 'name': 'DisneyToon Studios', 'logo_path': '/dt.jpg'};
        if (index == 6) return {'id': 2, 'name': 'Walt Disney Animation Studios', 'logo_path': '/wdas.jpg'};
        return {'id': 100 + index, 'name': 'Other Disney $index', 'logo_path': '/other.jpg'};
      });

      when(mockTmdbService.searchCompany(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': rawResults});

      // 2. Mock Top Works
      // DisneyToon: Low popularity work
      when(mockTmdbService.getCompanyTopWorks(1)).thenAnswer((_) async => {
        'results': [{'title': 'Planes', 'popularity': 50.0}]
      });

      // WDAS: High popularity work
      when(mockTmdbService.getCompanyTopWorks(2)).thenAnswer((_) async => {
        'results': [{'title': 'Moana 2', 'popularity': 2000.0}] // Winner
      });

      // Others: Very low popularity
      for (int i = 0; i < 10; i++) {
        if (i != 0 && i != 6) {
          when(mockTmdbService.getCompanyTopWorks(100 + i)).thenAnswer((_) async => {
            'results': [{'title': 'Obscure Short', 'popularity': 1.0}]
          });
        }
      }

      // 3. Execute
      final results = await searchLogic.getContributorSuggestions('Disney', ContributorType.company);

      // 4. Verify
      expect(results.results.length, 10);
      
      // WDAS should be first because it has highest max_popularity (2000 vs 50 vs 1)
      expect(results.results[0].name, 'Walt Disney Animation Studios');
      expect(results.results[0].tmdbId, 2);
      
      // DisneyToon should be second
      expect(results.results[1].name, 'DisneyToon Studios');
      expect(results.results[1].tmdbId, 1);
    });
  });

  group('SearchLogic People & Movie Sorting', () {
    test('Exact Match Gate: Prioritizes exact match only if popularity > 0', () async {
      final rawResults = [
        {'id': 10, 'name': 'Greta Gerwig', 'popularity': 0.0, 'known_for_department': 'Directing'}, // Exact but 0 pop
        {'id': 20, 'name': 'Greta Gerwig', 'popularity': 50.0, 'known_for_department': 'Directing'}, // Exact + pop
        {'id': 30, 'name': 'Greta', 'popularity': 100.0, 'known_for_department': 'Directing'}, // Not exact but high pop
      ];

      when(mockTmdbService.searchPerson(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': rawResults});

      final results = await searchLogic.getContributorSuggestions('Greta Gerwig', ContributorType.person);

      // Should be:
      // 1. Greta Gerwig (id: 20) - Exact & Pop > 0 (Valid Exact Match)
      // 2. Greta Gerwig (id: 10) - Exact match starts with query, beating id 30
      // 3. Greta (id: 30) - Does not start with "Greta Gerwig"
      expect(results.results[0].tmdbId, 20);
      expect(results.results[1].tmdbId, 10);
      expect(results.results[2].tmdbId, 30);
    });

    test('Starts With: Prioritizes results starting with query', () async {
      final rawResults = [
        {'id': 1, 'name': 'The Batman', 'popularity': 50.0},
        {'id': 2, 'title': 'Batman Begins', 'popularity': 40.0}, // Starts with query
        {'id': 3, 'title': 'Lego Batman', 'popularity': 60.0},
      ];

      when(mockTmdbService.searchMovie(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': rawResults});
      when(mockTmdbService.searchCollection(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': []});

      final results = await searchLogic.getContributorSuggestions('Batman', ContributorType.movie);

      // Should be:
      // 1. Batman Begins (id: 2) - Starts with Batman
      // 2. Lego Batman (id: 3) - higher pop than The Batman
      // 3. The Batman (id: 1)
      expect(results.results[0].tmdbId, 2);
      expect(results.results[1].tmdbId, 3);
      expect(results.results[2].tmdbId, 1);
    });

    test('Exact Match: Movie with exact name match wins regardless of popularity', () async {
      final rawResults = [
        {'id': 1, 'title': 'The Dark Knight', 'popularity': 1000.0},
        {'id': 2, 'title': 'Batman', 'popularity': 10.0}, // Exact Match
        {'id': 3, 'title': 'Batman Begins', 'popularity': 500.0}, // Starts With
      ];

      when(mockTmdbService.searchMovie(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': rawResults});
      when(mockTmdbService.searchCollection(any, page: anyNamed('page'))).thenAnswer((_) async => {'results': []});

      final results = await searchLogic.getContributorSuggestions('Batman', ContributorType.movie);

      // Order:
      // 1. Batman (Exact Match) - id 2
      // 2. Batman Begins (Starts With) - id 3
      // 3. The Dark Knight (Popularity) - id 1
      expect(results.results[0].tmdbId, 2);
      expect(results.results[1].tmdbId, 3);
      expect(results.results[2].tmdbId, 1);
    });
  });
}