import 'package:filmmaker_alerts/core/constants.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/movie_cache_entry.dart';
import 'package:filmmaker_alerts/data/models/movie_detail.dart';
import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/data/models/tv_cache.dart';
import 'package:filmmaker_alerts/data/models/tv_detail.dart';
import 'package:filmmaker_alerts/data/repositories/history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

NotificationHistoryEntry _tvEntry(int tmdbId) => NotificationHistoryEntry(
      tmdbId: tmdbId,
      mediaType: 'tv',
      reasons: [],
      notificationEvents: [
        NotificationEvent(
          releaseType: 'series_premiere',
          releaseDate: '2026-08-16',
          notifiedAt: '2026-08-16T10:00:00.000Z',
        ),
      ],
    );

NotificationHistoryEntry _movieEntry(int tmdbId) => NotificationHistoryEntry(
      tmdbId: tmdbId,
      mediaType: 'movie',
      reasons: [],
      notificationEvents: [
        NotificationEvent(
          releaseType: 'Theatrical',
          releaseDate: '2026-09-03',
          notifiedAt: '2026-09-03T09:00:00.000Z',
        ),
      ],
    );

void _registerAdapters() {
  // Only register if not already registered (tests share the Hive registry).
  void reg<T>(int id, TypeAdapter<T> a) {
    if (!Hive.isAdapterRegistered(id)) Hive.registerAdapter(a);
  }

  reg(3, NotificationHistoryEntryAdapter());
  reg(4, NotificationReasonAdapter());
  reg(5, NotificationEventAdapter());
  reg(6, MovieCacheEntryAdapter());
  reg(9, TvShowCacheEntryAdapter());
  reg(10, TvEpisodeCacheEntryAdapter());
  // TvShowDetail and its dependents
  reg(20, WorkTypeAdapter());
  reg(21, ReleaseTypeAdapter());
  reg(22, StreamingTypeAdapter());
  reg(23, ContributorRoleAdapter());
  reg(24, StreamingOptionAdapter());
  reg(25, WorkAdapter());
  reg(26, ContributorDetailAdapter());
  reg(27, CastMemberAdapter());
  reg(28, CrewMemberAdapter());
  reg(29, MovieDetailAdapter());
  reg(30, TvShowDetailAdapter());
  reg(31, TvSeasonAdapter());
}

// ---------------------------------------------------------------------------
// getHistory() — title/poster fallback logic
// ---------------------------------------------------------------------------

void main() {
  group('HistoryRepository.getHistory() — title/poster resolution', () {
    late HistoryRepository repo;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();

      // Open all boxes that HistoryRepository accesses.
      await Hive.openBox<NotificationHistoryEntry>(AppConstants.historyBox);
      await Hive.openBox<TvShowCacheEntry>(AppConstants.tvCacheBox);
      await Hive.openBox<MovieCacheEntry>(AppConstants.movieCacheBox);
      // Detail boxes are opened by HistoryRepository lazily via try/catch;
      // open them here so fallback logic is exercised.
      await Hive.openBox<TvShowDetail>(AppConstants.tvDetailsBox);
      await Hive.openBox<MovieDetail>(AppConstants.movieDetailsBox);

      repo = HistoryRepository();
    });

    tearDown(() async => tearDownTestHive());

    // --- TV show ---

    test('TV: returns title and poster from tv_shows_cache (O(1) path)', () async {
      const id = 111;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final tvCacheBox = Hive.box<TvShowCacheEntry>(AppConstants.tvCacheBox);

      await historyBox.add(_tvEntry(id));
      // tv_cache uses integer tmdbId as key.
      await tvCacheBox.put(id, TvShowCacheEntry(
        tmdbId: id,
        name: 'Lanterns',
        posterPath: '/lanterns.jpg',
        creators: [],
      ));

      final history = repo.getHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Lanterns');
      expect(history.first.posterPath, '/lanterns.jpg');
    });

    test('TV: falls back to tv_details when tv_cache misses', () async {
      const id = 222;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final tvDetailsBox = Hive.box<TvShowDetail>(AppConstants.tvDetailsBox);

      await historyBox.add(_tvEntry(id));
      // No entry in tv_cache — detail box is populated (e.g. user visited the show).
      await tvDetailsBox.add(TvShowDetail(
        tmdbId: id,
        name: 'Lanterns (from detail)',
        posterPath: '/lanterns_detail.jpg',
        synopsis: '',
      ));

      final history = repo.getHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Lanterns (from detail)');
      expect(history.first.posterPath, '/lanterns_detail.jpg');
    });

    test('TV: returns "Unknown Title" only when both cache and detail miss', () async {
      const id = 333;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await historyBox.add(_tvEntry(id));
      // Nothing in either cache.

      final history = repo.getHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Unknown Title');
      expect(history.first.posterPath, isNull);
    });

    test('TV: tv_cache entry with empty name falls through to tv_details', () async {
      const id = 444;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final tvCacheBox = Hive.box<TvShowCacheEntry>(AppConstants.tvCacheBox);
      final tvDetailsBox = Hive.box<TvShowDetail>(AppConstants.tvDetailsBox);

      await historyBox.add(_tvEntry(id));
      // Cache entry exists but name is empty (e.g. corrupted write).
      await tvCacheBox.put(id, TvShowCacheEntry(
        tmdbId: id,
        name: '',
        creators: [],
      ));
      await tvDetailsBox.add(TvShowDetail(
        tmdbId: id,
        name: 'Recovered Name',
        posterPath: '/recovered.jpg',
        synopsis: '',
      ));

      final history = repo.getHistory();
      expect(history.first.title, 'Recovered Name');
    });

    // --- Movie ---

    test('Movie: returns title and poster from movie_cache', () async {
      const id = 555;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final movieCacheBox = Hive.box<MovieCacheEntry>(AppConstants.movieCacheBox);

      await historyBox.add(_movieEntry(id));
      await movieCacheBox.add(MovieCacheEntry(
        tmdbId: id,
        title: 'NY Bear',
        posterPath: '/nybear.jpg',
      ));

      final history = repo.getHistory();
      expect(history.length, 1);
      expect(history.first.title, 'NY Bear');
      expect(history.first.posterPath, '/nybear.jpg');
    });

    test('Movie: falls back to movie_details when movie_cache misses', () async {
      const id = 666;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final movieDetailsBox = Hive.box<MovieDetail>(AppConstants.movieDetailsBox);

      await historyBox.add(_movieEntry(id));
      await movieDetailsBox.add(MovieDetail(
        tmdbId: id,
        title: 'NY Bear (from detail)',
        posterPath: '/nybear_detail.jpg',
        synopsis: '',
      ));

      final history = repo.getHistory();
      expect(history.first.title, 'NY Bear (from detail)');
      expect(history.first.posterPath, '/nybear_detail.jpg');
    });

    test('Movie: returns "Unknown Title" when both caches miss', () async {
      const id = 777;
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await historyBox.add(_movieEntry(id));

      final history = repo.getHistory();
      expect(history.first.title, 'Unknown Title');
      expect(history.first.posterPath, isNull);
    });

    // --- Sorting ---

    test('History is sorted by most recent notification descending', () async {
      final historyBox = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      final tvCacheBox = Hive.box<TvShowCacheEntry>(AppConstants.tvCacheBox);

      // Add entries with different notification dates.
      await historyBox.add(NotificationHistoryEntry(
        tmdbId: 1,
        mediaType: 'tv',
        reasons: [],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'series_premiere',
            releaseDate: '2026-01-01',
            notifiedAt: '2026-01-01T10:00:00.000Z', // older
          ),
        ],
      ));
      await historyBox.add(NotificationHistoryEntry(
        tmdbId: 2,
        mediaType: 'tv',
        reasons: [],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'season_premiere',
            releaseDate: '2026-09-01',
            notifiedAt: '2026-09-01T10:00:00.000Z', // newer
          ),
        ],
      ));
      await tvCacheBox.put(1, TvShowCacheEntry(tmdbId: 1, name: 'Show A', creators: []));
      await tvCacheBox.put(2, TvShowCacheEntry(tmdbId: 2, name: 'Show B', creators: []));

      final history = repo.getHistory();
      expect(history.first.title, 'Show B'); // most recent first
      expect(history.last.title, 'Show A');
    });
  });
}
