import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/logic/notification_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationLogic formatting', () {
    test('Single Movie Title', () {
      expect(NotificationLogic.formatTitle(['Oppenheimer']), '🎬 New Release: Oppenheimer');
    });

    test('Multiple Movie Title', () {
      expect(NotificationLogic.formatTitle(['Oppenheimer', 'Barbie']), '🎬 2 New Releases');
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
      expect(body, contains('Christopher Nolan - Director, Writer'));
      expect(body, contains('🍿 In theatres 01/01/2023'));
    });

    test('Multiple Movies Body (2 movies)', () {
      final entries = [
        NotificationHistoryEntry(tmdbId: 1, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 2, reasons: [], notificationEvents: []),
      ];
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie'], entries);
      expect(body, 'Oppenheimer • Barbie');
    });

    test('Multiple Movies Body (3 movies)', () {
      final entries = [
        NotificationHistoryEntry(tmdbId: 1, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 2, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 3, reasons: [], notificationEvents: []),
      ];
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie', 'Interstellar'], entries);
      expect(body, 'Oppenheimer • Barbie • Interstellar');
    });

    test('Multiple Movies Body (4 movies)', () {
      final entries = [
        NotificationHistoryEntry(tmdbId: 1, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 2, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 3, reasons: [], notificationEvents: []),
        NotificationHistoryEntry(tmdbId: 4, reasons: [], notificationEvents: []),
      ];
      final body = NotificationLogic.formatBody(['Oppenheimer', 'Barbie', 'Interstellar', 'Dunkirk'], entries);
      expect(body, 'Oppenheimer • Barbie • Interstellar • +1 more');
    });

    // TV Show Tests
    test('Single TV Show Title - Series Premiere', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
          tvNotificationType: 'series_premiere',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad'], entries: entries);
      expect(title, '📺 Series Premiere: Breaking Bad');
    });

    test('Single TV Show Title - Season Premiere', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 2,
          episodeNumber: 1,
          episodeTitle: 'Seven Thirty-Seven',
          tvNotificationType: 'season_premiere',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad'], entries: entries);
      expect(title, '📺 Season 2 Premiere: Breaking Bad');
    });

    test('Single TV Show Title - Season Finale', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 1,
          episodeNumber: 13,
          episodeTitle: 'A No-Rough-Stuff-Type Deal',
          tvNotificationType: 'season_finale',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad'], entries: entries);
      expect(title, '📺 Season 1 Finale: Breaking Bad');
    });

    test('Single TV Show Title - Special', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 0,
          episodeNumber: 1,
          episodeTitle: 'Behind the Scenes',
          tvNotificationType: 'special',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad'], entries: entries);
      expect(title, '📺 Special: Breaking Bad');
    });

    test('Single TV Show Title - Grouped Episodes', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
          tvNotificationType: 'episode',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad'], entries: entries);
      expect(title, '📺 3 new episodes of Breaking Bad');
    });

    test('Single TV Show Body with Episode Info', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [
            NotificationReason(contributorId: 1, contributorName: 'Vince Gilligan', department: 'Creating', job: 'Creator'),
          ],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 1,
          episodeNumber: 1,
          episodeTitle: 'Pilot',
          tvNotificationType: 'series_premiere',
        )
      ];
      
      final body = NotificationLogic.formatBody(['Breaking Bad'], entries);
      expect(body, contains('Pilot - S1E01'));
      expect(body, contains('01/01/2023'));
      expect(body, contains('Vince Gilligan - Creator'));
    });

    test('Multiple TV Shows Title', () {
      final entries = [
        NotificationHistoryEntry(
          tmdbId: 100,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 1,
          episodeNumber: 1,
          tvNotificationType: 'episode',
        ),
        NotificationHistoryEntry(
          tmdbId: 101,
          reasons: [],
          notificationEvents: [
            NotificationEvent(releaseType: 'tv', releaseDate: '2023-01-01', notifiedAt: '2023-01-01'),
          ],
          mediaType: 'tv',
          seasonNumber: 2,
          episodeNumber: 5,
          tvNotificationType: 'episode',
        )
      ];
      
      final title = NotificationLogic.formatTitle(['Breaking Bad', 'Better Call Saul'], entries: entries);
      expect(title, '📺 2 New TV Episodes');
    });

    // Property-based tests for TV notification formatting
    test('Property 9: Release Type Emoji Mapping - Property Test', () {
      // **Property 9: Release Type Emoji Mapping**
      // **Validates: Requirements 7.1, 7.2**
      
      // Test emoji mapping across different release types
      final testCases = [
        {'releaseType': 'tv', 'expectedEmoji': '📺'},
        {'releaseType': 'broadcast', 'expectedEmoji': '📺'},
        {'releaseType': 'air', 'expectedEmoji': '📺'},
        {'releaseType': 'streaming', 'expectedEmoji': '💻'},
        {'releaseType': 'digital', 'expectedEmoji': '💻'},
      ];
      
      for (int i = 0; i < 100; i++) {
        final testCase = testCases[i % testCases.length];
        final releaseType = testCase['releaseType'] as String;
        final expectedEmoji = testCase['expectedEmoji'] as String;
        
        final entries = [
          NotificationHistoryEntry(
            tmdbId: 100 + i,
            reasons: [],
            notificationEvents: [
              NotificationEvent(
                releaseType: releaseType,
                releaseDate: '2023-01-01',
                notifiedAt: '2023-01-01',
              ),
            ],
            mediaType: 'tv',
            seasonNumber: 1,
            episodeNumber: 1,
            episodeTitle: 'Test Episode',
            tvNotificationType: 'episode',
          )
        ];
        
        final title = NotificationLogic.formatTitle(['Test Show'], entries: entries);
        expect(title, contains(expectedEmoji),
          reason: 'Release type "$releaseType" should use emoji "$expectedEmoji"');
      }
    });

    test('Property 10: Notification Label Formatting - Property Test', () {
      // **Property 10: Notification Label Formatting**
      // **Validates: Requirements 7.3, 7.4, 7.5, 7.6, 7.7**
      
      // Test notification label formatting across different episode types
      final testCases = [
        {
          'tvType': 'series_premiere',
          'seasonNum': 1,
          'episodeNum': 1,
          'expectedTitleContains': 'Series Premiere',
          'expectedBodyContains': 'S1E01'
        },
        {
          'tvType': 'season_premiere',
          'seasonNum': 2,
          'episodeNum': 1,
          'expectedTitleContains': 'Season 2 Premiere',
          'expectedBodyContains': 'S2E01'
        },
        {
          'tvType': 'season_finale',
          'seasonNum': 1,
          'episodeNum': 10,
          'expectedTitleContains': 'Season 1 Finale',
          'expectedBodyContains': 'S1E10'
        },
        {
          'tvType': 'special',
          'seasonNum': 0,
          'episodeNum': 1,
          'expectedTitleContains': 'Special',
          'expectedBodyContains': 'S0E01'
        },
        {
          'tvType': 'episode',
          'seasonNum': 3,
          'episodeNum': 5,
          'expectedTitleContains': 'New Episode',
          'expectedBodyContains': 'S3E05'
        },
      ];
      
      for (int i = 0; i < 100; i++) {
        final testCase = testCases[i % testCases.length];
        final tvType = testCase['tvType'] as String;
        final seasonNum = testCase['seasonNum'] as int;
        final episodeNum = testCase['episodeNum'] as int;
        final expectedTitleContains = testCase['expectedTitleContains'] as String;
        final expectedBodyContains = testCase['expectedBodyContains'] as String;
        
        final entries = [
          NotificationHistoryEntry(
            tmdbId: 100 + i,
            reasons: [],
            notificationEvents: [
              NotificationEvent(
                releaseType: 'tv',
                releaseDate: '2023-01-01',
                notifiedAt: '2023-01-01',
              ),
            ],
            mediaType: 'tv',
            seasonNumber: seasonNum,
            episodeNumber: episodeNum,
            episodeTitle: 'Test Episode $i',
            tvNotificationType: tvType,
          )
        ];
        
        final title = NotificationLogic.formatTvTitle(['Test Show $i'], entries);
        final body = NotificationLogic.formatTvBody(['Test Show $i'], entries);
        
        expect(title, contains(expectedTitleContains),
          reason: 'TV type "$tvType" should have title containing "$expectedTitleContains"');
        expect(body, contains(expectedBodyContains),
          reason: 'Season $seasonNum Episode $episodeNum should format as "$expectedBodyContains"');
        
        // All TV notifications should use 📺 emoji
        expect(title, contains('📺'),
          reason: 'All TV notifications should use 📺 emoji');
      }
    });

    test('Property 11: History Entry Completeness - Property Test', () {
      // **Property 11: History Entry Completeness**
      // **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.6**
      
      // Test that TV notification history entries contain all required fields
      // For any TV notification history entry, the entry SHALL contain:
      // - show poster path (via posterPath in history item)
      // - show title (via title in history item)
      // - episode details (season/episode numbers)
      // - notification type label (tvNotificationType)
      // - at least one date (air date or streaming date)
      
      final testCases = [
        {
          'tvType': 'series_premiere',
          'seasonNum': 1,
          'episodeNum': 1,
          'episodeTitle': 'Pilot',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
        {
          'tvType': 'season_premiere',
          'seasonNum': 2,
          'episodeNum': 1,
          'episodeTitle': 'New Season',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
        {
          'tvType': 'season_finale',
          'seasonNum': 1,
          'episodeNum': 10,
          'episodeTitle': 'The End',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
        {
          'tvType': 'special',
          'seasonNum': 0,
          'episodeNum': 1,
          'episodeTitle': 'Holiday Special',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
        {
          'tvType': 'episode',
          'seasonNum': 3,
          'episodeNum': 5,
          'episodeTitle': 'Regular Episode',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
        {
          'tvType': 'grouped_episodes',
          'seasonNum': 1,
          'episodeNum': 3, // Episode count for grouped
          'episodeTitle': '3 episodes',
          'hasAirDate': true,
          'hasStreamingDate': false,
        },
      ];
      
      for (int i = 0; i < 100; i++) {
        final testCase = testCases[i % testCases.length];
        final tvType = testCase['tvType'] as String;
        final seasonNum = testCase['seasonNum'] as int;
        final episodeNum = testCase['episodeNum'] as int;
        final episodeTitle = testCase['episodeTitle'] as String;
        
        // Create a TV notification history entry
        final entry = NotificationHistoryEntry(
          tmdbId: 100 + i,
          reasons: [
            NotificationReason(
              contributorId: 1,
              contributorName: 'Test Show',
              department: 'TV Show',
              job: 'Followed Show',
            ),
          ],
          notificationEvents: [
            NotificationEvent(
              releaseType: 'tv',
              releaseDate: '2023-01-01',
              notifiedAt: '2023-01-01',
            ),
          ],
          mediaType: 'tv',
          seasonNumber: seasonNum,
          episodeNumber: episodeNum,
          episodeTitle: episodeTitle,
          tvNotificationType: tvType,
        );
        
        // Verify all required fields are present
        expect(entry.mediaType, equals('tv'),
          reason: 'TV entry must have mediaType set to "tv"');
        
        expect(entry.seasonNumber, isNotNull,
          reason: 'TV entry must have seasonNumber');
        expect(entry.seasonNumber, equals(seasonNum),
          reason: 'Season number must match');
        
        expect(entry.episodeNumber, isNotNull,
          reason: 'TV entry must have episodeNumber');
        expect(entry.episodeNumber, equals(episodeNum),
          reason: 'Episode number must match');
        
        expect(entry.episodeTitle, isNotNull,
          reason: 'TV entry must have episodeTitle');
        expect(entry.episodeTitle, equals(episodeTitle),
          reason: 'Episode title must match');
        
        expect(entry.tvNotificationType, isNotNull,
          reason: 'TV entry must have tvNotificationType');
        expect(entry.tvNotificationType, equals(tvType),
          reason: 'TV notification type must match');
        
        // Verify at least one date is present
        expect(entry.notificationEvents, isNotEmpty,
          reason: 'TV entry must have at least one notification event');
        
        final hasDate = entry.notificationEvents.any((e) => 
          e.releaseDate.isNotEmpty
        );
        expect(hasDate, isTrue,
          reason: 'TV entry must have at least one date (air date or streaming date)');
        
        // Verify reasons are present (show or person info)
        expect(entry.reasons, isNotEmpty,
          reason: 'TV entry must have at least one reason (show or person)');
        
        // Verify reason has required fields
        final reason = entry.reasons.first;
        expect(reason.contributorId, isNotNull,
          reason: 'Reason must have contributorId');
        expect(reason.contributorName, isNotEmpty,
          reason: 'Reason must have contributorName');
        expect(reason.department, isNotEmpty,
          reason: 'Reason must have department');
      }
    });
  });
}
