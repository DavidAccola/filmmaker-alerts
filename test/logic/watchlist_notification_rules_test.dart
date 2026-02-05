import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/data/repositories/watchlist_repository.dart';
import 'package:filmmaker_alerts/data/repositories/episode_status_repository.dart';
import 'package:filmmaker_alerts/data/repositories/season_status_repository.dart';
import 'package:filmmaker_alerts/logic/watchlist_notification_rules.dart';

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

  group('WatchlistNotificationRules', () {
    setUp(() async {
      await setUpTestHive();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    group('Movie Notification Rules', () {
      test('Movies on watchlist should notify by default', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Test Movie',
        );

        expect(rules.shouldNotifyForWork(123, WorkType.movie), true);
      });

      test('Snoozed movies should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Test Movie',
        );
        await watchlistRepo.setSnoozed(123, WorkType.movie, true);

        expect(rules.shouldNotifyForWork(123, WorkType.movie), false);
      });

      test('Movies with snoozed notifications should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Test Movie',
        );
        await watchlistRepo.setNotificationsSnoozed(123, WorkType.movie, true);

        expect(rules.shouldNotifyForWork(123, WorkType.movie), false);
      });

      test('Movies marked "Did not finish" should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Test Movie',
        );
        await watchlistRepo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.dnf, setAt: DateTime.now()),
        );

        expect(rules.shouldNotifyForWork(123, WorkType.movie), false);
      });
    });

    group('TV Show Notification Rules', () {
      test('TV shows with no episodes should notify by default', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        expect(rules.shouldNotifyForWork(123, WorkType.tvShow), true);
      });

      test('TV shows with "Want to watch" episodes should notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        // Add episode with "Want to watch" status
        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        expect(rules.shouldNotifyForWork(123, WorkType.tvShow), true);
      });

      test('TV shows with no "Want to watch" episodes should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        // Add episode with "Watched" status (no "Want to watch")
        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        expect(rules.shouldNotifyForWork(123, WorkType.tvShow), false);
      });

      test('Snoozed TV shows should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );
        await watchlistRepo.setSnoozed(123, WorkType.tvShow, true);

        expect(rules.shouldNotifyForWork(123, WorkType.tvShow), false);
      });
    });

    group('Episode Notification Rules', () {
      test('Episodes with no status should notify (default "Want to watch")', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        // Episode doesn't exist yet, so it has no status (default "Want to watch")
        expect(rules.shouldNotifyForEpisode(123, 1, 1), true);
      });

      test('Episodes marked "Want to watch" should notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        expect(rules.shouldNotifyForEpisode(123, 1, 1), true);
      });

      test('Episodes not marked "Want to watch" should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        expect(rules.shouldNotifyForEpisode(123, 1, 1), false);
      });

      test('Episodes of snoozed shows should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );
        await watchlistRepo.setSnoozed(123, WorkType.tvShow, true);

        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        expect(rules.shouldNotifyForEpisode(123, 1, 1), false);
      });
    });

    group('Season Notification Rules', () {
      test('Seasons with no status should notify if episodes are "Want to watch"', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        // Season doesn't exist yet, but episodes are assumed "Want to watch" by default
        expect(rules.shouldNotifyForSeason(123, 1), true);
      });

      test('Seasons marked "Want to watch" should notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        await seasonRepo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );
        await seasonRepo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        expect(rules.shouldNotifyForSeason(123, 1), true);
      });

      test('Seasons not marked "Want to watch" should not notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        await seasonRepo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );
        await seasonRepo.addStatusRecord(
          123,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        expect(rules.shouldNotifyForSeason(123, 1), false);
      });
    });

    group('Utility Methods', () {
      test('getNotifiableWorks returns only works that should notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        // Add notifiable movie
        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.movie,
          title: 'Notifiable Movie',
        );

        // Add snoozed movie (should not notify)
        await watchlistRepo.addWork(
          tmdbId: 456,
          type: WorkType.movie,
          title: 'Snoozed Movie',
        );
        await watchlistRepo.setSnoozed(456, WorkType.movie, true);

        // Add notifiable TV show
        await watchlistRepo.addWork(
          tmdbId: 789,
          type: WorkType.tvShow,
          title: 'Notifiable Show',
        );

        final notifiableWorks = rules.getNotifiableWorks();
        expect(notifiableWorks.length, 2);
        expect(notifiableWorks.any((w) => w.tmdbId == 123), true);
        expect(notifiableWorks.any((w) => w.tmdbId == 456), false); // Snoozed
        expect(notifiableWorks.any((w) => w.tmdbId == 789), true);
      });

      test('getNotifiableEpisodes returns only episodes that should notify', () async {
        final watchlistBox = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final episodeBox = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final seasonBox = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        
        final watchlistRepo = WatchlistRepository(watchlistBox);
        final episodeRepo = EpisodeStatusRepository(episodeBox);
        final seasonRepo = SeasonStatusRepository(seasonBox);
        final rules = WatchlistNotificationRules(watchlistRepo, episodeRepo, seasonRepo);

        await watchlistRepo.addWork(
          tmdbId: 123,
          type: WorkType.tvShow,
          title: 'Test Show',
        );

        // Add episode that should notify
        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Notifiable Episode',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        // Add episode that should not notify
        await episodeRepo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 2,
          episodeTitle: 'Non-notifiable Episode',
        );
        await episodeRepo.addStatusRecord(
          123,
          1,
          2,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        final notifiableEpisodes = rules.getNotifiableEpisodes(123);
        expect(notifiableEpisodes.length, 1);
        expect(notifiableEpisodes.first.episodeNumber, 1);
      });
    });
  });
}