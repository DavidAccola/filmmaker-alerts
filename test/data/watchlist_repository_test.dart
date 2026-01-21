import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/repositories/watchlist_repository.dart';

void main() {
  setUpAll(() {
    // Register adapters once for all tests
    Hive.registerAdapter(WatchlistEntryAdapter());
    Hive.registerAdapter(ContributorSnapshotAdapter());
    Hive.registerAdapter(StatusRecordAdapter());
    Hive.registerAdapter(WatchStatusAdapter());
    Hive.registerAdapter(WorkTypeAdapter());
    Hive.registerAdapter(ReleaseTypeAdapter());
  });

  group('WatchlistRepository', () {
    setUp(() async {
      await setUpTestHive();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('addWork creates entry with default Want to watch status', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
      );

      final entry = repo.getWork(123, WorkType.movie);
      expect(entry, isNotNull);
      expect(entry!.title, 'Test Movie');
      expect(entry.statusRecords.length, 1);
      expect(entry.statusRecords.first.status, WatchStatus.wantToWatch);
    });

    test('addWork assigns sequential addRank', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(tmdbId: 1, type: WorkType.movie, title: 'Movie 1');
      await repo.addWork(tmdbId: 2, type: WorkType.movie, title: 'Movie 2');
      await repo.addWork(tmdbId: 3, type: WorkType.movie, title: 'Movie 3');

      final entry1 = repo.getWork(1, WorkType.movie);
      final entry2 = repo.getWork(2, WorkType.movie);
      final entry3 = repo.getWork(3, WorkType.movie);

      expect(entry1!.addRank, 1);
      expect(entry2!.addRank, 2);
      expect(entry3!.addRank, 3);
    });

    test('removeWork deletes entry', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');
      expect(repo.getWork(123, WorkType.movie), isNotNull);

      await repo.removeWork(123, WorkType.movie);
      expect(repo.getWork(123, WorkType.movie), isNull);
    });

    test('addStatusRecord clears conflicting statuses', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

      // Add In progress status (should clear Want to watch)
      await repo.addStatusRecord(
        123,
        WorkType.movie,
        StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
      );

      var entry = repo.getWork(123, WorkType.movie);
      expect(entry!.statusRecords.length, 1);
      expect(entry.statusRecords.first.status, WatchStatus.inProgress);

      // Add Watched status (should clear In progress)
      await repo.addStatusRecord(
        123,
        WorkType.movie,
        StatusRecord(
          status: WatchStatus.watched,
          setAt: DateTime.now(),
          watchDates: [DateTime.now()],
        ),
      );

      entry = repo.getWork(123, WorkType.movie);
      expect(entry!.statusRecords.length, 1);
      expect(entry.statusRecords.first.status, WatchStatus.watched);
    });

    test('setSnoozed updates snoozed status', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');
      await repo.setSnoozed(123, WorkType.movie, true);

      final entry = repo.getWork(123, WorkType.movie);
      expect(entry!.isSnoozed, true);
    });

    test('updateUserRank updates rank', () async {
      final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
      final repo = WatchlistRepository(box);

      await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');
      await repo.updateUserRank(123, WorkType.movie, 5);

      final entry = repo.getWork(123, WorkType.movie);
      expect(entry!.userRank, 5);
    });

    group('Status Clearing Hierarchy Tests', () {
      test('Watched clears In progress & Want to watch', () async {
        final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final repo = WatchlistRepository(box);

        await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        // Add Want to watch status back (should clear In progress)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        var entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.wantToWatch);

        // Add In progress again
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.inProgress);

        // Add Watched status (should clear In progress)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.watched);
      });

      test('In progress clears Want to watch', () async {
        final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final repo = WatchlistRepository(box);

        await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

        // Initially has Want to watch
        var entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.wantToWatch);

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.inProgress);
      });

      test('Want to watch clears In progress', () async {
        final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final repo = WatchlistRepository(box);

        await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

        // Add In progress status (should clear Want to watch)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        var entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.inProgress);

        // Add Want to watch status (should clear In progress)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.wantToWatch);
      });

      test('Re-marking cleared statuses works', () async {
        final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final repo = WatchlistRepository(box);

        await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

        // Mark as Watched (clears Want to watch)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [DateTime.now()],
          ),
        );

        var entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 1);
        expect(entry.statusRecords.first.status, WatchStatus.watched);

        // Re-mark as Want to watch (should work)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now()),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 2);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.watched), true);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.wantToWatch), true);

        // Re-mark as In progress (should clear Want to watch but keep Watched)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 2);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.watched), true);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.inProgress), true);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.wantToWatch), false);
      });

      test('DNF does not clear other statuses', () async {
        final box = await Hive.openBox<WatchlistEntry>('test_watchlist');
        final repo = WatchlistRepository(box);

        await repo.addWork(tmdbId: 123, type: WorkType.movie, title: 'Test Movie');

        // Add In progress status
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.inProgress, setAt: DateTime.now()),
        );

        // Add DNF status (should not clear In progress)
        await repo.addStatusRecord(
          123,
          WorkType.movie,
          StatusRecord(status: WatchStatus.dnf, setAt: DateTime.now()),
        );

        final entry = repo.getWork(123, WorkType.movie);
        expect(entry!.statusRecords.length, 2);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.inProgress), true);
        expect(entry.statusRecords.any((r) => r.status == WatchStatus.dnf), true);
      });
    });
  });
}
