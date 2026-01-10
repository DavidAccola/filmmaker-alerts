import 'package:filmmaker_alerts/core/constants.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/movie_cache_entry.dart';
import 'package:filmmaker_alerts/data/models/movie_detail.dart';
import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/data/repositories/contributor_detail_repository.dart';
import 'package:filmmaker_alerts/data/repositories/movie_detail_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ContributorAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LatestWorkAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PreferencesAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationHistoryEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(NotificationReasonAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(NotificationEventAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MovieCacheEntryAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ContributorTypeAdapter());
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(WorkTypeAdapter());
    if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(ReleaseTypeAdapter());
    if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(StreamingTypeAdapter());
    if (!Hive.isAdapterRegistered(23)) Hive.registerAdapter(ContributorRoleAdapter());
    if (!Hive.isAdapterRegistered(24)) Hive.registerAdapter(StreamingOptionAdapter());
    if (!Hive.isAdapterRegistered(25)) Hive.registerAdapter(WorkAdapter());
    if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(ContributorDetailAdapter());
    if (!Hive.isAdapterRegistered(27)) Hive.registerAdapter(CastMemberAdapter());
    if (!Hive.isAdapterRegistered(28)) Hive.registerAdapter(CrewMemberAdapter());
    if (!Hive.isAdapterRegistered(29)) Hive.registerAdapter(MovieDetailAdapter());

    await Hive.openBox<ContributorDetail>(AppConstants.contributorDetailsBox);
    await Hive.openBox<MovieDetail>(AppConstants.movieDetailsBox);
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  group('ContributorDetailRepository - Property 15: Data Caching Consistency', () {
    test('Property 15: Caching a contributor detail and retrieving it returns the same data', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail = ContributorDetail(
        tmdbId: 123,
        name: 'Test Director',
        profilePath: '/path.jpg',
        type: ContributorType.person,
        upcomingWorks: [],
        latestReleases: [],
        biggestHits: [],
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail);
      final retrieved = repo.getContributorDetail(123);

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.tmdbId, equals(123));
      expect(retrieved.name, equals('Test Director'));
      expect(retrieved.profilePath, equals('/path.jpg'));
    });

    test('Property 15: Updating a cached contributor detail overwrites the previous data', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail1 = ContributorDetail(
        tmdbId: 123,
        name: 'Original Name',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail2 = ContributorDetail(
        tmdbId: 123,
        name: 'Updated Name',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail1);
      await repo.cacheContributorDetail(detail2);
      final retrieved = repo.getContributorDetail(123);

      // Assert
      expect(retrieved!.name, equals('Updated Name'));
    });

    test('Property 15: Multiple contributor details can be cached independently', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail1 = ContributorDetail(
        tmdbId: 123,
        name: 'Director 1',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail2 = ContributorDetail(
        tmdbId: 456,
        name: 'Director 2',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail1);
      await repo.cacheContributorDetail(detail2);
      final retrieved1 = repo.getContributorDetail(123);
      final retrieved2 = repo.getContributorDetail(456);

      // Assert
      expect(retrieved1!.name, equals('Director 1'));
      expect(retrieved2!.name, equals('Director 2'));
    });

    test('Property 15: Retrieving non-existent contributor detail returns null', () async {
      // Arrange
      final repo = ContributorDetailRepository();

      // Act
      final retrieved = repo.getContributorDetail(999);

      // Assert
      expect(retrieved, isNull);
    });

    test('Property 15: isCached returns true for fresh data (within 24 hours)', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail = ContributorDetail(
        tmdbId: 123,
        name: 'Test Director',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail);
      final isFresh = repo.isCached(123);

      // Assert
      expect(isFresh, isTrue);
    });

    test('Property 15: isCached returns false for stale data (older than 24 hours)', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final oldTime = DateTime.now().subtract(Duration(hours: 25));
      final detail = ContributorDetail(
        tmdbId: 123,
        name: 'Test Director',
        type: ContributorType.person,
        lastUpdated: oldTime,
      );

      // Act
      await repo.cacheContributorDetail(detail);
      final isFresh = repo.isCached(123);

      // Assert
      expect(isFresh, isFalse);
    });

    test('Property 15: getAllCachedDetails returns all cached contributor details', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail1 = ContributorDetail(
        tmdbId: 123,
        name: 'Director 1',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail2 = ContributorDetail(
        tmdbId: 456,
        name: 'Director 2',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail1);
      await repo.cacheContributorDetail(detail2);
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(2));
      expect(allDetails.map((d) => d.tmdbId), containsAll([123, 456]));
    });

    test('Property 15: getCachedDetailsForContributors returns only requested contributors', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail1 = ContributorDetail(
        tmdbId: 123,
        name: 'Director 1',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail2 = ContributorDetail(
        tmdbId: 456,
        name: 'Director 2',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail3 = ContributorDetail(
        tmdbId: 789,
        name: 'Director 3',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail1);
      await repo.cacheContributorDetail(detail2);
      await repo.cacheContributorDetail(detail3);
      final filtered = repo.getCachedDetailsForContributors([123, 789]);

      // Assert
      expect(filtered.length, equals(2));
      expect(filtered.map((d) => d.tmdbId), containsAll([123, 789]));
      expect(filtered.map((d) => d.tmdbId), isNot(contains(456)));
    });

    test('Property 15: deleteContributorDetail removes specific contributor from cache', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail = ContributorDetail(
        tmdbId: 123,
        name: 'Test Director',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail);
      await repo.deleteContributorDetail(123);
      final retrieved = repo.getContributorDetail(123);

      // Assert
      expect(retrieved, isNull);
    });

    test('Property 15: clearAllCache removes all cached contributor details', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final detail1 = ContributorDetail(
        tmdbId: 123,
        name: 'Director 1',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final detail2 = ContributorDetail(
        tmdbId: 456,
        name: 'Director 2',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheContributorDetail(detail1);
      await repo.cacheContributorDetail(detail2);
      await repo.clearAllCache();
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(0));
    });

    test('Property 15: clearOldCache removes entries older than 7 days', () async {
      // Arrange
      final repo = ContributorDetailRepository();
      final freshDetail = ContributorDetail(
        tmdbId: 123,
        name: 'Fresh Director',
        type: ContributorType.person,
        lastUpdated: DateTime.now(),
      );
      final oldDetail = ContributorDetail(
        tmdbId: 456,
        name: 'Old Director',
        type: ContributorType.person,
        lastUpdated: DateTime.now().subtract(Duration(days: 8)),
      );

      // Act
      await repo.cacheContributorDetail(freshDetail);
      await repo.cacheContributorDetail(oldDetail);
      await repo.clearOldCache();
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(1));
      expect(allDetails.first.tmdbId, equals(123));
    });
  });

  group('MovieDetailRepository - Property 15: Data Caching Consistency', () {
    test('Property 15: Caching a movie detail and retrieving it returns the same data', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail = MovieDetail(
        tmdbId: 123,
        title: 'Test Movie',
        synopsis: 'A test movie',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail);
      final retrieved = repo.getMovieDetail(123);

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.tmdbId, equals(123));
      expect(retrieved.title, equals('Test Movie'));
      expect(retrieved.synopsis, equals('A test movie'));
    });

    test('Property 15: Updating a cached movie detail overwrites the previous data', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail1 = MovieDetail(
        tmdbId: 123,
        title: 'Original Title',
        synopsis: 'Original synopsis',
        lastUpdated: DateTime.now(),
      );
      final detail2 = MovieDetail(
        tmdbId: 123,
        title: 'Updated Title',
        synopsis: 'Updated synopsis',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail1);
      await repo.cacheMovieDetail(detail2);
      final retrieved = repo.getMovieDetail(123);

      // Assert
      expect(retrieved!.title, equals('Updated Title'));
      expect(retrieved.synopsis, equals('Updated synopsis'));
    });

    test('Property 15: Multiple movie details can be cached independently', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail1 = MovieDetail(
        tmdbId: 123,
        title: 'Movie 1',
        synopsis: 'Synopsis 1',
        lastUpdated: DateTime.now(),
      );
      final detail2 = MovieDetail(
        tmdbId: 456,
        title: 'Movie 2',
        synopsis: 'Synopsis 2',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail1);
      await repo.cacheMovieDetail(detail2);
      final retrieved1 = repo.getMovieDetail(123);
      final retrieved2 = repo.getMovieDetail(456);

      // Assert
      expect(retrieved1!.title, equals('Movie 1'));
      expect(retrieved2!.title, equals('Movie 2'));
    });

    test('Property 15: Retrieving non-existent movie detail returns null', () async {
      // Arrange
      final repo = MovieDetailRepository();

      // Act
      final retrieved = repo.getMovieDetail(999);

      // Assert
      expect(retrieved, isNull);
    });

    test('Property 15: isCached returns true for fresh data (within 24 hours)', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail = MovieDetail(
        tmdbId: 123,
        title: 'Test Movie',
        synopsis: 'A test movie',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail);
      final isFresh = repo.isCached(123);

      // Assert
      expect(isFresh, isTrue);
    });

    test('Property 15: isCached returns false for stale data (older than 24 hours)', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final oldTime = DateTime.now().subtract(Duration(hours: 25));
      final detail = MovieDetail(
        tmdbId: 123,
        title: 'Test Movie',
        synopsis: 'A test movie',
        lastUpdated: oldTime,
      );

      // Act
      await repo.cacheMovieDetail(detail);
      final isFresh = repo.isCached(123);

      // Assert
      expect(isFresh, isFalse);
    });

    test('Property 15: getAllCachedDetails returns all cached movie details', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail1 = MovieDetail(
        tmdbId: 123,
        title: 'Movie 1',
        synopsis: 'Synopsis 1',
        lastUpdated: DateTime.now(),
      );
      final detail2 = MovieDetail(
        tmdbId: 456,
        title: 'Movie 2',
        synopsis: 'Synopsis 2',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail1);
      await repo.cacheMovieDetail(detail2);
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(2));
      expect(allDetails.map((d) => d.tmdbId), containsAll([123, 456]));
    });

    test('Property 15: getCachedDetailsForMovies returns only requested movies', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail1 = MovieDetail(
        tmdbId: 123,
        title: 'Movie 1',
        synopsis: 'Synopsis 1',
        lastUpdated: DateTime.now(),
      );
      final detail2 = MovieDetail(
        tmdbId: 456,
        title: 'Movie 2',
        synopsis: 'Synopsis 2',
        lastUpdated: DateTime.now(),
      );
      final detail3 = MovieDetail(
        tmdbId: 789,
        title: 'Movie 3',
        synopsis: 'Synopsis 3',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail1);
      await repo.cacheMovieDetail(detail2);
      await repo.cacheMovieDetail(detail3);
      final filtered = repo.getCachedDetailsForMovies([123, 789]);

      // Assert
      expect(filtered.length, equals(2));
      expect(filtered.map((d) => d.tmdbId), containsAll([123, 789]));
      expect(filtered.map((d) => d.tmdbId), isNot(contains(456)));
    });

    test('Property 15: deleteMovieDetail removes specific movie from cache', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail = MovieDetail(
        tmdbId: 123,
        title: 'Test Movie',
        synopsis: 'A test movie',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail);
      await repo.deleteMovieDetail(123);
      final retrieved = repo.getMovieDetail(123);

      // Assert
      expect(retrieved, isNull);
    });

    test('Property 15: clearAllCache removes all cached movie details', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final detail1 = MovieDetail(
        tmdbId: 123,
        title: 'Movie 1',
        synopsis: 'Synopsis 1',
        lastUpdated: DateTime.now(),
      );
      final detail2 = MovieDetail(
        tmdbId: 456,
        title: 'Movie 2',
        synopsis: 'Synopsis 2',
        lastUpdated: DateTime.now(),
      );

      // Act
      await repo.cacheMovieDetail(detail1);
      await repo.cacheMovieDetail(detail2);
      await repo.clearAllCache();
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(0));
    });

    test('Property 15: clearOldCache removes entries older than 7 days', () async {
      // Arrange
      final repo = MovieDetailRepository();
      final freshDetail = MovieDetail(
        tmdbId: 123,
        title: 'Fresh Movie',
        synopsis: 'Fresh synopsis',
        lastUpdated: DateTime.now(),
      );
      final oldDetail = MovieDetail(
        tmdbId: 456,
        title: 'Old Movie',
        synopsis: 'Old synopsis',
        lastUpdated: DateTime.now().subtract(Duration(days: 8)),
      );

      // Act
      await repo.cacheMovieDetail(freshDetail);
      await repo.cacheMovieDetail(oldDetail);
      await repo.clearOldCache();
      final allDetails = repo.getAllCachedDetails();

      // Assert
      expect(allDetails.length, equals(1));
      expect(allDetails.first.tmdbId, equals(123));
    });
  });
}
