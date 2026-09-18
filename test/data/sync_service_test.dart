import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:filmmaker_alerts/data/models/collection_order.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/movie_status_entry.dart';
import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/services/google_auth_service.dart';
import 'package:filmmaker_alerts/data/services/sync_service.dart';
import 'package:filmmaker_alerts/core/constants.dart';

import 'sync_service_test.mocks.dart';

@GenerateMocks([GoogleAuthService, FlutterSecureStorage])
void main() {
  setUpAll(() {
    // Register all Hive adapters needed by SyncService
    Hive.registerAdapter(WatchlistEntryAdapter());
    Hive.registerAdapter(ContributorSnapshotAdapter());
    Hive.registerAdapter(ReleaseNotificationPreferencesAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
    Hive.registerAdapter(WorkTypeAdapter());
    Hive.registerAdapter(ReleaseTypeAdapter());
    Hive.registerAdapter(TvNotificationPreferencesAdapter());
    Hive.registerAdapter(ContributorAdapter());
    Hive.registerAdapter(ContributorTypeAdapter());
    Hive.registerAdapter(LatestWorkAdapter());
    Hive.registerAdapter(PreferencesAdapter());
    Hive.registerAdapter(EpisodeStatusEntryAdapter());
    Hive.registerAdapter(SeasonStatusEntryAdapter());
    Hive.registerAdapter(MovieStatusEntryAdapter());
    Hive.registerAdapter(NotificationReasonAdapter());
    Hive.registerAdapter(NotificationEventAdapter());
    Hive.registerAdapter(NotificationHistoryEntryAdapter());
    Hive.registerAdapter(CollectionOrderAdapter());
  });

  group('SyncService serialization roundtrips', () {
    late MockGoogleAuthService mockAuth;
    late MockFlutterSecureStorage mockStorage;
    late SyncService sync;

    setUp(() async {
      await setUpTestHive();

      // Open all boxes SyncService touches
      await Hive.openBox<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      await Hive.openBox<Contributor>(AppConstants.contributorsBox);
      await Hive.openBox<Preferences>(AppConstants.preferencesBox);
      await Hive.openBox<EpisodeStatusEntry>(AppConstants.episodeStatusesBox);
      await Hive.openBox<SeasonStatusEntry>(AppConstants.seasonStatusesBox);
      await Hive.openBox<MovieStatusEntry>(AppConstants.movieStatusesBox);
      await Hive.openBox<CollectionOrder>(AppConstants.collectionOrdersBox);
      await Hive.openBox<NotificationHistoryEntry>(AppConstants.historyBox);

      mockAuth = MockGoogleAuthService();
      mockStorage = MockFlutterSecureStorage();

      when(mockAuth.isSignedIn).thenReturn(true);
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => null);
      when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenAnswer((_) async {});

      sync = SyncService(auth: mockAuth, storage: mockStorage);
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    // -------------------------------------------------------------------------
    // WatchlistEntry roundtrip
    // -------------------------------------------------------------------------

    test('WatchlistEntry: all fields survive serialize → deserialize', () async {
      final prefs = ReleaseNotificationPreferences(
        theatrical: true,
        streaming: false,
        physical: true,
        tv: false,
      );
      final original = WatchlistEntry(
        tmdbId: 42,
        type: WorkType.movie,
        title: 'Inception',
        posterPath: '/poster.jpg',
        releaseDate: DateTime(2010, 7, 16),
        releaseType: ReleaseType.theatrical,
        addedAt: DateTime(2024, 1, 1),
        addRank: 3,
        userRank: 2,
        isSnoozed: true,
        notificationsSnoozed: false,
        overriddenGenre: 'Thriller',
        genreListId: 'genre_1',
        lastViewedAt: DateTime(2024, 6, 1),
        followedContributors: [
          ContributorSnapshot(contributorId: 1, name: 'Nolan', role: 'Director'),
        ],
        statusRecords: [
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime(2024, 2, 1),
            watchDates: [DateTime(2024, 2, 1), DateTime(2024, 3, 1)],
          ),
        ],
        releaseNotificationPrefs: prefs,
      )..userRating = 9;

      final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      await box.put(original.uniqueKey, original);

      // Serialize → JSON → deserialize → write back → read
      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get(original.uniqueKey);
      expect(restored, isNotNull);
      expect(restored!.tmdbId, 42);
      expect(restored.type, WorkType.movie);
      expect(restored.title, 'Inception');
      expect(restored.posterPath, '/poster.jpg');
      expect(restored.releaseDate, DateTime(2010, 7, 16));
      expect(restored.releaseType, ReleaseType.theatrical);
      expect(restored.addRank, 3);
      expect(restored.userRank, 2);
      expect(restored.userRating, 9);
      expect(restored.isSnoozed, true);
      expect(restored.notificationsSnoozed, false);
      expect(restored.overriddenGenre, 'Thriller');
      expect(restored.genreListId, 'genre_1');
      expect(restored.lastViewedAt, DateTime(2024, 6, 1));
      expect(restored.followedContributors.length, 1);
      expect(restored.followedContributors.first.contributorId, 1);
      expect(restored.followedContributors.first.name, 'Nolan');
      expect(restored.statusRecords.length, 1);
      expect(restored.statusRecords.first.status, WatchStatus.watched);
      expect(restored.statusRecords.first.watchDates?.length, 2);
      expect(restored.releaseNotificationPrefs?.theatrical, true);
      expect(restored.releaseNotificationPrefs?.streaming, false);
      expect(restored.releaseNotificationPrefs?.physical, true);
    });

    test('WatchlistEntry: null optional fields survive roundtrip', () async {
      final original = WatchlistEntry(
        tmdbId: 99,
        type: WorkType.tvShow,
        title: 'Bare Minimum Show',
        addedAt: DateTime(2024),
        addRank: 1,
      );

      final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      await box.put(original.uniqueKey, original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get(original.uniqueKey);
      expect(restored, isNotNull);
      expect(restored!.posterPath, isNull);
      expect(restored.releaseDate, isNull);
      expect(restored.userRating, isNull);
      expect(restored.userRank, isNull);
      expect(restored.releaseNotificationPrefs, isNull);
      expect(restored.statusRecords, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Contributor roundtrip
    // -------------------------------------------------------------------------

    test('Contributor: all fields including tvNotificationPrefs and latestWork', () async {
      final tvPrefs = TvNotificationPreferences(
        seriesPremiere: true,
        seasonPremieres: false,
        seasonFinales: true,
        newEpisodes: false,
        specials: true,
      );
      final work = LatestWork(
        title: 'Oppenheimer',
        releaseYear: '2023',
        releaseDate: '2023-07-21',
        department: 'Directing',
        job: 'Director',
        posterPath: '/op.jpg',
        originalReleaseDate: '2023-07-21',
        originalReleaseType: 'theatrical',
        latestReleaseDate: '2023-11-01',
        latestReleaseType: 'streaming',
      );
      final original = Contributor(
        tmdbId: 525,
        name: 'Christopher Nolan',
        type: ContributorType.person,
        profilePath: '/nolan.jpg',
        knownFor: 'Directing',
        isHidden: false,
        notificationsSnoozed: true,
        notifyForDepartments: ['Directing', 'Writing'],
        availableDepartments: ['Directing', 'Writing', 'Production'],
        allRolesSelected: false,
        notifyTvEpisodeWork: true,
        showStatus: 'Returning Series',
        totalSeasons: 3,
        nextEpisodeDate: '2025-01-01',
        imdbId: 'nm0634240',
        followedAt: DateTime(2023, 1, 1),
        tvNotificationPrefs: tvPrefs,
        latestWork: work,
      );

      final box = Hive.box<Contributor>(AppConstants.contributorsBox);
      await box.put(original.tmdbId.toString(), original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get('525');
      expect(restored, isNotNull);
      expect(restored!.name, 'Christopher Nolan');
      expect(restored.profilePath, '/nolan.jpg');
      expect(restored.notificationsSnoozed, true);
      expect(restored.notifyForDepartments, ['Directing', 'Writing']);
      expect(restored.allRolesSelected, false);
      expect(restored.notifyTvEpisodeWork, true);
      expect(restored.showStatus, 'Returning Series');
      expect(restored.totalSeasons, 3);
      expect(restored.nextEpisodeDate, '2025-01-01');
      expect(restored.imdbId, 'nm0634240');
      expect(restored.followedAt, DateTime(2023, 1, 1));
      // TV notification prefs
      expect(restored.tvNotificationPrefs?.seriesPremiere, true);
      expect(restored.tvNotificationPrefs?.seasonPremieres, false);
      expect(restored.tvNotificationPrefs?.seasonFinales, true);
      expect(restored.tvNotificationPrefs?.newEpisodes, false);
      expect(restored.tvNotificationPrefs?.specials, true);
      // Latest work
      expect(restored.latestWork?.title, 'Oppenheimer');
      expect(restored.latestWork?.department, 'Directing');
      expect(restored.latestWork?.job, 'Director');
      expect(restored.latestWork?.latestReleaseType, 'streaming');
    });

    test('Contributor: null tvNotificationPrefs and latestWork survive roundtrip', () async {
      final original = Contributor(
        tmdbId: 999,
        name: 'Minimal Contributor',
        type: ContributorType.company,
        knownFor: 'Production',
        notifyForDepartments: [],
        availableDepartments: [],
      );

      final box = Hive.box<Contributor>(AppConstants.contributorsBox);
      await box.put(original.tmdbId.toString(), original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get('999');
      expect(restored?.tvNotificationPrefs, isNull);
      expect(restored?.latestWork, isNull);
      expect(restored?.followedAt, isNull);
    });

    // -------------------------------------------------------------------------
    // EpisodeStatusEntry roundtrip
    // -------------------------------------------------------------------------

    test('EpisodeStatusEntry: all fields including userRating', () async {
      final original = EpisodeStatusEntry(
        showId: 1,
        seasonNumber: 2,
        episodeNumber: 3,
        episodeTitle: 'The One',
        airDate: DateTime(2023, 5, 1),
        statusRecords: [
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime(2023, 5, 2),
            watchDates: [DateTime(2023, 5, 2)],
          ),
        ],
      )..userRating = 8;

      final box = Hive.box<EpisodeStatusEntry>(AppConstants.episodeStatusesBox);
      await box.put(original.uniqueKey, original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get(original.uniqueKey);
      expect(restored?.showId, 1);
      expect(restored?.seasonNumber, 2);
      expect(restored?.episodeNumber, 3);
      expect(restored?.episodeTitle, 'The One');
      expect(restored?.airDate, DateTime(2023, 5, 1));
      expect(restored?.userRating, 8);
      expect(restored?.statusRecords.first.status, WatchStatus.watched);
      expect(restored?.statusRecords.first.watchDates?.length, 1);
    });

    // -------------------------------------------------------------------------
    // SeasonStatusEntry roundtrip
    // -------------------------------------------------------------------------

    test('SeasonStatusEntry: userRating survives roundtrip', () async {
      final original = SeasonStatusEntry(
        showId: 10,
        seasonNumber: 1,
        airDate: DateTime(2022, 9, 1),
      )..userRating = 7;

      final box = Hive.box<SeasonStatusEntry>(AppConstants.seasonStatusesBox);
      await box.put(original.uniqueKey, original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get(original.uniqueKey);
      expect(restored?.showId, 10);
      expect(restored?.seasonNumber, 1);
      expect(restored?.userRating, 7);
      expect(restored?.airDate, DateTime(2022, 9, 1));
    });

    // -------------------------------------------------------------------------
    // MovieStatusEntry roundtrip
    // -------------------------------------------------------------------------

    test('MovieStatusEntry: all fields survive roundtrip', () async {
      final original = MovieStatusEntry(
        collectionId: 100,
        movieId: 200,
        movieTitle: 'Iron Man',
        releaseDate: DateTime(2008, 5, 2),
        statusRecords: [
          StatusRecord(status: WatchStatus.watched, setAt: DateTime(2020)),
        ],
      );

      final box = Hive.box<MovieStatusEntry>(AppConstants.movieStatusesBox);
      await box.put(original.uniqueKey, original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get(original.uniqueKey);
      expect(restored?.collectionId, 100);
      expect(restored?.movieId, 200);
      expect(restored?.movieTitle, 'Iron Man');
      expect(restored?.releaseDate, DateTime(2008, 5, 2));
      expect(restored?.statusRecords.first.status, WatchStatus.watched);
    });

    // -------------------------------------------------------------------------
    // Preferences roundtrip
    // -------------------------------------------------------------------------

    test('Preferences: legacy fields (pre-expansion) survive roundtrip', () async {
      // NOTE: This test covers only the fields that existed before the sync
      // expansion. The full set of new fields is covered by
      // 'new sync expansion fields survive roundtrip' below.
      final box = Hive.box<Preferences>(AppConstants.preferencesBox);
      final original = Preferences(
        notifyTheatre: false,
        notifyStreaming: true,
        notifyPhysical: true,
        notifyTV: false,
        scheduleTime: '14:30',
        useDarkMode: false,
        watchlistSortOrder: 'myRating',
        watchlistUseListView: true,
        connectionsSortOrder: 'releaseDate',
        connectionsGroupByRelease: true,
        connectionsShowHiddenContributors: true,
        connectionsShowHiddenWatchlist: false,
        dismissedConnectionIds: ['movie_123', 'tvShow_456'],
        streamingCountry: 'GB',
        defaultDepartments: ['Directing'],
        hideRatingsInDetails: true,
      );
      await box.add(original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.getAt(0)!;
      expect(restored.notifyTheatre, false);
      expect(restored.notifyStreaming, true);
      expect(restored.notifyPhysical, true);
      expect(restored.notifyTV, false);
      expect(restored.scheduleTime, '14:30');
      expect(restored.useDarkMode, false);
      expect(restored.watchlistSortOrder, 'myRating');
      expect(restored.watchlistUseListView, true);
      expect(restored.connectionsSortOrder, 'releaseDate');
      expect(restored.connectionsGroupByRelease, true);
      expect(restored.connectionsShowHiddenContributors, true);
      expect(restored.dismissedConnectionIds, ['movie_123', 'tvShow_456']);
      expect(restored.streamingCountry, 'GB');
      expect(restored.defaultDepartments, ['Directing']);
      expect(restored.hideRatingsInDetails, true);
    });

    // -------------------------------------------------------------------------
    // _replaceBox: atomic upsert/delete
    // -------------------------------------------------------------------------

    test('_replaceBox: entries removed from remote are deleted locally', () async {
      final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);

      // Start with 2 local entries
      final keep = WatchlistEntry(
          tmdbId: 1, type: WorkType.movie, title: 'Keep',
          addedAt: DateTime(2024), addRank: 1);
      final remove = WatchlistEntry(
          tmdbId: 2, type: WorkType.movie, title: 'Remove',
          addedAt: DateTime(2024), addRank: 2);
      await box.put(keep.uniqueKey, keep);
      await box.put(remove.uniqueKey, remove);

      // Build payload with only 'keep'
      final payload = sync.buildPayloadForTest();
      // Remove the second entry from the payload before applying
      final entries = payload['watchlistEntries'] as List;
      entries.removeWhere((e) => (e as Map)['tmdbId'] == 2);

      await sync.applyPayloadForTest(payload);

      expect(box.containsKey(keep.uniqueKey), true);
      expect(box.containsKey(remove.uniqueKey), false);
    });

    test('_replaceBox: new entries from remote are added locally', () async {
      final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      expect(box.isEmpty, true); // start empty

      // Build a payload with one entry manually
      final entry = WatchlistEntry(
          tmdbId: 55, type: WorkType.tvShow, title: 'New Show',
          addedAt: DateTime(2024), addRank: 1);
      await box.put(entry.uniqueKey, entry);
      final payload = sync.buildPayloadForTest();
      await box.clear();

      // Apply payload to empty box
      await sync.applyPayloadForTest(payload);

      expect(box.containsKey(entry.uniqueKey), true);
      expect(box.get(entry.uniqueKey)?.title, 'New Show');
    });

    test('_replaceBox: existing data preserved when applying identical payload', () async {
      // Verifies the build-first-then-upsert pattern: no data is cleared
      // before new items are ready, so applying the same data is safe.
      final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      final entry = WatchlistEntry(
          tmdbId: 1, type: WorkType.movie, title: 'Safe',
          addedAt: DateTime(2024), addRank: 1);
      await box.put(entry.uniqueKey, entry);

      final payload = sync.buildPayloadForTest();
      await sync.applyPayloadForTest(payload);

      // Entry should still be present after applying the same data
      expect(box.containsKey(entry.uniqueKey), true);
    });

    // -------------------------------------------------------------------------
    // Early-return guards
    // -------------------------------------------------------------------------

    test('downloadIfNewerAndSignedIn returns false when not signed in', () async {
      when(mockAuth.isSignedIn).thenReturn(false);
      final result = await sync.downloadIfNewerAndSignedIn();
      expect(result, false);
    });

    test('uploadIfSignedIn is no-op when not signed in', () async {
      when(mockAuth.isSignedIn).thenReturn(false);
      // Should complete without throwing
      await sync.uploadIfSignedIn();
    });

    // -------------------------------------------------------------------------
    // Preferences null-fallback behaviour
    // -------------------------------------------------------------------------

    test('Preferences: remote null for unset field preserves local value', () async {
      // A sync from a device that never set watchlistSortOrder (null in payload)
      // must NOT reset the receiving device's existing sort order.
      final box = Hive.box<Preferences>(AppConstants.preferencesBox);
      final local = Preferences(
        watchlistSortOrder: 'myRating',
        connectionsSortOrder: 'releaseDate',
        connectionsGroupByRelease: true,
        connectionsShowHiddenContributors: false,
        connectionsShowHiddenWatchlist: true,
        hideRatingsInDetails: false,
      );
      await box.add(local);

      // Apply a payload that has null for all the formerly-inconsistent fields
      final payload = sync.buildPayloadForTest();
      final prefs = payload['preferences'] as Map<String, dynamic>;
      prefs['watchlistSortOrder'] = null;
      prefs['connectionsSortOrder'] = null;
      prefs['connectionsGroupByRelease'] = null;
      prefs['connectionsShowHiddenContributors'] = null;
      prefs['connectionsShowHiddenWatchlist'] = null;
      prefs['hideRatingsInDetails'] = null;

      await sync.applyPayloadForTest(payload);

      final restored = box.getAt(0)!;
      // Local values must be preserved — not silently reset to null
      expect(restored.watchlistSortOrder, 'myRating');
      expect(restored.connectionsSortOrder, 'releaseDate');
      expect(restored.connectionsGroupByRelease, true);
      expect(restored.connectionsShowHiddenContributors, false);
      expect(restored.connectionsShowHiddenWatchlist, true);
      expect(restored.hideRatingsInDetails, false);
    });

    // -------------------------------------------------------------------------
    // lastSyncTime
    // -------------------------------------------------------------------------

    test('lastSyncTime returns null when no sync has occurred', () async {
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => null);
      final t = await sync.lastSyncTime();
      expect(t, isNull);
    });

    test('lastSyncTime returns parsed DateTime when present', () async {
      const ts = '2024-06-01T12:00:00.000Z';
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => ts);
      final t = await sync.lastSyncTime();
      expect(t, DateTime.utc(2024, 6, 1, 12, 0, 0));
    });

    // -------------------------------------------------------------------------
    // Preferences: new fields roundtrip
    // -------------------------------------------------------------------------

    test('Preferences: new sync expansion fields survive roundtrip', () async {
      final box = Hive.box<Preferences>(AppConstants.preferencesBox);
      final tvPrefs = TvNotificationPreferences(
        seriesPremiere: true,
        seasonPremieres: false,
        seasonFinales: true,
        newEpisodes: true,
        specials: false,
      );
      final original = Preferences(
        includeCollectionsInMovieSearch: false,
        useGridView: false,
        homeSortOrder: 'myRating',
        groupByType: false,
        allRolesSelected: true,
        allReleaseTypesSelected: true,
        autoFollowNewRoles: false,
        movieDetailsPreference: 'imdb',
        notifyPersonTvEpisodes: false,
        hidePopularityInDetails: true,
        defaultTvNotificationPrefs: tvPrefs,
      );
      await box.add(original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.getAt(0)!;
      expect(restored.includeCollectionsInMovieSearch, false);
      expect(restored.useGridView, false);
      expect(restored.homeSortOrder, 'myRating');
      expect(restored.groupByType, false);
      expect(restored.allRolesSelected, true);
      expect(restored.allReleaseTypesSelected, true);
      expect(restored.autoFollowNewRoles, false);
      expect(restored.movieDetailsPreference, 'imdb');
      expect(restored.notifyPersonTvEpisodes, false);
      expect(restored.hidePopularityInDetails, true);
      expect(restored.defaultTvNotificationPrefs?.seriesPremiere, true);
      expect(restored.defaultTvNotificationPrefs?.seasonPremieres, false);
      expect(restored.defaultTvNotificationPrefs?.seasonFinales, true);
      expect(restored.defaultTvNotificationPrefs?.newEpisodes, true);
      expect(restored.defaultTvNotificationPrefs?.specials, false);
    });

    test('Preferences: remote null for new fields preserves local value', () async {
      final box = Hive.box<Preferences>(AppConstants.preferencesBox);
      final local = Preferences(
        useGridView: false,
        homeSortOrder: 'myRating',
        movieDetailsPreference: 'imdb',
        notifyPersonTvEpisodes: false,
        hidePopularityInDetails: true,
        includeCollectionsInMovieSearch: false,
      );
      await box.add(local);

      final payload = sync.buildPayloadForTest();
      final prefs = payload['preferences'] as Map<String, dynamic>;
      prefs['useGridView'] = null;
      prefs['homeSortOrder'] = null;
      prefs['movieDetailsPreference'] = null;
      prefs['notifyPersonTvEpisodes'] = null;
      prefs['hidePopularityInDetails'] = null;
      prefs['includeCollectionsInMovieSearch'] = null;

      await sync.applyPayloadForTest(payload);

      final restored = box.getAt(0)!;
      expect(restored.useGridView, false);
      expect(restored.homeSortOrder, 'myRating');
      expect(restored.movieDetailsPreference, 'imdb');
      expect(restored.notifyPersonTvEpisodes, false);
      expect(restored.hidePopularityInDetails, true);
      expect(restored.includeCollectionsInMovieSearch, false);
    });

    // -------------------------------------------------------------------------
    // CollectionOrder roundtrip
    // -------------------------------------------------------------------------

    test('CollectionOrder: all fields survive roundtrip', () async {
      final box = Hive.box<CollectionOrder>(AppConstants.collectionOrdersBox);
      final original = CollectionOrder(
        collectionId: 131292,
        movieIds: [299536, 299534, 271110],
      );
      await box.put(original.collectionId.toString(), original);

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      final restored = box.get('131292');
      expect(restored, isNotNull);
      expect(restored!.collectionId, 131292);
      expect(restored.movieIds, [299536, 299534, 271110]);
    });

    test('CollectionOrder: payload includes collectionOrders key', () async {
      final payload = sync.buildPayloadForTest();
      expect(payload.containsKey('collectionOrders'), true);
      expect(payload['collectionOrders'], isA<List>());
    });

    // -------------------------------------------------------------------------
    // _mergeHistoryBox
    // -------------------------------------------------------------------------

    test('history: payload includes history key', () async {
      final payload = sync.buildPayloadForTest();
      expect(payload.containsKey('history'), true);
      expect(payload['history'], isA<List>());
    });

    test('history: remote-only entry is inserted locally', () async {
      final box = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      expect(box.isEmpty, true);

      final payload = {
        'history': [
          {
            'tmdbId': 123,
            'mediaType': 'movie',
            'seasonNumber': null,
            'episodeNumber': null,
            'episodeTitle': null,
            'tvNotificationType': null,
            'reasons': [
              {
                'contributorId': 1,
                'contributorName': 'Nolan',
                'department': 'Directing',
                'job': 'Director',
              }
            ],
            'notificationEvents': [
              {
                'releaseType': 'theatrical',
                'releaseDate': '2024-07-19',
                'notifiedAt': '2024-07-18T09:00:00.000Z',
              }
            ],
          }
        ],
      };

      await sync.applyPayloadForTest(payload);

      expect(box.length, 1);
      final entry = box.values.first;
      expect(entry.tmdbId, 123);
      expect(entry.mediaType, 'movie');
      expect(entry.reasons.length, 1);
      expect(entry.reasons.first.contributorName, 'Nolan');
      expect(entry.notificationEvents.length, 1);
      expect(entry.notificationEvents.first.releaseType, 'theatrical');
    });

    test('history: local-only entry is preserved (not deleted)', () async {
      final box = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await box.add(NotificationHistoryEntry(
        tmdbId: 999,
        mediaType: 'movie',
        reasons: [],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'streaming',
            releaseDate: '2024-01-01',
            notifiedAt: '2024-01-01T09:00:00.000Z',
          ),
        ],
      ));

      // Apply a payload that doesn't mention tmdbId 999
      await sync.applyPayloadForTest({'history': []});

      expect(box.length, 1);
      expect(box.values.first.tmdbId, 999);
    });

    test('history: existing entry has remote reasons and events merged in', () async {
      final box = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await box.add(NotificationHistoryEntry(
        tmdbId: 42,
        mediaType: 'movie',
        reasons: [
          NotificationReason(
            contributorId: 1,
            contributorName: 'Nolan',
            department: 'Directing',
          ),
        ],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'theatrical',
            releaseDate: '2024-07-19',
            notifiedAt: '2024-07-18T09:00:00.000Z',
          ),
        ],
      ));

      final payload = {
        'history': [
          {
            'tmdbId': 42,
            'mediaType': 'movie',
            'seasonNumber': null,
            'episodeNumber': null,
            'episodeTitle': null,
            'tvNotificationType': null,
            'reasons': [
              // existing reason — should not be duplicated
              {
                'contributorId': 1,
                'contributorName': 'Nolan',
                'department': 'Directing',
                'job': null,
              },
              // new reason — should be added
              {
                'contributorId': 2,
                'contributorName': 'Zimmer',
                'department': 'Sound',
                'job': 'Composer',
              },
            ],
            'notificationEvents': [
              // existing event — should not be duplicated
              {
                'releaseType': 'theatrical',
                'releaseDate': '2024-07-19',
                'notifiedAt': '2024-07-18T09:00:00.000Z',
              },
              // new event — should be added
              {
                'releaseType': 'streaming',
                'releaseDate': '2024-10-15',
                'notifiedAt': '2024-10-14T09:00:00.000Z',
              },
            ],
          }
        ],
      };

      await sync.applyPayloadForTest(payload);

      final entry = box.values.first;
      expect(entry.reasons.length, 2);
      expect(entry.reasons.map((r) => r.contributorId).toSet(), {1, 2});
      expect(entry.notificationEvents.length, 2);
      expect(
        entry.notificationEvents.map((e) => e.releaseType).toSet(),
        {'theatrical', 'streaming'},
      );
    });

    test('history: duplicate event on both sides is not duplicated', () async {
      final box = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await box.add(NotificationHistoryEntry(
        tmdbId: 77,
        mediaType: 'movie',
        reasons: [],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'streaming',
            releaseDate: '2024-03-01',
            notifiedAt: '2024-02-28T09:00:00.000Z',
          ),
        ],
      ));

      final payload = {
        'history': [
          {
            'tmdbId': 77,
            'mediaType': 'movie',
            'seasonNumber': null,
            'episodeNumber': null,
            'episodeTitle': null,
            'tvNotificationType': null,
            'reasons': [],
            'notificationEvents': [
              {
                'releaseType': 'streaming',
                'releaseDate': '2024-03-01',
                'notifiedAt': '2024-02-28T09:00:00.000Z',
              },
            ],
          }
        ],
      };

      await sync.applyPayloadForTest(payload);

      expect(box.values.first.notificationEvents.length, 1);
    });

    test('history: TV entry with seasonNumber and tvNotificationType survives roundtrip', () async {
      final box = Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
      await box.add(NotificationHistoryEntry(
        tmdbId: 1399, // Game of Thrones
        mediaType: 'tv',
        seasonNumber: 8,
        episodeNumber: 6,
        episodeTitle: 'The Iron Throne',
        tvNotificationType: 'season_premiere',
        reasons: [],
        notificationEvents: [
          NotificationEvent(
            releaseType: 'Series Premiere',
            releaseDate: '2019-05-19',
            notifiedAt: '2019-05-19T09:00:00.000Z',
          ),
        ],
      ));

      final payload = sync.buildPayloadForTest();
      await box.clear();
      await sync.applyPayloadForTest(payload);

      expect(box.length, 1);
      final entry = box.values.first;
      expect(entry.tmdbId, 1399);
      expect(entry.mediaType, 'tv');
      expect(entry.seasonNumber, 8);
      expect(entry.episodeNumber, 6);
      expect(entry.episodeTitle, 'The Iron Throne');
      expect(entry.tvNotificationType, 'season_premiere');
      expect(entry.notificationEvents.first.releaseType, 'Series Premiere');
    });
  });
}
