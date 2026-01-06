import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/movie_cache_entry.dart';
import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/logic/background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late BackgroundTaskProcessor processor;
  late MockTmdbService mockTmdbService;
  late MockContributorRepository mockContributorRepo;
  late MockPreferencesRepository mockPrefsRepo;
  late MockHistoryRepository mockHistoryRepo;
  late MockMovieCacheRepository mockMovieCacheRepo;
  late MockTvCacheRepository mockTvCacheRepo;
  late MockNotificationService mockNotificationService;

  setUp(() {
    mockTmdbService = MockTmdbService();
    mockContributorRepo = MockContributorRepository();
    mockPrefsRepo = MockPreferencesRepository();
    mockHistoryRepo = MockHistoryRepository();
    mockMovieCacheRepo = MockMovieCacheRepository();
    mockTvCacheRepo = MockTvCacheRepository();
    mockNotificationService = MockNotificationService();

    processor = BackgroundTaskProcessor(
      tmdbService: mockTmdbService,
      contributorRepo: mockContributorRepo,
      prefsRepo: mockPrefsRepo,
      historyRepo: mockHistoryRepo,
      movieCacheRepo: mockMovieCacheRepo,
      notificationService: mockNotificationService,
      tvCacheRepo: mockTvCacheRepo,
    );
    
    // Default stubs
    when(mockPrefsRepo.getPreferences()).thenReturn(Preferences(pretendToday: '2023-01-01'));
    when(mockHistoryRepo.getHistory()).thenReturn([]);
  });

  group('BackgroundTaskProcessor', () {
    test('Should process and notify for new releases', () async {
      // 1. Setup Contributor
      final contributor = Contributor(
        tmdbId: 1,
        name: 'Christopher Nolan',
        type: ContributorType.person,
        notifyForDepartments: ['Director'],
        availableDepartments: ['Director'],
        knownFor: '',
      );
      when(mockContributorRepo.getContributors()).thenReturn([contributor]);
      when(mockContributorRepo.getContributor(1)).thenReturn(contributor);

      // 2. Mock Credits (Oppenheimer)
      when(mockTmdbService.getPersonCombinedCredits(1)).thenAnswer((_) async => {
        'crew': [
          {'id': 100, 'job': 'Director', 'department': 'Directing', 'release_date': '2023-01-01'}
        ]
      });

      // 3. Mock Movie Details
      when(mockTmdbService.getMovieDetails(100)).thenAnswer((_) async => {
        'id': 100,
        'title': 'Oppenheimer',
        'release_date': '2023-01-01',
        'poster_path': '/path.jpg',
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'US',
              'release_dates': [{'type': 3, 'release_date': '2023-01-01T00:00:00.000Z'}]
            }
          ]
        }
      });

      // 4. Mock Movie Cache (after details are fetched, checker adds it to cache usually, but processor reads it)
      final movieEntry = MovieCacheEntry(tmdbId: 100, title: 'Oppenheimer', releaseDate: '2023-01-01', posterPath: '/path.jpg');
      when(mockMovieCacheRepo.getMovie(100)).thenReturn(movieEntry);

      // 5. Run Processor
      final result = await processor.process();

      // 6. Verify
      expect(result, isTrue);
      
      // Verify history update
      verify(mockHistoryRepo.addNotificationToHistory(any)).called(1);
      
      // Verify contributor update (latest work)
      verify(mockContributorRepo.updateContributor(argThat(predicate((Contributor c) => c.latestWork?.title == 'Oppenheimer')))).called(1);
    });

    test('Should not notify if no new releases', () async {
      when(mockContributorRepo.getContributors()).thenReturn([]);
      when(mockPrefsRepo.getPreferences()).thenReturn(Preferences(pretendToday: '2023-01-01'));
      
      final result = await processor.process();
      
      expect(result, isTrue);
      verifyNever(mockNotificationService.showNotification(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
      ));
    });
   group('BackgroundTaskProcessor', () {
      test('Should correctly identify TV releases for URL', () async {
        final contributor = Contributor(
          tmdbId: 2,
          name: 'TV Creator',
          type: ContributorType.person,
          notifyForDepartments: ['Creator'],
          availableDepartments: ['Creator'],
          knownFor: '',
        );
        when(mockContributorRepo.getContributors()).thenReturn([contributor]);
        when(mockContributorRepo.getContributor(2)).thenReturn(contributor);

        when(mockPrefsRepo.getPreferences()).thenReturn(Preferences(
          pretendToday: '2023-01-01',
          notifyTV: true,
        ));

        when(mockTmdbService.getPersonCombinedCredits(2)).thenAnswer((_) async => {
          'crew': [
            {'id': 200, 'media_type': 'tv', 'job': 'Creator', 'department': 'Creator', 'first_air_date': '2023-01-01'}
          ]
        });
        
        // No details needed for TV in ReleaseChecker usually but let's see
        
        final movieEntry = MovieCacheEntry(tmdbId: 200, title: 'TV Show', releaseDate: '2023-01-01');
        when(mockMovieCacheRepo.getMovie(200)).thenReturn(movieEntry);
        
        // Mock TV cache for the new TV show title lookup
        when(mockTvCacheRepo.getShow(200)).thenReturn(null);

        await processor.process();
      });
    });
  });
}
