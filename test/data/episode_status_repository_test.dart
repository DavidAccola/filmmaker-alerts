import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/repositories/episode_status_repository.dart';

void main() {
  setUpAll(() {
    // Register adapters once for all tests
    Hive.registerAdapter(EpisodeStatusEntryAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
  });

  group('EpisodeStatusRepository', () {
    setUp(() async {
      await setUpTestHive();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('getOrCreateEpisode creates new episode entry', () async {
      final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final repo = EpisodeStatusRepository(box);

      final episode = await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Pilot',
        airDate: DateTime(2023, 1, 1),
      );

      expect(episode.showId, 123);
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.episodeTitle, 'Pilot');
      expect(episode.statusRecords.isEmpty, true);
    });

    test('getOrCreateEpisode returns existing episode', () async {
      final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final repo = EpisodeStatusRepository(box);

      // Create episode first time
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Pilot',
      );

      // Get same episode again
      final episode = await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Different Title', // Should be ignored
      );

      expect(episode.episodeTitle, 'Pilot'); // Original title preserved
    });

    group('Episode Status Clearing Hierarchy Tests', () {
      test('Watched clears In progress & Want to watch for episodes', () async {
        final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final repo = EpisodeStatusRepository(box);

        await repo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );

        // Add Want to watch status
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        var episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.inProgress);

        // Add Watched status (should clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.watched);
      });

      test('In progress clears Want to watch for episodes', () async {
        final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final repo = EpisodeStatusRepository(box);

        await repo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );

        // Add Want to watch status
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        var episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.wantToWatch);

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.inProgress);
      });

      test('Want to watch clears In progress for episodes', () async {
        final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final repo = EpisodeStatusRepository(box);

        await repo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );

        // Add In progress status
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        var episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.inProgress);

        // Add Want to watch status (should clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.wantToWatch);
      });

      test('Re-marking cleared statuses works for episodes', () async {
        final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final repo = EpisodeStatusRepository(box);

        await repo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );

        // Mark as Watched
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        var episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 1);
        expect(episode.statusRecords.first.status, WatchStatus.watched);

        // Re-mark as Want to watch (should work)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 2);
        expect(episode.statusRecords.any((r) => r.status == WatchStatus.watched), true);
        expect(episode.statusRecords.any((r) => r.status == WatchStatus.wantToWatch), true);
      });

      test('DNF does not clear other statuses for episodes', () async {
        final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
        final repo = EpisodeStatusRepository(box);

        await repo.getOrCreateEpisode(
          showId: 123,
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
        );

        // Add In progress status
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        // Add DNF status (should not clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          1,
          StatusRecord(status: WatchStatus.dnf, setAt: DateTime.now()),
        );

        final episode = repo.getEpisode(123, 1, 1);
        expect(episode!.statusRecords.length, 2);
        expect(episode.statusRecords.any((r) => r.status == WatchStatus.inProgress), true);
        expect(episode.statusRecords.any((r) => r.status == WatchStatus.dnf), true);
      });
    });

    test('getEpisodesByShow returns all episodes for show', () async {
      final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final repo = EpisodeStatusRepository(box);

      // Create episodes for show 123
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Episode 1',
      );
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 2,
        episodeTitle: 'Episode 2',
      );
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 2,
        episodeNumber: 1,
        episodeTitle: 'Episode 1',
      );

      // Create episode for different show
      await repo.getOrCreateEpisode(
        showId: 456,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'Different Show',
      );

      final episodes = repo.getEpisodesByShow(123);
      expect(episodes.length, 3);
      expect(episodes.every((e) => e.showId == 123), true);
    });

    test('getEpisodesBySeason returns episodes for specific season', () async {
      final box = await Hive.openBox<EpisodeStatusEntry>('test_episodes');
      final repo = EpisodeStatusRepository(box);

      // Create episodes for season 1
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 1,
        episodeTitle: 'S1E1',
      );
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 1,
        episodeNumber: 2,
        episodeTitle: 'S1E2',
      );

      // Create episode for season 2
      await repo.getOrCreateEpisode(
        showId: 123,
        seasonNumber: 2,
        episodeNumber: 1,
        episodeTitle: 'S2E1',
      );

      final season1Episodes = repo.getEpisodesBySeason(123, 1);
      expect(season1Episodes.length, 2);
      expect(season1Episodes.every((e) => e.seasonNumber == 1), true);
    });
  });
}