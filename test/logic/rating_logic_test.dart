import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:mockito/mockito.dart';

import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/repositories/episode_status_repository.dart';
import 'package:filmmaker_alerts/data/repositories/season_status_repository.dart';
import 'package:filmmaker_alerts/logic/connections_logic.dart';
import 'package:filmmaker_alerts/logic/connections_models.dart';
import 'package:filmmaker_alerts/logic/rating_logic.dart';

import '../helpers/test_helpers.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

WatchlistEntry _makeEntry({
  required int tmdbId,
  WorkType type = WorkType.movie,
  String title = 'Test',
  int? userRating,
  bool watched = false,
  List<ContributorSnapshot>? contributors,
}) {
  return WatchlistEntry(
    tmdbId: tmdbId,
    type: type,
    title: title,
    addedAt: DateTime(2024),
    addRank: tmdbId,
    followedContributors: contributors ?? [],
    statusRecords: watched
        ? [StatusRecord(status: WatchStatus.watched, setAt: DateTime(2024))]
        : [StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime(2024))],
  )..userRating = userRating;
}

EpisodeStatusEntry _makeEpisode({
  required int showId,
  required int seasonNumber,
  required int episodeNumber,
  int? userRating,
}) {
  return EpisodeStatusEntry(
    showId: showId,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    episodeTitle: 'Ep S${seasonNumber}E$episodeNumber',
  )..userRating = userRating;
}

SeasonStatusEntry _makeSeason({
  required int showId,
  required int seasonNumber,
  int? userRating,
}) {
  return SeasonStatusEntry(
    showId: showId,
    seasonNumber: seasonNumber,
  )..userRating = userRating;
}

// ---------------------------------------------------------------------------
// RatingLogic tests — use real in-memory Hive boxes
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    Hive.registerAdapter(EpisodeStatusEntryAdapter());
    Hive.registerAdapter(SeasonStatusEntryAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
    Hive.registerAdapter(WatchlistEntryAdapter());
    Hive.registerAdapter(WorkTypeAdapter());
    Hive.registerAdapter(ReleaseTypeAdapter());
    Hive.registerAdapter(ContributorSnapshotAdapter());
    Hive.registerAdapter(ReleaseNotificationPreferencesAdapter());
    Hive.registerAdapter(TvNotificationPreferencesAdapter());
    Hive.registerAdapter(ContributorAdapter());
    Hive.registerAdapter(ContributorTypeAdapter());
    Hive.registerAdapter(LatestWorkAdapter());
  });

  group('RatingLogic.effectiveRating', () {
    late Box<EpisodeStatusEntry> episodeBox;
    late Box<SeasonStatusEntry> seasonBox;
    late EpisodeStatusRepository episodeRepo;
    late SeasonStatusRepository seasonRepo;
    late RatingLogic logic;

    setUp(() async {
      await setUpTestHive();
      episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      episodeRepo = EpisodeStatusRepository(episodeBox);
      seasonRepo = SeasonStatusRepository(seasonBox);
      logic = RatingLogic(episodeRepo: episodeRepo, seasonRepo: seasonRepo);
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('returns manual userRating for movie', () {
      final entry = _makeEntry(tmdbId: 1, userRating: 8);
      expect(logic.effectiveRating(entry), 8.0);
    });

    test('returns null for unrated movie', () {
      final entry = _makeEntry(tmdbId: 1);
      expect(logic.effectiveRating(entry), isNull);
    });

    test('manual rating beats season average for TV show', () async {
      // Season 1 rated 6, but manual show rating is 9
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 6));
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow, userRating: 9);
      expect(logic.effectiveRating(entry), 9.0);
    });

    test('season average used when no manual show rating', () async {
      // Seasons 1 rated 6, season 2 rated 8 → avg = 7.0
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 6));
      await seasonBox.put('42_2', _makeSeason(showId: 42, seasonNumber: 2, userRating: 8));
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      expect(logic.effectiveRating(entry), 7.0);
    });

    test('season average beats episode average', () async {
      // Season rated 8, episodes rated 4 and 4 → season avg should win
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 8));
      await episodeBox.put('42_1_1', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 1, userRating: 4));
      await episodeBox.put('42_1_2', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 2, userRating: 4));
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      expect(logic.effectiveRating(entry), 8.0);
    });

    test('falls back to episode average when no season ratings', () async {
      // Episodes rated 6 and 10 → avg 8.0
      await episodeBox.put('42_1_1', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 1, userRating: 6));
      await episodeBox.put('42_1_2', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 2, userRating: 10));
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      expect(logic.effectiveRating(entry), 8.0);
    });

    test('returns null for TV show with no ratings at any level', () {
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      expect(logic.effectiveRating(entry), isNull);
    });

    test('isManualRating true only when userRating is set directly', () async {
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 7));
      final unrated = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      final manual = _makeEntry(tmdbId: 42, type: WorkType.tvShow, userRating: 9);
      expect(logic.isManualRating(unrated), false);
      expect(logic.isManualRating(manual), true);
    });

    test('effectiveSeasonRating: manual overrides episode avg', () async {
      // Season 1 manually rated 9
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 9));
      await episodeBox.put('42_1_1', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 1, userRating: 2));
      expect(logic.effectiveSeasonRating(42, 1), 9.0);
    });

    test('effectiveSeasonRating: falls back to episode avg when no season rating', () async {
      await episodeBox.put('42_1_1', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 1, userRating: 4));
      await episodeBox.put('42_1_2', _makeEpisode(showId: 42, seasonNumber: 1, episodeNumber: 2, userRating: 6));
      expect(logic.effectiveSeasonRating(42, 1), 5.0);
    });

    test('effectiveSeasonRating: returns null when no ratings exist', () {
      expect(logic.effectiveSeasonRating(42, 1), isNull);
    });

    test('seasonAverageRating: ignores unrated seasons', () async {
      await seasonBox.put('42_1', _makeSeason(showId: 42, seasonNumber: 1, userRating: 8));
      await seasonBox.put('42_2', _makeSeason(showId: 42, seasonNumber: 2)); // no rating
      final entry = _makeEntry(tmdbId: 42, type: WorkType.tvShow);
      // Only season 1 is rated → avg = 8.0 (not 4.0)
      expect(logic.seasonAverageRating(42), 8.0);
    });
  });

  // ---------------------------------------------------------------------------
  // computeRankedDiscoveryFeed — filtering and threshold tests
  // ---------------------------------------------------------------------------

  group('ConnectionsLogic.computeRankedDiscoveryFeed', () {
    late MockContributorDetailRepository mockDetailRepo;
    late MockWatchlistRepository mockWatchlistRepo;
    late MockMovieDetailRepository mockMovieDetailRepo;
    late MockTvDetailRepository mockTvDetailRepo;
    late RatingLogic ratingLogic;
    late ConnectionsLogic connectionsLogic;

    // Minimal repos for RatingLogic (no episodes/seasons needed for these tests)
    late Box<EpisodeStatusEntry> episodeBox;
    late Box<SeasonStatusEntry> seasonBox;

    setUp(() async {
      await setUpTestHive();
      episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes_cl');
      seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons_cl');

      mockDetailRepo = MockContributorDetailRepository();
      mockWatchlistRepo = MockWatchlistRepository();
      mockMovieDetailRepo = MockMovieDetailRepository();
      mockTvDetailRepo = MockTvDetailRepository();

      ratingLogic = RatingLogic(
        episodeRepo: EpisodeStatusRepository(episodeBox),
        seasonRepo: SeasonStatusRepository(seasonBox),
      );

      connectionsLogic = ConnectionsLogic(
        detailRepo: mockDetailRepo,
        watchlistRepo: mockWatchlistRepo,
        movieDetailRepo: mockMovieDetailRepo,
        tvDetailRepo: mockTvDetailRepo,
      );
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    // Helper: build a contributor with one work
    Contributor _contributor(int id, String name) => Contributor(
          tmdbId: id,
          name: name,
          type: ContributorType.person,
          notifyForDepartments: const ['Directing'],
          availableDepartments: const ['Directing'],
          knownFor: 'Directing',
        );

    ContributorDetail _detail(int contributorId, List<Work> works) =>
        ContributorDetail(
          tmdbId: contributorId,
          name: 'Person $contributorId',
          type: ContributorType.person,
          allWorks: works,
        );

    Work _work(int tmdbId, {WorkType type = WorkType.movie, int contributorId = 1, String dept = 'Directing', String role = 'Director'}) => Work(
          tmdbId: tmdbId,
          title: 'Work $tmdbId',
          type: type,
          contributorRoles: [
            ContributorRole(
              contributorId: contributorId,
              contributorName: 'Person $contributorId',
              role: role,
              department: dept,
            ),
          ],
        );

    test('excludes works already on watchlist', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');
      final sharedWork = _work(100, contributorId: 1);
      final sharedWork2 = sharedWork.copyWith(
        contributorRoles: [
          ...sharedWork.contributorRoles,
          ContributorRole(contributorId: 2, contributorName: 'Bob', role: 'Director', department: 'Directing'),
        ],
      );

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [sharedWork2]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [sharedWork2]));
      when(mockWatchlistRepo.getWorks()).thenReturn([
        _makeEntry(tmdbId: 100, type: WorkType.movie), // already on watchlist
      ]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      expect(results.any((w) => w.tmdbId == 100), false,
          reason: 'watchlist item should be excluded');
    });

    test('excludes watched works', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');
      final w = _work(200, contributorId: 1).copyWith(
        contributorRoles: [
          ContributorRole(contributorId: 1, contributorName: 'Alice', role: 'Director', department: 'Directing'),
          ContributorRole(contributorId: 2, contributorName: 'Bob', role: 'Director', department: 'Directing'),
        ],
      );

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [w]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [w]));
      when(mockWatchlistRepo.getWorks()).thenReturn([
        _makeEntry(tmdbId: 200, type: WorkType.movie, watched: true),
      ]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      expect(results.any((w) => w.tmdbId == 200), false,
          reason: 'watched item should be excluded');
    });

    test('excludes dismissed works', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');
      final w = _work(300, contributorId: 1).copyWith(
        contributorRoles: [
          ContributorRole(contributorId: 1, contributorName: 'Alice', role: 'Director', department: 'Directing'),
          ContributorRole(contributorId: 2, contributorName: 'Bob', role: 'Director', department: 'Directing'),
        ],
      );

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [w]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [w]));
      when(mockWatchlistRepo.getWorks()).thenReturn([]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: ['movie_300'],
        ratingLogic: ratingLogic,
      );

      expect(results.any((w) => w.tmdbId == 300), false,
          reason: 'dismissed item should be excluded');
    });

    test('includes work with 1 contributor in significant role (director)', () {
      final c1 = _contributor(1, 'Alice');
      // Only 1 contributor but role importance 0 (Director) — meets threshold
      final w = _work(400, contributorId: 1, dept: 'Directing', role: 'Director');

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [w]));
      when(mockWatchlistRepo.getWorks()).thenReturn([]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      expect(results.any((r) => r.tmdbId == 400), true,
          reason: 'single director should meet the significant-role threshold');
    });

    test('excludes work with 1 contributor in a minor crew role', () {
      final c1 = _contributor(1, 'Alice');
      // Role = 'Grip' in Crew dept → importance 7, above threshold of 4
      final w = _work(500, contributorId: 1, dept: 'Crew', role: 'Grip');

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [w]));
      when(mockWatchlistRepo.getWorks()).thenReturn([]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      expect(results.any((r) => r.tmdbId == 500), false,
          reason: 'single minor-crew contributor should not meet threshold');
    });

    test('includes work with 2+ contributors regardless of role', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');
      // Both in minor crew roles — still meets threshold because 2+ contributors
      final w = Work(
        tmdbId: 600,
        title: 'Work 600',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(contributorId: 1, contributorName: 'Alice', role: 'Grip', department: 'Crew'),
          ContributorRole(contributorId: 2, contributorName: 'Bob', role: 'Grip', department: 'Crew'),
        ],
      );

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [w]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [w]));
      when(mockWatchlistRepo.getWorks()).thenReturn([]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      expect(results.any((r) => r.tmdbId == 600), true,
          reason: '2 contributors should meet threshold regardless of role');
    });

    test('contributor filter narrows results to only that person', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');

      final wAlice = _work(700, contributorId: 1, dept: 'Directing', role: 'Director');
      final wBob = _work(800, contributorId: 2, dept: 'Directing', role: 'Director');

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [wAlice]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [wBob]));
      when(mockWatchlistRepo.getWorks()).thenReturn([]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
        contributorFilter: 1, // Only Alice
      );

      expect(results.every((r) => r.matchedContributors.any((mc) => mc.contributorId == 1)), true,
          reason: 'all results should include the filtered contributor');
      expect(results.any((r) => r.tmdbId == 800), false,
          reason: "Bob's work should be excluded when filtering by Alice");
    });

    test('higher-affinity contributors rank their works first', () {
      final c1 = _contributor(1, 'Alice');
      final c2 = _contributor(2, 'Bob');

      final wAlice = _work(901, contributorId: 1, dept: 'Directing', role: 'Director');
      final wBob = _work(902, contributorId: 2, dept: 'Directing', role: 'Director');

      when(mockDetailRepo.getContributorDetail(1)).thenReturn(_detail(1, [wAlice]));
      when(mockDetailRepo.getContributorDetail(2)).thenReturn(_detail(2, [wBob]));

      // Alice has a high-rated watched work → high affinity
      // Bob has no rated works → neutral affinity (1.0)
      // But Alice's rated avg (10) > Bob neutral (1.0 as fraction = 10/10) …
      // Actually neutral is 1.0, Alice rated 10 = 10/10 = 1.0 too.
      // Use a low rating for Bob to make the difference: Bob's work in watchlist rated 2.
      when(mockWatchlistRepo.getWorks()).thenReturn([
        _makeEntry(
          tmdbId: 9000,
          type: WorkType.movie,
          watched: true,
          userRating: 2,
          contributors: [ContributorSnapshot(contributorId: 2, name: 'Bob', role: 'Director')],
        ),
      ]);

      final results = connectionsLogic.computeRankedDiscoveryFeed(
        followedContributors: [c1, c2],
        dismissedConnectionIds: [],
        ratingLogic: ratingLogic,
      );

      // Bob has affinity 0.2 (rated 2/10), Alice neutral 1.0
      // Work 901 (Alice, director) scores higher than 902 (Bob, director)
      final ids = results.map((r) => r.tmdbId).toList();
      final aliceIdx = ids.indexOf(901);
      final bobIdx = ids.indexOf(902);
      expect(aliceIdx, lessThan(bobIdx),
          reason: "Alice's work (neutral affinity) should rank above Bob's (low affinity)");
    });
  });
}
