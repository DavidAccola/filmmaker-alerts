import 'package:filmmaker_alerts/ui/common/adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdaptiveScaffold shows NavigationBar on narrow screens', (tester) async {
    // Set small screen size (Mobile Portrait)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          body: const Text('Body'),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );

    // Expect Bottom Navigation Bar
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('AdaptiveScaffold shows NavigationRail on wide screens', (tester) async {
    // Set large screen size (Desktop / Tablet Landscape)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          body: const Text('Body'),
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );

    // Expect Navigation Rail
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
