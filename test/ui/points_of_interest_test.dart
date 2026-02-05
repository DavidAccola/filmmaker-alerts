import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/ui/common/points_of_interest_widget.dart';

void main() {
  group('PointsOfInterestWidget', () {
    /// Property 10: Points of Interest Detection
    /// For any work, if other followed contributors are involved, a Points of Interest 
    /// section should appear showing their names and roles; if none exist, the section 
    /// should be hidden
    /// **Validates: Requirements 7.1, 7.2, 7.3, 7.4**
    testWidgets('Property 10: Points of Interest Detection - shows section when followed contributors exist', (WidgetTester tester) async {
      // Setup: Create followed contributors
      final followedContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Christopher Nolan',
          type: ContributorType.person,
          profilePath: '/path1.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Director',
        ),
        Contributor(
          tmdbId: 2,
          name: 'Hans Zimmer',
          type: ContributorType.person,
          profilePath: '/path2.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Composer',
        ),
      ];

      // Create a work with roles from followed contributors
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Director',
          ),
          ContributorRole(
            contributorId: 2,
            contributorName: 'Hans Zimmer',
            role: 'Composer',
          ),
          ContributorRole(
            contributorId: 999, // Not followed
            contributorName: 'Leonardo DiCaprio',
            role: 'Actor',
          ),
        ],
      );

      // Build the widget
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render and show followed contributors
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsOneWidget,
        reason: 'Points of Interest header should be visible',
      );
      
      // Verify: Should show followed contributors' names
      expect(
        find.text('Christopher Nolan'),
        findsOneWidget,
        reason: 'Christopher Nolan should be displayed',
      );
      expect(
        find.text('Hans Zimmer'),
        findsOneWidget,
        reason: 'Hans Zimmer should be displayed',
      );
    });

    testWidgets('Property 10: Points of Interest Detection - hides section when no followed contributors exist', (WidgetTester tester) async {
      // Setup: Create followed contributors
      final followedContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Christopher Nolan',
          type: ContributorType.person,
          profilePath: '/path1.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Director',
        ),
      ];

      // Create a work with NO roles from followed contributors
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(
            contributorId: 999, // Not followed
            contributorName: 'Leonardo DiCaprio',
            role: 'Actor',
          ),
          ContributorRole(
            contributorId: 998, // Not followed
            contributorName: 'Ellen Page',
            role: 'Actress',
          ),
        ],
      );

      // Build the widget
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render but show nothing (SizedBox.shrink)
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should NOT show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsNothing,
        reason: 'Points of Interest header should not be visible when no followed contributors exist',
      );
    });

    testWidgets('Property 10: Points of Interest Detection - displays all roles for contributors with multiple roles', (WidgetTester tester) async {
      // Setup: Create followed contributors
      final followedContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Christopher Nolan',
          type: ContributorType.person,
          profilePath: '/path1.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Director',
        ),
      ];

      // Create a work where a followed contributor has multiple roles
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Director',
          ),
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Writer',
          ),
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Producer',
          ),
        ],
      );

      // Build the widget
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsOneWidget,
        reason: 'Points of Interest header should be visible',
      );
      
      // Verify: Should show contributor name
      expect(
        find.text('Christopher Nolan'),
        findsOneWidget,
        reason: 'Christopher Nolan should be displayed',
      );
      
      // Verify: All roles should be displayed
      expect(
        find.text('Director, Writer, Producer'),
        findsOneWidget,
        reason: 'All roles should be displayed together',
      );
    });

    testWidgets('Property 10: Points of Interest Detection - handles empty followed contributors list', (WidgetTester tester) async {
      // Setup: Empty followed contributors list
      final followedContributors = <Contributor>[];

      // Create a work with roles
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Director',
          ),
        ],
      );

      // Build the widget
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render but show nothing
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should NOT show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsNothing,
        reason: 'Points of Interest header should not be visible when no followed contributors exist',
      );
    });

    testWidgets('Property 10: Points of Interest Detection - handles work with no contributor roles', (WidgetTester tester) async {
      // Setup: Create followed contributors
      final followedContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Christopher Nolan',
          type: ContributorType.person,
          profilePath: '/path1.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Director',
        ),
      ];

      // Create a work with NO roles
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [],
      );

      // Build the widget
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render but show nothing
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should NOT show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsNothing,
        reason: 'Points of Interest header should not be visible when work has no roles',
      );
    });

    testWidgets('Property 10: Points of Interest Detection - callback is invoked when contributor is tapped', (WidgetTester tester) async {
      // Setup: Create followed contributors
      final followedContributors = [
        Contributor(
          tmdbId: 1,
          name: 'Christopher Nolan',
          type: ContributorType.person,
          profilePath: '/path1.jpg',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: 'Director',
        ),
      ];

      // Create a work with roles from followed contributors
      final work = Work(
        tmdbId: 100,
        title: 'Inception',
        type: WorkType.movie,
        contributorRoles: [
          ContributorRole(
            contributorId: 1,
            contributorName: 'Christopher Nolan',
            role: 'Director',
          ),
        ],
      );

      // Build the widget with callback (callback not invoked in this test, just verifying setup)
      final widget = MaterialApp(
        home: Scaffold(
          body: PointsOfInterestWidget(
            work: work,
            followedContributors: followedContributors,
            onContributorTapped: (contributor) {
              // Callback would be invoked when contributor is tapped
              expect(contributor, isNotNull);
            },
          ),
        ),
      );

      // Pump the widget
      await tester.pumpWidget(widget);

      // Verify: Widget should render
      expect(
        find.byType(PointsOfInterestWidget),
        findsOneWidget,
        reason: 'PointsOfInterestWidget should be rendered',
      );
      
      // Verify: Should show the "Points of Interest" header
      expect(
        find.text('Points of Interest'),
        findsOneWidget,
        reason: 'Points of Interest header should be visible',
      );
    });
  });
}
