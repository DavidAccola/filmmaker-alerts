import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/logic/release_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late ReleaseChecker releaseChecker;
  late MockTmdbService mockTmdbService;
  late MockContributorRepository mockContributorRepo;
  late MockPreferencesRepository mockPreferencesRepo;
  late MockHistoryRepository mockHistoryRepo;
  late MockMovieCacheRepository mockMovieCacheRepo;
  late MockWatchlistRepository mockWatchlistRepo;

  setUp(() {
    mockTmdbService = MockTmdbService();
    mockContributorRepo = MockContributorRepository();
    mockPreferencesRepo = MockPreferencesRepository();
    mockHistoryRepo = MockHistoryRepository();
    mockMovieCacheRepo = MockMovieCacheRepository();
    final mockTvCacheRepo = MockTvCacheRepository();
    mockWatchlistRepo = MockWatchlistRepository();

    releaseChecker = ReleaseChecker(
      mockTmdbService,
      mockContributorRepo,
      mockPreferencesRepo,
      mockHistoryRepo,
      mockMovieCacheRepo,
      mockTvCacheRepo,
      mockWatchlistRepo,
    );

    // Default Preferences
    when(mockPreferencesRepo.getPreferences()).thenReturn(
      Preferences(
        notifyTheatre: true,
        notifyStreaming: true,
        notifyPhysical: true,
        notifyTV: true,
        pretendToday: '2023-01-01', // Fixed date for testing
        defaultDepartments: [],
        includeCollectionsInMovieSearch: true,
      ),
    );
    
    // Default history
    when(mockHistoryRepo.getHistory()).thenReturn([]);
  });

  group('ReleaseChecker Logic', () {
    test('Department Filtering: Should ignore release if dept not followed', () async {
      // Setup Contributor: Follows 'Director' only (App Role)
      final nolan = Contributor(
        tmdbId: 1,
        name: 'Christopher Nolan',
        type: ContributorType.person,
        profilePath: '',
        notifyForDepartments: ['Director'], 
        availableDepartments: ['Director', 'Writer'],
        knownFor: '',
      );
      when(mockContributorRepo.getContributors()).thenReturn([nolan]);

      // Mock Credits: Oppenheimer (Dir & Write) - TMDB Departments
      when(mockTmdbService.getPersonCombinedCredits(1)).thenAnswer((_) async => {
        'crew': [
          {'id': 100, 'job': 'Writer', 'department': 'Writing', 'release_date': '2023-01-01'},
          {'id': 100, 'job': 'Director', 'department': 'Directing', 'release_date': '2023-01-01'},
        ]
      });

      // Mock Details
      when(mockTmdbService.getMovieDetails(100)).thenAnswer((_) async => {
        'id': 100,
        'title': 'Oppenheimer',
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'US',
              'release_dates': [{'type': 3, 'release_date': '2023-01-01T00:00:00.000Z'}]
            }
          ]
        },
        'poster_path': '/nolan.jpg',
        'release_date': '2023-01-01'
      });

      final notifications = await releaseChecker.findNewReleases();

      // Should verify that only 'Directing' reason is added (mapped to Director), NOT 'Writing'
      expect(notifications.length, 1);
      final notification = notifications.first;
      expect(notification.reasons.length, 1);
      expect(notification.reasons.first.department, 'Directing');
    });

    test('True All Logic: Should include all departments if allRolesSelected is true', () async {
      final nolan = Contributor(
        tmdbId: 1,
        name: 'Christopher Nolan',
        type: ContributorType.person,
        notifyForDepartments: ['Director'], // User followed only Director
        availableDepartments: ['Director', 'Writer'],
        allRolesSelected: true, // But enabled "True All"
        knownFor: '',
      );
      when(mockContributorRepo.getContributors()).thenReturn([nolan]);

      when(mockTmdbService.getPersonCombinedCredits(1)).thenAnswer((_) async => {
        'crew': [
          {'id': 100, 'job': 'Writer', 'department': 'Writing', 'release_date': '2023-01-01'},
        ]
      });

      when(mockTmdbService.getMovieDetails(100)).thenAnswer((_) async => {
        'id': 100,
        'title': 'Oppenheimer',
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'US',
              'release_dates': [{'type': 3, 'release_date': '2023-01-01T00:00:00.000Z'}]
            }
          ]
        },
        'poster_path': '/nolan.jpg',
        'release_date': '2023-01-01'
      });

      final notifications = await releaseChecker.findNewReleases();

      // Should include Writing because of True All
      expect(notifications.length, 1);
      expect(notifications.first.reasons.first.department, 'Writing');
    });

    test('Deduplication: Should group multiple roles for same movie', () async {
      // Setup Contributor: Follows BOTH
      final nolan = Contributor(
        tmdbId: 1,
        name: 'Christopher Nolan',
        type: ContributorType.person,
        profilePath: '',
        notifyForDepartments: ['Director', 'Writer'],
        availableDepartments: ['Director', 'Writer'],
        knownFor: '',
      );
      when(mockContributorRepo.getContributors()).thenReturn([nolan]);

      when(mockTmdbService.getPersonCombinedCredits(1)).thenAnswer((_) async => {
        'crew': [
          {'id': 100, 'job': 'Writer', 'department': 'Writing', 'release_date': '2023-01-01'},
          {'id': 100, 'job': 'Director', 'department': 'Directing', 'release_date': '2023-01-01'},
        ]
      });

      when(mockTmdbService.getMovieDetails(100)).thenAnswer((_) async => {
        'id': 100,
        'title': 'Oppenheimer',
        'release_dates': {
          'results': [
            {
              'iso_3166_1': 'US',
              'release_dates': [{'type': 3, 'release_date': '2023-01-01T00:00:00.000Z'}]
            }
          ]
        },
        'poster_path': '/nolan.jpg',
        'release_date': '2023-01-01'
      });

      final notifications = await releaseChecker.findNewReleases();

      // Should be 1 notification with 2 reasons
      expect(notifications.length, 1);
      final notification = notifications.first;
      expect(notification.reasons.length, 2);
      expect(notification.reasons.map((r) => r.department).toSet(), {'Directing', 'Writing'});
      
      // Verify getMovieDetails was called only once (Deduplication)
      verify(mockTmdbService.getMovieDetails(100)).called(1);
    });
  });
}