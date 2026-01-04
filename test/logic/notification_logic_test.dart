import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/logic/notification_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationLogic formatting', () {
    test('Single Movie Title', () {
      expect(NotificationLogic.formatTitle(['Oppenheimer']), 'New Release: Oppenheimer');
    });

    test('Multiple Movie Title', () {
      expect(NotificationLogic.formatTitle(['Oppenheimer', 'Barbie']), '2 New Releases Found');
    });

    test('Single Movie Body with Multiple Roles', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [
            NotificationReason(contributorId: 1, contributorName: 'Christopher Nolan', department: 'Directing', job: 'Director'),
            NotificationReason(contributorId: 1, contributorName: 'Christopher Nolan', department: 'Writing', job: 'Writer'),
          ],
          notificationEvents: [
            NotificationEvent(releaseType: 'Theatrical', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
        )
      ];
      
      final body = NotificationLogic.formatBody(['Oppenheimer'], entries);
      expect(body, contains('Christopher Nolan is Director, Writer'));
      expect(body, contains('Release Date: 2023-01-01'));
    });

    test('Multiple Movies Body (2 movies)', () {
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie'], []);
      expect(body, 'Oppenheimer and Barbie\nClick to view full history in the app.');
    });

    test('Multiple Movies Body (3 movies)', () {
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie', 'Interstellar'], []);
      expect(body, 'Oppenheimer, Barbie, and Interstellar\nClick to view full history in the app.');
    });

    test('Multiple Movies Body (4 movies)', () {
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie', 'Interstellar', 'Dunkirk'], []);
      expect(body, 'Oppenheimer, Barbie, Interstellar, and 1 more\nClick to view full history in the app.');
    });
  });
}
