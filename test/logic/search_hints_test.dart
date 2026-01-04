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

  group('SearchLogic Dynamic Hints', () {
    test('Movie hint uses upcoming movies from current year', () async {
      final currentYear = DateTime.now().year.toString();
      when(mockTmdbService.getUpcomingMovies()).thenAnswer((_) async => {
        'results': [
          {'title': 'Future Movie', 'release_date': '$currentYear-12-31', 'original_language': 'en'},
          {'title': 'Old Movie', 'release_date': '2000-01-01', 'original_language': 'en'},
          {'title': 'Foreign Movie', 'release_date': '$currentYear-12-31', 'original_language': 'fr'},
        ]
      });
      when(mockTmdbService.getTrendingMovies()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getTrendingPeople()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getPopularPeople()).thenAnswer((_) async => {'results': []});

      final hint = await searchLogic.getDynamicHint(ContributorType.movie);
      expect(hint, equals('e.g., Future Movie'));
    });

    test('Person hint prioritizes preferred roles from upcoming movies', () async {
      when(mockTmdbService.getUpcomingMovies()).thenAnswer((_) async => {
        'results': [
          {'id': 101, 'title': 'Upcoming 1', 'release_date': '2025-01-01', 'original_language': 'en'}
        ]
      });
      when(mockTmdbService.getMovieCredits(101)).thenAnswer((_) async => {
        'crew': [
          {'id': 1, 'name': 'Director Guy', 'job': 'Director'},
          {'id': 2, 'name': 'Producer Lady', 'job': 'Producer'},
        ]
      });
      when(mockTmdbService.getTrendingMovies()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getTrendingPeople()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getPopularPeople()).thenAnswer((_) async => {'results': []});

      // Test with preference for Director
      final hint = await searchLogic.getDynamicHint(ContributorType.person, preferredRoles: ['Director']);
      expect(hint, equals('e.g., Director Guy'));
    });

    test('Company hint uses production companies from trending movies', () async {
      when(mockTmdbService.getTrendingMovies()).thenAnswer((_) async => {
        'results': [
          {'id': 201, 'title': 'Trending 1', 'original_language': 'en'}
        ]
      });
      when(mockTmdbService.getMovieDetails(201)).thenAnswer((_) async => {
        'production_companies': [
          {'name': 'Cool Studio'}
        ]
      });
      when(mockTmdbService.getTrendingPeople()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getPopularPeople()).thenAnswer((_) async => {'results': []});
      when(mockTmdbService.getUpcomingMovies()).thenAnswer((_) async => {'results': []});

      final hint = await searchLogic.getDynamicHint(ContributorType.company);
      expect(hint, equals('e.g., Cool Studio'));
    });
  });
}
