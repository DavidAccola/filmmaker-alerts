import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/ui/common/watchlist_card.dart';
import 'package:filmmaker_alerts/ui/common/rewatch_dialog.dart';

void main() {
  group('WatchlistCard Widget Tests', () {
    late WatchlistEntry testEntry;

    setUp(() {
      testEntry = WatchlistEntry(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
        posterPath: '/test.jpg',
        releaseDate: DateTime(2024, 1, 1),
        releaseType: ReleaseType.theatrical,
        addedAt: DateTime.now(),
        addRank: 1,
        userRank: null,
        isSnoozed: false,
        notificationsSnoozed: false,
        overriddenGenre: null,
        genreListId: null,
        followedContributors: [],
        statusRecords: [
          StatusRecord(
            status: WatchStatus.wantToWatch,
            setAt: DateTime.now(),
            watchDates: null,
          ),
        ],
      );
    });

    testWidgets('displays movie title and poster', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      expect(find.text('Test Movie'), findsOneWidget);
    });

    testWidgets('shows notification snooze indicator when notifications are snoozed',
        (WidgetTester tester) async {
      testEntry.notificationsSnoozed = true;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    });

    testWidgets('displays correct media type icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.movie), findsOneWidget);

      // Test TV show icon
      testEntry.type = WorkType.tvShow;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.tv), findsOneWidget);
    });

    testWidgets('status bar shows correct active states', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      // Want to watch should be active
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('shows watch count for multiple watches', (WidgetTester tester) async {
      testEntry = WatchlistEntry(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
        posterPath: '/test.jpg',
        releaseDate: DateTime(2024, 1, 1),
        releaseType: ReleaseType.theatrical,
        addedAt: DateTime.now(),
        addRank: 1,
        statusRecords: [
          StatusRecord(
            status: WatchStatus.watched,
            setAt: DateTime.now(),
            watchDates: [
              DateTime(2024, 1, 1),
              DateTime(2024, 2, 1),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      expect(find.text('x2'), findsOneWidget);
    });

    testWidgets('three-dot menu shows all options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: testEntry),
            ),
          ),
        ),
      );

      // Find and tap the three-dot menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Snooze'), findsOneWidget);
      expect(find.text('Snooze Notifications'), findsOneWidget);
      expect(find.text('Did not finish'), findsOneWidget);
    });

    testWidgets('calls onStatusChanged when status button is tapped',
        (WidgetTester tester) async {
      WatchStatus? changedStatus;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(
                entry: testEntry,
                onStatusChanged: (status) {
                  changedStatus = status;
                },
              ),
            ),
          ),
        ),
      );

      // Tap the in progress button
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();

      expect(changedStatus, WatchStatus.inProgress);
    });
  });

  group('ReWatchDialog Widget Tests', () {
    testWidgets('displays existing watch dates', (WidgetTester tester) async {
      final watchDates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReWatchDialog(
              existingWatchDates: watchDates,
              lastWatchDate: watchDates.last,
            ),
          ),
        ),
      );

      expect(find.text('Watch 1'), findsOneWidget);
      expect(find.text('Watch 2'), findsOneWidget);
    });

    testWidgets('shows edit mode when less than 12 hours since last watch',
        (WidgetTester tester) async {
      final recentWatch = DateTime.now().subtract(const Duration(hours: 6));
      final watchDates = [recentWatch];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReWatchDialog(
              existingWatchDates: watchDates,
              lastWatchDate: recentWatch,
            ),
          ),
        ),
      );

      expect(find.text('Edit Watch'), findsOneWidget);
      expect(find.text('Edit your most recent watch:'), findsOneWidget);
    });

    testWidgets('shows all watches mode when more than 12 hours since last watch',
        (WidgetTester tester) async {
      final oldWatch = DateTime.now().subtract(const Duration(hours: 24));
      final watchDates = [oldWatch];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReWatchDialog(
              existingWatchDates: watchDates,
              lastWatchDate: oldWatch,
            ),
          ),
        ),
      );

      expect(find.text('Watch History'), findsOneWidget);
      expect(find.text('All watches:'), findsOneWidget);
    });

    testWidgets('can add new watch', (WidgetTester tester) async {
      final watchDates = [DateTime(2024, 1, 1)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReWatchDialog(
              existingWatchDates: watchDates,
              lastWatchDate: watchDates.last,
            ),
          ),
        ),
      );

      // Initially one watch
      expect(find.text('Watch 1'), findsOneWidget);
      expect(find.text('Watch 2'), findsNothing);

      // Tap add button
      await tester.tap(find.text('Add Watch'));
      await tester.pumpAndSettle();

      // Now two watches
      expect(find.text('Watch 1'), findsOneWidget);
      expect(find.text('Watch 2'), findsOneWidget);
    });

    testWidgets('can remove watch when multiple exist', (WidgetTester tester) async {
      final watchDates = [
        DateTime(2024, 1, 1),
        DateTime(2024, 2, 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReWatchDialog(
              existingWatchDates: watchDates,
              lastWatchDate: watchDates.last,
            ),
          ),
        ),
      );

      // Initially two watches
      expect(find.text('Watch 1'), findsOneWidget);
      expect(find.text('Watch 2'), findsOneWidget);

      // Tap delete button for first watch
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // Now only one watch
      expect(find.text('Watch 1'), findsOneWidget);
      expect(find.text('Watch 2'), findsNothing);
    });

    testWidgets('returns updated dates when saved', (WidgetTester tester) async {
      final watchDates = [DateTime(2024, 1, 1)];
      List<DateTime>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<List<DateTime>>(
                      context: context,
                      builder: (context) => ReWatchDialog(
                        existingWatchDates: watchDates,
                        lastWatchDate: watchDates.last,
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.length, 1);
    });
  });

  group('Status Hierarchy Tests', () {
    testWidgets('marking watched clears in progress and want to watch',
        (WidgetTester tester) async {
      final entry = WatchlistEntry(
        tmdbId: 123,
        type: WorkType.movie,
        title: 'Test Movie',
        posterPath: '/test.jpg',
        releaseDate: DateTime(2024, 1, 1),
        releaseType: ReleaseType.theatrical,
        addedAt: DateTime.now(),
        addRank: 1,
        statusRecords: [
          StatusRecord(
            status: WatchStatus.wantToWatch,
            setAt: DateTime.now(),
            watchDates: null,
          ),
          StatusRecord(
            status: WatchStatus.inProgress,
            setAt: DateTime.now(),
            watchDates: null,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WatchlistCard(entry: entry),
            ),
          ),
        ),
      );

      // Both want to watch and in progress should be active
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.play_circle), findsOneWidget);
    });
  });
}
