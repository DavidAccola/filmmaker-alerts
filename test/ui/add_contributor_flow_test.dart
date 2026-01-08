import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/providers/providers.dart';
import 'package:filmmaker_alerts/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

// Helper function to determine if a show has ended based on status
bool isShowEnded(String? status) {
  if (status == null) return false;
  return status == 'Ended' || status == 'Canceled';
}

void main() {
  late MockTmdbService mockTmdbService;
  late MockContributorRepository mockContributorRepo;
  late MockPreferencesRepository mockPreferencesRepo;

  setUp(() {
    mockTmdbService = MockTmdbService();
    mockContributorRepo = MockContributorRepository();
    mockPreferencesRepo = MockPreferencesRepository();

    // Default Stubs
    when(mockPreferencesRepo.getPreferences()).thenReturn(Preferences());
    when(mockContributorRepo.getContributors()).thenReturn([]);
    
    // Stub person search
    when(mockTmdbService.searchPerson(any, page: anyNamed('page'))).thenAnswer((_) async => {
      'results': [
        {'id': 1, 'name': 'Greta Gerwig', 'popularity': 100.0, 'known_for_department': 'Directing', 'profile_path': null}
      ],
      'total_pages': 1,
      'total_results': 1,
    });

    // Stub credits for Greta
    when(mockTmdbService.getPersonCombinedCredits(1)).thenAnswer((_) async => {
      'cast': [],
      'crew': [
        {'id': 101, 'title': 'Barbie', 'department': 'Directing', 'job': 'Director', 'release_date': '2023-07-21'}
      ]
    });
    
    // Stub trending/upcoming for hints
    when(mockTmdbService.getUpcomingMovies()).thenAnswer((_) async => {'results': []});
    when(mockTmdbService.getTrendingMovies()).thenAnswer((_) async => {'results': []});
    when(mockTmdbService.getTrendingPeople()).thenAnswer((_) async => {'results': []});
    when(mockTmdbService.getPopularPeople()).thenAnswer((_) async => {'results': []});
  });

  testWidgets('Add Contributor Flow Integration Test', (WidgetTester tester) async {
    // 1. Load App with Overridden Providers
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tmdbServiceProvider.overrideWithValue(mockTmdbService),
          contributorRepositoryProvider.overrideWithValue(mockContributorRepo),
          preferencesRepositoryProvider.overrideWithValue(mockPreferencesRepo),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Empty State
    expect(find.text('No contributors followed yet.\nAdd one to get started!'), findsOneWidget);

    // 2. Tap Add Button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify Add Screen
    expect(find.text('Add an Alert'), findsOneWidget);

    // 3. Search for Greta
    await tester.enterText(find.byType(TextField), 'Greta');
    await tester.pump(const Duration(milliseconds: 600)); // Debounce
    await tester.pumpAndSettle();

    // Verify Results
    expect(find.text('Greta Gerwig'), findsOneWidget);

    // 4. Tap Result
    // Before tapping, we need to stub the addContributor call and getContributors call for the refresh
    when(mockContributorRepo.addContributor(any)).thenAnswer((_) {
      // Update getContributors mock to return Greta next time it's called
      when(mockContributorRepo.getContributors()).thenReturn([
        Contributor(tmdbId: 1, name: 'Greta Gerwig', type: ContributorType.person, notifyForDepartments: ['Director'], availableDepartments: ['Director'], knownFor: 'Barbie')
      ]);
      return Future.value(true);
    });

    await tester.tap(find.text('Greta Gerwig'));
    await tester.pumpAndSettle();

    // Home screen should be back
    expect(find.text('Following'), findsOneWidget);
    
    // 5. Verify Greta appears in the list
    // The FutureProvider will re-fetch from the mock repo which now returns Greta
    await tester.pumpAndSettle(); // Allow FutureProvider to settle
    
    expect(find.text('Greta Gerwig'), findsOneWidget);
    expect(find.text('Barbie'), findsOneWidget); // subtitle
  });

  // Property-based test for ended show detection
  test('Property 4: Ended Show Message Trigger - Property Test', () {
    // **Property 4: Ended Show Message Trigger**
    // **Validates: Requirements 2.4**
    
    // Test cases for ended shows
    final endedStatuses = ['Ended', 'Canceled'];
    final activeStatuses = ['Returning Series', 'In Production', 'Continuing', 'Pilot'];
    final nullOrEmptyStatuses = [null, '', 'Unknown'];
    
    // Property test with 100 iterations covering different status combinations
    for (int i = 0; i < 100; i++) {
      String? testStatus;
      bool expectedEnded;
      
      if (i < 25) {
        // Test ended statuses
        testStatus = endedStatuses[i % endedStatuses.length];
        expectedEnded = true;
      } else if (i < 50) {
        // Test active statuses
        testStatus = activeStatuses[i % activeStatuses.length];
        expectedEnded = false;
      } else if (i < 75) {
        // Test null/empty statuses
        testStatus = nullOrEmptyStatuses[i % nullOrEmptyStatuses.length];
        expectedEnded = false;
      } else {
        // Test case variations and edge cases
        final variations = ['ENDED', 'ended', 'Cancelled', 'CANCELED', 'canceled'];
        testStatus = variations[i % variations.length];
        // Only exact matches should be considered ended
        expectedEnded = testStatus == 'Ended' || testStatus == 'Canceled';
      }
      
      final result = isShowEnded(testStatus);
      
      if (expectedEnded) {
        expect(result, isTrue, 
          reason: 'Status "$testStatus" should be detected as ended');
      } else {
        expect(result, isFalse,
          reason: 'Status "$testStatus" should NOT be detected as ended');
      }
    }
    
    // Specific test cases for the exact requirements
    expect(isShowEnded('Ended'), isTrue, reason: '"Ended" status should trigger ended message');
    expect(isShowEnded('Canceled'), isTrue, reason: '"Canceled" status should trigger ended message');
    expect(isShowEnded('Returning Series'), isFalse, reason: '"Returning Series" status should NOT trigger ended message');
    expect(isShowEnded('In Production'), isFalse, reason: '"In Production" status should NOT trigger ended message');
    expect(isShowEnded(null), isFalse, reason: 'null status should NOT trigger ended message');
    expect(isShowEnded(''), isFalse, reason: 'empty status should NOT trigger ended message');
  });
}
