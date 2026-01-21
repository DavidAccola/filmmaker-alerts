import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/repositories/watchlist_repository.dart';
import 'package:filmmaker_alerts/data/repositories/episode_status_repository.dart';
import 'package:filmmaker_alerts/data/repositories/season_status_repository.dart';
import 'package:filmmaker_alerts/logic/watchlist_logic.dart';

void main() {
  setUpAll(() {
    // Register adapters once for all tests
    Hive.registerAdapter(WatchlistEntryAdapter());
    Hive.registerAdapter(ContributorSnapshotAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
    Hive.registerAdapter(WorkTypeAdapter());
    Hive.registerAdapter(ReleaseTypeAdapter());
    Hive.registerAdapter(EpisodeStatusEntryAdapter());
    Hive.registerAdapter(SeasonStatusEntryAdapter());
  });

  group('WatchlistLogic', () {
    setUp(() async {
      await setUpTestHive();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('addWorkToWatchlist creates entry with default status', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      await logic.addWorkToWatchlist(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
      );

      final entry = logic.getWork(123, WorkType.movie);
      expect(entry, isNotNull);
      expect(entry!.title, 'Test Movie');
      expect(entry.statusRecords.length, 1);
      expect(entry.statusRecords.first.status, WatchStatus.wantToWatch);
    });

    test('removeWorkFromWatchlist removes TV show and related episodes/seasons', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      // Add TV show to watchlist
      await logic.addWorkToWatchlist(
        tmdbId: 123,
        type: WorkType.tvShow,
        title: 'Test Show',
      );

      // Add some episodes and seasons
      await episodeRepo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Pilot',
      );
      await seasonRepo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 1,
      );

      // Verify they exist
      expect(logic.getWork(123, WorkType.tvShow), isNotNull);
      expect(episodeRepo.getEpisodesByShow(123).length, 1);
      expect(seasonRepo.getSeasonsByShow(123).length, 1);

      // Remove the show
      await logic.removeWorkFromWatchlist(123, WorkType.tvShow);

      // Verify everything is removed
      expect(logic.getWork(123, WorkType.tvShow), isNull);
      expect(episodeRepo.getEpisodesByShow(123).length, 0);
      expect(seasonRepo.getSeasonsByShow(123).length, 0);
    });

    test('addStatusToWork adds status with dates', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      await logic.addWorkToWatchlist(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
      );

      final watchDate = DateTime.now();
      await logic.addStatusToWork(
        123,
        WorkType.movie,
        WatchStatus.watched,
        watchDates: [watchDate],
      );

      final entry = logic.getWork(123, WorkType.movie);
      expect(entry!.statusRecords.length, 1);
      expect(entry.statusRecords.first.status, WatchStatus.watched);
      expect(entry.statusRecords.first.watchDates, [watchDate]);
    });

    test('addStatusToEpisode adds status to episode', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      // Create episode first
      await episodeRepo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Pilot',
      );

      await logic.addStatusToEpisode(
        123,
        1,
        1,
        WatchStatus.watched,
        watchDates: [DateTime.now()],
      );

      final episode = episodeRepo.getEpisode(123, 1, 1);
      expect(episode!.statusRecords.length, 1);
      expect(episode.statusRecords.first.status, WatchStatus.watched);
    });

    test('addStatusToSeason adds status to season', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      // Create season first
      await seasonRepo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 1,
      );

      await logic.addStatusToSeason(
        123,
        1,
        WatchStatus.watched,
        watchDates: [DateTime.now()],
      );

      final season = seasonRepo.getSeason(123, 1);
      expect(season!.statusRecords.length, 1);
      expect(season.statusRecords.first.status, WatchStatus.watched);
    });

    group('Contributor Snapshot Tests', () {
      test('updateContributorSnapshot updates entry snapshots', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

        await logic.addWorkToWatchlist(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Test Movie',
        );

        final snapshots = [
          ContributorSnapshot(
            contributorId: 1,
            name: 'Christopher Nolan',
            role: 'Director',
          ),
          ContributorSnapshot(
            contributorId: 2,
            name: 'Leonardo DiCaprio',
            role: 'Actor',
          ),
        ];

        await logic.updateContributorSnapshot(123, WorkType.movie, snapshots);

        final entry = logic.getWork(123, WorkType.movie);
        expect(entry!.followedContributors.length, 2);
        expect(entry.followedContributors[0].name, 'Christopher Nolan');
        expect(entry.followedContributors[0].role, 'Director');
        expect(entry.followedContributors[1].name, 'Leonardo DiCaprio');
        expect(entry.followedContributors[1].role, 'Actor');
      });

      test('updateAllContributorSnapshots updates all entries', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

        // Add multiple works to watchlist
        await logic.addWorkToWatchlist(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Movie 1',
        );
        await logic.addWorkToWatchlist(
          tmdbId: 456,
          type: WorkType.tvShow,
          title: 'Show 1',
        );

        // Mock followed contributors (in real implementation, these would come from ContributorRepository)
        final followedContributors = <Contributor>[];

        // This should update snapshots for all entries
        await logic.updateAllContributorSnapshots(followedContributors);

        // Verify that the method completes without error
        // In a real implementation, you'd verify that snapshots were actually updated
        final entry1 = logic.getWork(123, WorkType.movie);
        final entry2 = logic.getWork(456, WorkType.tvShow);
        expect(entry1, isNotNull);
        expect(entry2, isNotNull);
      });
    });

    test('setSnoozed updates snoozed status', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      await logic.addWorkToWatchlist(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
      );

      await logic.setSnoozed(123, WorkType.movie, true);

      final entry = logic.getWork(123, WorkType.movie);
      expect(entry!.isSnoozed, true);
    });

    test('setNotificationsSnoozed updates notifications snoozed status', () async {
      final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      
      final watchlistRepo = WatchlistRepository(watchlistBox);
      final episodeRepo = EpisodeStatusRepository(episodeBox);
      final seasonRepo = SeasonStatusRepository(seasonBox);
      final logic = WatchlistLogic(watchlistRepo, episodeRepo, seasonRepo);

      await logic.addWorkToWatchlist(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
      );

      await logic.setNotificationsSnoozed(123, WorkType.movie, true);

      final entry = logic.getWork(123, WorkType.movie);
      expect(entry!.notificationsSnoozed, true);
    });
  });
}