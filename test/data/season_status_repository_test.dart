import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/repositories/season_status_repository.dart';

void main() {
  setUpAll(() {
    // Register adapters once for all tests
    Hive.registerAdapter(SeasonStatusEntryAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
  });

  group('SeasonStatusRepository', () {
    setUp(() async {
      await setUpTestHive();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('getOrCreateSeason creates new season entry', () async {
      final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      final repo = SeasonStatusRepository(box);

      final season = await repo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 1,
        airDate: DateTime(2023, 1, 1),
      );

      expect(season.showId, 123);
      expect(season.seasonNumber, 1);
      expect(season.displayName, 'Season 1');
      expect(season.statusRecords.isEmpty, true);
    });

    test('getOrCreateSeason handles specials (season 0)', () async {
      final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      final repo = SeasonStatusRepository(box);

      final season = await repo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 0,
      );

      expect(season.displayName, 'Specials');
    });

    test('getOrCreateSeason returns existing season', () async {
      final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      final repo = SeasonStatusRepository(box);

      // Create season first time
      await repo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 1,
        airDate: DateTime(2023, 1, 1),
      );

      // Get same season again
      final season = await repo.getOrCreateSeason(
        showId: 123,
        seasonNumber: 1,
        airDate: DateTime(2023, 6, 1), // Different date should be ignored
      );

      expect(season.airDate, DateTime(2023, 1, 1)); // Original date preserved
    });

    group('Season Status Clearing Hierarchy Tests', () {
      test('Watched clears In progress & Want to watch for seasons', () async {
        final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        final repo = SeasonStatusRepository(box);

        await repo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );

        // Add Want to watch status
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        var season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.inProgress);

        // Add Watched status (should clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.watched);
      });

      test('In progress clears Want to watch for seasons', () async {
        final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        final repo = SeasonStatusRepository(box);

        await repo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );

        // Add Want to watch status
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        var season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.wantToWatch);

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.inProgress);
      });

      test('Want to watch clears In progress for seasons', () async {
        final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        final repo = SeasonStatusRepository(box);

        await repo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );

        // Add In progress status
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        var season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.inProgress);

        // Add Want to watch status (should clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.wantToWatch);
      });

      test('Re-marking cleared statuses works for seasons', () async {
        final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        final repo = SeasonStatusRepository(box);

        await repo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );

        // Mark as Watched
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        var season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 1);
        expect(season.statusRecords.first.status, WatchStatus.watched);

        // Re-mark as Want to watch (should work)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 2);
        expect(season.statusRecords.any((r) => r.status == WatchStatus.watched), true);
        expect(season.statusRecords.any((r) => r.status == WatchStatus.wantToWatch), true);
      });

      test('DNF does not clear other statuses for seasons', () async {
        final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
        final repo = SeasonStatusRepository(box);

        await repo.getOrCreateSeason(
          showId: 123,
          seasonNumber: 1,
        );

        // Add In progress status
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        // Add DNF status (should not clear In progress)
        await repo.addStatusRecord(
          123,
          1,
          StatusRecord(status: WatchStatus.dnf, setAt: DateTime.now()),
        );

        final season = repo.getSeason(123, 1);
        expect(season!.statusRecords.length, 2);
        expect(season.statusRecords.any((r) => r.status == WatchStatus.inProgress), true);
        expect(season.statusRecords.any((r) => r.status == WatchStatus.dnf), true);
      });
    });

    test('getSeasonsByShow returns all seasons for show', () async {
      final box = await Hive.openBox<SeasonStatusEntry>('test_seasons');
      final repo = SeasonStatusRepository(box);

      // Create seasons for show 123
      await repo.getOrCreateSeason(showId: 123, seasonNumber: 1);
      await repo.getOrCreateSeason(showId: 123, seasonNumber: 2);
      await repo.getOrCreateSeason(showId: 123, seasonNumber: 0); // Specials

      // Create season for different show
      await repo.getOrCreateSeason(showId: 456, seasonNumber: 1);

      final seasons = repo.getSeasonsByShow(123);
      expect(seasons.length, 3);
      expect(seasons.every((s) => s.showId == 123), true);
    });
  });
}