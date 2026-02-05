import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:filmmaker_alerts/data/models/episode_status_entry.dart';
import 'package:filmmaker_alerts/data/models/season_status_entry.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/data/models/tv_detail.dart';
import 'package:filmmaker_alerts/data/repositories/episode_status_repository.dart';
import 'package:filmmaker_alerts/data/repositories/season_status_repository.dart';
import 'package:filmmaker_alerts/data/repositories/tv_detail_repository.dart';
import 'package:filmmaker_alerts/logic/watchlist_logic.dart';
import 'package:filmmaker_alerts/logic/work_logic.dart';
import 'package:filmmaker_alerts/providers/providers.dart';
import 'package:filmmaker_alerts/ui/screens/show_configuration_screen.dart';

@GenerateMocks([
  EpisodeStatusRepository,
  SeasonStatusRepository,
  TvDetailRepository,
  WatchlistLogic,
  WorkLogic,
])
import 'show_configuration_screen_test.mocks.dart';

void main() {
  late MockEpisodeStatusRepository mockEpisodeRepo;
  late MockSeasonStatusRepository mockSeasonRepo;
  late MockTvDetailRepository mockTvDetailRepo;
  late MockWatchlistLogic mockWatchlistLogic;
  late MockWorkLogic mockWorkLogic;

  const testShowId = 123;
  const testShowTitle = 'Test Show';

  // Helper to create test episodes
  List<EpisodeStatusEntry> createTestEpisodes({
    required int seasonNumber,
    required int count,
    List<int> markedEpisodes = const [],
    WatchStatus status = WatchStatus.watched,
  }) {
    return List.generate(count, (index) {
      final episodeNumber = index + 1;
      final isMarked = markedEpisodes.contains(episodeNumber);
      return EpisodeStatusEntry(
        showId: testShowId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: 'Episode $episodeNumber',
        statusRecords: isMarked
            ? [StatusRecord(status: status, setAt: DateTime.now())]
            : [],
      );
    });
  }

  // Helper to create TvShowDetail
  TvShowDetail createTestShowDetail({
    List<int> seasonNumbers = const [1, 2],
    int episodesPerSeason = 5,
  }) {
    return TvShowDetail(
      tmdbId: testShowId,
      name: testShowTitle,
      synopsis: 'Test synopsis',
      seasons: seasonNumbers
          .map((seasonNum) => TvSeason(
                tmdbId: seasonNum * 100,
                name: 'Season $seasonNum',
                seasonNumber: seasonNum,
                episodeCount: episodesPerSeason,
              ))
          .toList(),
    );
  }

  // Helper to create TvSeasonDetail
  TvSeasonDetail createTestSeasonDetail({
    required int seasonNumber,
    required int episodeCount,
  }) {
    return TvSeasonDetail(
      tmdbId: seasonNumber * 100,
      name: 'Season $seasonNumber',
      seasonNumber: seasonNumber,
      episodes: List.generate(
        episodeCount,
        (index) => SeasonEpisode(
          tmdbId: seasonNumber * 1000 + index + 1,
          episodeNumber: index + 1,
          name: 'Episode ${index + 1}',
        ),
      ),
    );
  }

  setUp(() {
    mockEpisodeRepo = MockEpisodeStatusRepository();
    mockSeasonRepo = MockSeasonStatusRepository();
    mockTvDetailRepo = MockTvDetailRepository();
    mockWatchlistLogic = MockWatchlistLogic();
    mockWorkLogic = MockWorkLogic();
  });

  Widget createTestWidget({
    List<EpisodeStatusEntry> markedEpisodes = const [],
    List<SeasonStatusEntry> markedSeasons = const [],
    TvShowDetail? showDetail,
    Map<int, TvSeasonDetail>? seasonDetails,
    Size screenSize = const Size(800, 600), // Default to desktop size
  }) {
    // Default show detail with 2 seasons, 5 episodes each
    final testShowDetail = showDetail ?? createTestShowDetail();
    final testSeasonDetails = seasonDetails ??
        {
          1: createTestSeasonDetail(seasonNumber: 1, episodeCount: 5),
          2: createTestSeasonDetail(seasonNumber: 2, episodeCount: 5),
        };

    // Setup mocks
    when(mockEpisodeRepo.getEpisodesByShow(testShowId))
        .thenReturn(markedEpisodes);
    when(mockSeasonRepo.getSeasonsByShow(testShowId))
        .thenReturn(markedSeasons);
    when(mockTvDetailRepo.getTvShowDetail(testShowId))
        .thenReturn(testShowDetail);

    for (final entry in testSeasonDetails.entries) {
      when(mockTvDetailRepo.getTvSeasonDetail(testShowId, entry.key))
          .thenReturn(entry.value);
    }

    // Setup episode repo getEpisode for each episode
    for (final season in testShowDetail.seasons) {
      final seasonDetail = testSeasonDetails[season.seasonNumber];
      if (seasonDetail != null) {
        for (final episode in seasonDetail.episodes) {
          final markedEpisode = markedEpisodes.cast<EpisodeStatusEntry?>().firstWhere(
            (e) =>
                e != null &&
                e.seasonNumber == season.seasonNumber &&
                e.episodeNumber == episode.episodeNumber,
            orElse: () => null,
          );
          when(mockEpisodeRepo.getEpisode(
            testShowId,
            season.seasonNumber,
            episode.episodeNumber,
          )).thenReturn(markedEpisode);
        }
      }
    }

    // Setup work logic mock
    when(mockWorkLogic.fetchAndCacheTvShowDetail(testShowId))
        .thenAnswer((_) async => testShowDetail);
    for (final entry in testSeasonDetails.entries) {
      when(mockWorkLogic.fetchAndCacheTvSeasonDetail(
        showId: testShowId,
        seasonNumber: entry.key,
      )).thenAnswer((_) async => entry.value);
    }

    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: ProviderScope(
        overrides: [
          episodeStatusRepositoryProvider.overrideWithValue(mockEpisodeRepo),
          seasonStatusRepositoryProvider.overrideWithValue(mockSeasonRepo),
          tvDetailRepositoryProvider.overrideWithValue(mockTvDetailRepo),
          watchlistLogicProvider.overrideWithValue(mockWatchlistLogic),
          workLogicProvider.overrideWithValue(mockWorkLogic),
        ],
        child: MaterialApp(
          home: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: ShowConfigurationScreen(
              showId: testShowId,
              showTitle: testShowTitle,
            ),
          ),
        ),
      ),
    );
  }

  // Helper to find checkbox by its position in the widget tree
  Finder findCheckboxAt(int index) => find.byType(Checkbox).at(index);

  // Helper to tap a checkbox directly (not the surrounding InkWell)
  Future<void> tapCheckbox(WidgetTester tester, int index) async {
    final checkbox = find.byType(Checkbox).at(index);
    // Find the center of the checkbox and tap it
    await tester.tap(checkbox);
  }

  group('9.1 Tri-state checkbox computation logic', () {
    // **Validates: Requirements US-1, US-2**

    testWidgets(
        '_computeSeasonCheckboxState returns false when no episodes are marked',
        (WidgetTester tester) async {
      // All episodes unmarked - season checkbox should be unchecked (false)
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find season 1 checkbox - should be unchecked
      final season1Row = find.text('Season 1');
      expect(season1Row, findsOneWidget);

      // The checkbox in the season row should be unchecked (value = false)
      // Checkboxes order: Mark All (0), Season 1 (1), Season 2 (2)
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, false,
          reason: 'Season checkbox should be false when no episodes are marked');
    });

    testWidgets(
        '_computeSeasonCheckboxState returns true when all episodes are marked',
        (WidgetTester tester) async {
      // All 5 episodes in season 1 are marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2, 3, 4, 5],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, true,
          reason:
              'Season checkbox should be true when all episodes are marked');
    });

    testWidgets(
        '_computeSeasonCheckboxState returns null (indeterminate) when some episodes are marked',
        (WidgetTester tester) async {
      // Only episodes 1 and 2 of 5 are marked in season 1
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, null,
          reason:
              'Season checkbox should be null (indeterminate) when some episodes are marked');
    });

    testWidgets(
        '_computeShowCheckboxState returns false when no episodes are marked',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // First checkbox is "Mark All" (show-level)
      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, false,
          reason: 'Show checkbox should be false when no episodes are marked');
    });

    testWidgets(
        '_computeShowCheckboxState returns true when all episodes in all seasons are marked',
        (WidgetTester tester) async {
      // All episodes in both seasons are marked
      final markedEpisodes = [
        ...createTestEpisodes(
          seasonNumber: 1,
          count: 5,
          markedEpisodes: [1, 2, 3, 4, 5],
        ),
        ...createTestEpisodes(
          seasonNumber: 2,
          count: 5,
          markedEpisodes: [1, 2, 3, 4, 5],
        ),
      ];

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, true,
          reason:
              'Show checkbox should be true when all episodes are marked');
    });

    testWidgets(
        '_computeShowCheckboxState returns null (indeterminate) when some episodes are marked',
        (WidgetTester tester) async {
      // Only some episodes in season 1 are marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2, 3],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, null,
          reason:
              'Show checkbox should be null (indeterminate) when some episodes are marked');
    });
  });

  group('9.2 Episode marking/unmarking updates parent states', () {
    // **Validates: Requirements US-3**

    testWidgets(
        'Marking single episode makes season checkbox indeterminate',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand season 1 to see episodes
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // After expanding, checkboxes are: Mark All (0), Season 1 (1), Ep1 (2), Ep2 (3), ..., Season 2 (7)
      // Tap episode 1 checkbox
      await tester.tap(findCheckboxAt(2));
      await tester.pumpAndSettle();

      // Season 1 checkbox should now be indeterminate (null)
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, null,
          reason:
              'Season checkbox should become indeterminate when one episode is marked');

      // Show checkbox should also be indeterminate
      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, null,
          reason:
              'Show checkbox should become indeterminate when one episode is marked');
    });

    testWidgets(
        'Marking all episodes makes season checkbox checked',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Mark all 5 episodes in season 1 (indices 2-6)
      for (int i = 2; i <= 6; i++) {
        await tester.tap(findCheckboxAt(i));
        await tester.pumpAndSettle();
      }

      // Season 1 checkbox should now be checked (true)
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, true,
          reason:
              'Season checkbox should be checked when all episodes are marked');
    });

    testWidgets(
        'Unmarking all episodes makes season checkbox unchecked',
        (WidgetTester tester) async {
      // Start with all episodes in season 1 marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2, 3, 4, 5],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Unmark all 5 episodes (indices 2-6)
      for (int i = 2; i <= 6; i++) {
        await tester.tap(findCheckboxAt(i));
        await tester.pumpAndSettle();
      }

      // Season 1 checkbox should now be unchecked (false)
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, false,
          reason:
              'Season checkbox should be unchecked when all episodes are unmarked');
    });
  });

  group('9.3 Season marking marks all episodes', () {
    // **Validates: Requirements US-2**
    
    // Note: Flutter's tri-state Checkbox behavior:
    // - Clicking false → onChanged(true)
    // - Clicking true → onChanged(null) if tristate, else onChanged(false)
    // - Clicking null → onChanged(false)
    //
    // The implementation's _handleSeasonCheckboxChanged uses the NEW value:
    // - value != true means "should mark"
    // - value == true means "should clear"
    //
    // So clicking an unchecked (false) checkbox:
    // - onChanged receives true
    // - shouldMark = (true != true) = false
    // - This CLEARS instead of marking - this appears to be inverted logic
    //
    // For now, we test the ACTUAL behavior of the implementation.

    testWidgets(
        'Clicking unchecked season checkbox marks all episodes in that season',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify season 1 checkbox starts unchecked
      final initialCheckbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(initialCheckbox.value, false,
          reason: 'Season checkbox should start unchecked');

      // Click season 1 checkbox
      await tapCheckbox(tester, 1);
      await tester.pumpAndSettle();

      // After clicking, season 1 checkbox should be checked (all episodes marked)
      final updatedCheckbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(updatedCheckbox.value, true,
          reason: 'Season checkbox should be checked after clicking unchecked');

      // Expand season 1 to verify all episodes are marked
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // All episode checkboxes should be checked (indices 2-6)
      for (int i = 2; i <= 6; i++) {
        final episodeCheckbox = tester.widget<Checkbox>(findCheckboxAt(i));
        expect(episodeCheckbox.value, true,
            reason: 'Episode ${i - 1} should be marked');
      }
    });

    testWidgets(
        'Clicking indeterminate season checkbox marks all remaining episodes',
        (WidgetTester tester) async {
      // Start with some episodes marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2], // Only first 2 marked
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Season 1 checkbox should be indeterminate
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, null,
          reason: 'Season checkbox should start as indeterminate');

      // Click the indeterminate season checkbox
      await tapCheckbox(tester, 1);
      await tester.pumpAndSettle();

      // Season 1 checkbox should now be checked (all episodes marked)
      final updatedSeason1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(updatedSeason1Checkbox.value, true,
          reason:
              'Season checkbox should be checked after clicking indeterminate');
    });

    testWidgets(
        'Clicking checked season checkbox clears all episode statuses',
        (WidgetTester tester) async {
      // Start with all episodes marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2, 3, 4, 5],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Season 1 checkbox should be checked
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, true,
          reason: 'Season checkbox should start as checked');

      // Click the checked season checkbox to clear
      await tapCheckbox(tester, 1);
      await tester.pumpAndSettle();

      // Season 1 checkbox should now be unchecked
      final updatedSeason1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(updatedSeason1Checkbox.value, false,
          reason: 'Season checkbox should be unchecked after clicking checked');
    });
  });

  group('9.4 Show marking marks all seasons and episodes', () {
    // **Validates: Requirements US-1**

    testWidgets(
        'Clicking unchecked show checkbox marks all episodes in all seasons',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify show checkbox starts unchecked
      final initialCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(initialCheckbox.value, false,
          reason: 'Show checkbox should start unchecked');

      // Click "Mark All" checkbox (show-level) - index 0
      await tapCheckbox(tester, 0);
      await tester.pumpAndSettle();

      // Show checkbox should now be checked
      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, true,
          reason: 'Show checkbox should be checked after clicking');

      // Both season checkboxes should be checked
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      final season2Checkbox = tester.widget<Checkbox>(findCheckboxAt(2));
      expect(season1Checkbox.value, true,
          reason: 'Season 1 checkbox should be checked');
      expect(season2Checkbox.value, true,
          reason: 'Season 2 checkbox should be checked');
    });

    testWidgets(
        'Clicking indeterminate show checkbox marks all remaining episodes',
        (WidgetTester tester) async {
      // Start with some episodes marked in season 1 only
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2],
      );

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Show checkbox should be indeterminate
      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, null,
          reason: 'Show checkbox should start as indeterminate');

      // Click the indeterminate show checkbox
      await tapCheckbox(tester, 0);
      await tester.pumpAndSettle();

      // Show checkbox should now be checked
      final updatedShowCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(updatedShowCheckbox.value, true,
          reason:
              'Show checkbox should be checked after clicking indeterminate');
    });

    testWidgets(
        'Clicking checked show checkbox clears all episode statuses',
        (WidgetTester tester) async {
      // Start with all episodes marked in both seasons
      final markedEpisodes = [
        ...createTestEpisodes(
          seasonNumber: 1,
          count: 5,
          markedEpisodes: [1, 2, 3, 4, 5],
        ),
        ...createTestEpisodes(
          seasonNumber: 2,
          count: 5,
          markedEpisodes: [1, 2, 3, 4, 5],
        ),
      ];

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Show checkbox should be checked
      final showCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(showCheckbox.value, true,
          reason: 'Show checkbox should start as checked');

      // Click the checked show checkbox to clear
      await tapCheckbox(tester, 0);
      await tester.pumpAndSettle();

      // Show checkbox should now be unchecked
      final updatedShowCheckbox = tester.widget<Checkbox>(findCheckboxAt(0));
      expect(updatedShowCheckbox.value, false,
          reason: 'Show checkbox should be unchecked after clicking checked');

      // Both season checkboxes should be unchecked
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      final season2Checkbox = tester.widget<Checkbox>(findCheckboxAt(2));
      expect(season1Checkbox.value, false,
          reason: 'Season 1 checkbox should be unchecked');
      expect(season2Checkbox.value, false,
          reason: 'Season 2 checkbox should be unchecked');
    });
  });


  group('9.5 Status selector change does not affect existing marks', () {
    // **Validates: Requirements US-4**

    testWidgets(
        'Changing status selector does not modify existing pending changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Mark first episode with "Watched" status (default)
      await tester.tap(findCheckboxAt(2)); // Episode 1
      await tester.pumpAndSettle();

      // Verify episode is marked with "Watched" symbol (✓)
      expect(find.text('✓'), findsOneWidget,
          reason: 'Episode should show Watched symbol');

      // Change status selector to "In Progress" using SegmentedButton
      // On desktop (800x600), it uses SegmentedButton with text like "▶ In Progress"
      final inProgressSegment = find.text('▶ In Progress');
      expect(inProgressSegment, findsOneWidget,
          reason: 'Should find In Progress segment on desktop');
      await tester.tap(inProgressSegment);
      await tester.pumpAndSettle();

      // The existing marked episode should still show "Watched" symbol
      expect(find.text('✓'), findsOneWidget,
          reason:
              'Existing mark should retain Watched status after selector change');
    });

    testWidgets(
        'New marks use the newly selected status',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Change status selector to "In Progress" first
      final inProgressSegment = find.text('▶ In Progress');
      await tester.tap(inProgressSegment);
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Mark first episode
      await tester.tap(findCheckboxAt(2)); // Episode 1
      await tester.pumpAndSettle();

      // Verify episode is marked with "In Progress" symbol (▶)
      // The status selector also shows ▶, so we check for 2 occurrences
      // One in the selector segment, one in the episode row
      // The segment shows "▶ In Progress" so we need to check differently
      // The episode row shows just "▶"
      expect(find.text('▶').evaluate().isNotEmpty, true,
          reason: 'Should have In Progress symbol');
    });

    testWidgets(
        'Existing marks retain their original status when new marks are added',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Mark episode 1 with "Watched" (default)
      await tester.tap(findCheckboxAt(2)); // Episode 1
      await tester.pumpAndSettle();

      // Verify episode 1 shows Watched symbol
      expect(find.text('✓'), findsOneWidget);

      // Change status selector to "Want to Watch"
      final wantToWatchSegment = find.text('📖 Want to Watch');
      await tester.tap(wantToWatchSegment);
      await tester.pumpAndSettle();

      // Mark episode 2 with "Want to Watch"
      await tester.tap(findCheckboxAt(3)); // Episode 2
      await tester.pumpAndSettle();

      // Episode 1 should still show "Watched" (✓)
      // Episode 2 should show "Want to Watch" (📖)
      expect(find.text('✓'), findsOneWidget,
          reason: 'Episode 1 should retain Watched status');
      expect(find.text('📖'), findsWidgets,
          reason: 'Episode 2 should show Want to Watch status');
    });
  });

  group('9.6 Save persists changes correctly', () {
    // **Validates: Requirements US-3**
    // Note: Save tests need to handle the snackbar timer that's created on save.
    // We use addTearDown to clean up any pending timers.

    testWidgets('Save button appears when changes are made', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially, FAB should not be visible (no changes)
      expect(find.byType(FloatingActionButton), findsNothing,
          reason: 'FAB should not be visible when no changes');

      // Make a change - mark season 1
      await tapCheckbox(tester, 1); // Season 1 checkbox
      await tester.pumpAndSettle();

      // FAB should now be visible
      expect(find.byType(FloatingActionButton), findsOneWidget,
          reason: 'FAB should appear after making changes');
    });

    testWidgets('Save calls addStatusToEpisode for newly marked episodes',
        (WidgetTester tester) async {
      // Setup mock to track calls
      when(mockWatchlistLogic.addStatusToEpisode(
        any,
        any,
        any,
        any,
        watchDates: anyNamed('watchDates'),
      )).thenAnswer((_) async {});
      when(mockWatchlistLogic.removeStatusFromEpisode(any, any, any))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Mark season 1 by clicking the checkbox
      await tapCheckbox(tester, 1);
      await tester.pumpAndSettle();

      // Verify season is now checked (episodes marked)
      final season1Checkbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(season1Checkbox.value, true,
          reason: 'Season 1 should be checked after clicking');

      // Tap save FAB
      await tester.tap(find.byType(FloatingActionButton));
      // Pump to process the save
      await tester.pump();

      // Verify addStatusToEpisode was called for each episode in season 1
      verify(mockWatchlistLogic.addStatusToEpisode(
        testShowId,
        1, // season 1
        any,
        WatchStatus.watched,
        watchDates: anyNamed('watchDates'),
      )).called(5);
      
      // Clean up snackbar timer by pumping past its duration
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Save calls removeStatusFromEpisode for cleared episodes',
        (WidgetTester tester) async {
      // Start with all episodes marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1, 2, 3, 4, 5],
      );

      // Setup mocks
      when(mockWatchlistLogic.addStatusToEpisode(
        any,
        any,
        any,
        any,
        watchDates: anyNamed('watchDates'),
      )).thenAnswer((_) async {});
      when(mockWatchlistLogic.removeStatusFromEpisode(any, any, any))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Verify season 1 starts checked
      final initialCheckbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(initialCheckbox.value, true,
          reason: 'Season 1 should start checked');

      // Clear season 1 by clicking the checked checkbox (goes to null, which clears)
      await tapCheckbox(tester, 1);
      await tester.pumpAndSettle();

      // Verify season is now unchecked
      final clearedCheckbox = tester.widget<Checkbox>(findCheckboxAt(1));
      expect(clearedCheckbox.value, false,
          reason: 'Season 1 should be unchecked after clicking');

      // Tap save FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verify removeStatusFromEpisode was called for each episode
      verify(mockWatchlistLogic.removeStatusFromEpisode(
        testShowId,
        1, // season 1
        any,
      )).called(5);
      
      // Clean up snackbar timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Save handles mixed changes (mark some, clear others)',
        (WidgetTester tester) async {
      // Start with episode 1 marked
      final markedEpisodes = createTestEpisodes(
        seasonNumber: 1,
        count: 5,
        markedEpisodes: [1],
      );

      when(mockWatchlistLogic.addStatusToEpisode(
        any,
        any,
        any,
        any,
        watchDates: anyNamed('watchDates'),
      )).thenAnswer((_) async {});
      when(mockWatchlistLogic.removeStatusFromEpisode(any, any, any))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget(markedEpisodes: markedEpisodes));
      await tester.pumpAndSettle();

      // Expand season 1
      await tester.tap(find.text('Season 1'));
      await tester.pumpAndSettle();

      // Unmark episode 1 (set to null)
      await tapCheckbox(tester, 2); // Episode 1
      await tester.pumpAndSettle();

      // Mark episode 2 (set to watched)
      await tapCheckbox(tester, 3); // Episode 2
      await tester.pumpAndSettle();

      // Tap save FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verify removeStatusFromEpisode was called for episode 1
      verify(mockWatchlistLogic.removeStatusFromEpisode(
        testShowId,
        1,
        1, // episode 1
      )).called(1);

      // Verify addStatusToEpisode was called for episode 2
      verify(mockWatchlistLogic.addStatusToEpisode(
        testShowId,
        1,
        2, // episode 2
        WatchStatus.watched,
        watchDates: anyNamed('watchDates'),
      )).called(1);
      
      // Clean up snackbar timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('isDirty flag is reset after successful save',
        (WidgetTester tester) async {
      when(mockWatchlistLogic.addStatusToEpisode(
        any,
        any,
        any,
        any,
        watchDates: anyNamed('watchDates'),
      )).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Make a change
      await tapCheckbox(tester, 1); // Season 1
      await tester.pumpAndSettle();

      // FAB should be visible
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap save
      await tester.tap(find.byType(FloatingActionButton));
      
      // Pump multiple times to allow all async operations to complete
      // Each addStatusToEpisode is awaited, so we need to pump for each
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // FAB should disappear after save (isDirty = false)
      expect(find.byType(FloatingActionButton), findsNothing,
          reason: 'FAB should disappear after successful save');
      
      // Clean up snackbar timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
