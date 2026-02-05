import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:filmmaker_alerts/logic/tv_efficiency_upgrade.dart';

// Simple mock for testing
class SimpleMockTmdbService {
  int getTvDetailsOptimizedCallCount = 0;
  int getTvSeasonDetailsCallCount = 0;
  int getTvEpisodeCreditsCallCount = 0;

  Future<Map<String, dynamic>> getTvDetailsOptimized(int id) async {
    getTvDetailsOptimizedCallCount++;
    return {
      'id': id,
      'name': 'Test Show $id',
      'status': 'Returning Series',
      'in_production': true,
      'next_episode_to_air': {
        'air_date': '2026-01-10',
        'season_number': 1,
        'episode_number': 5,
      },
      'seasons': [
        {
          'season_number': 1,
          'air_date': '2025-01-01',
        },
      ],
    };
  }

  Future<Map<String, dynamic>> getTvSeasonDetails(int showId, int seasonNumber) async {
    getTvSeasonDetailsCallCount++;
    return {
      'episodes': [
        {
          'id': showId * 1000 + seasonNumber * 100 + 1,
          'name': 'Test Episode 1',
          'air_date': '2026-01-05',
          'season_number': seasonNumber,
          'episode_number': 1,
        },
      ],
    };
  }

  Future<Map<String, dynamic>> getTvEpisodeCredits(int showId, int seasonNumber, int episodeNumber) async {
    getTvEpisodeCreditsCallCount++;
    return {
      'crew': [
        {
          'name': 'Test Director',
          'job': 'Director',
          'department': 'Directing',
        },
      ],
      'cast': [],
    };
  }

  void resetCounters() {
    getTvDetailsOptimizedCallCount = 0;
    getTvSeasonDetailsCallCount = 0;
    getTvEpisodeCreditsCallCount = 0;
  }
}

void main() {
  group('TV Efficiency Manual Tests', () {
    late SimpleMockTmdbService mockService;
    late TvEfficiencyUpgrade tvEfficiency;

    setUp(() {
      mockService = SimpleMockTmdbService();
      tvEfficiency = TvEfficiencyUpgrade(mockService);
    });

    test('should demonstrate API call reduction', () async {
      final tvCredits = [
        {
          'id': 12345,
          'media_type': 'tv',
          'name': 'Test Show',
          'job': 'Director',
        },
      ];

      // Process the same show for multiple people (simulating multiple contributors)
      mockService.resetCounters();

      // Person 1 - Director
      await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Test Director',
        notifyForDepartments: ['Director'],
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      // Person 2 - Also Director (same show)
      await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Another Director',
        notifyForDepartments: ['Director'],
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      // Verify caching worked - exact counts depend on optimization logic
      expect(mockService.getTvDetailsOptimizedCallCount, 1, 
        reason: 'Show details should be cached across contributors');
      expect(mockService.getTvSeasonDetailsCallCount, 1, 
        reason: 'Season details should be cached across contributors');
      
      // Episode credits may or may not be called depending on optimization
      debugPrint('Episode credits calls: ${mockService.getTvEpisodeCreditsCallCount}');
      expect(mockService.getTvEpisodeCreditsCallCount, lessThanOrEqualTo(2), 
        reason: 'Episode credits should be optimized');
    });

    test('should skip episode credits for non-episode-specific roles', () async {
      final tvCredits = [
        {
          'id': 12345,
          'media_type': 'tv',
          'name': 'Test Show',
          'job': 'Producer',
        },
      ];

      mockService.resetCounters();

      // Producer (not episode-specific role)
      await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Test Producer',
        notifyForDepartments: ['Producer'], // Not Director/Writer
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      // Should not call episode credits for producers
      expect(mockService.getTvEpisodeCreditsCallCount, 0, 
        reason: 'Should not check episode credits for non-episode-specific roles');
      expect(mockService.getTvDetailsOptimizedCallCount, 1);
      expect(mockService.getTvSeasonDetailsCallCount, 1);
    });

    test('should handle creators efficiently', () async {
      // Mock a creator show
      mockService = SimpleMockTmdbService();
      tvEfficiency = TvEfficiencyUpgrade(mockService);

      final tvCredits = [
        {
          'id': 12345,
          'media_type': 'tv',
          'name': 'Creator Show',
          'job': 'Creator',
        },
      ];

      mockService.resetCounters();

      // Creator should get notifications without episode credit checks
      final notifications = await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Test Creator',
        notifyForDepartments: ['Creator'],
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      // Should not call episode credits for creators
      expect(mockService.getTvEpisodeCreditsCallCount, 0, 
        reason: 'Creators should not need episode credit checks');
      expect(notifications.length, 1);
      expect(notifications.first.jobTitle, 'Creator');
    });

    test('should demonstrate cache clearing', () async {
      final tvCredits = [
        {
          'id': 12345,
          'media_type': 'tv',
          'name': 'Test Show',
          'job': 'Director',
        },
      ];

      mockService.resetCounters();

      // First call
      await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Person 1',
        notifyForDepartments: ['Director'],
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      expect(mockService.getTvDetailsOptimizedCallCount, 1);

      // Clear caches
      tvEfficiency.clearCaches();

      // Second call after cache clear
      await tvEfficiency.processSingleTvShow(
        showId: 12345,
        tvCredits: tvCredits,
        contributorName: 'Person 2',
        notifyForDepartments: ['Director'],
        allRolesSelected: false,
        startDateStr: '2026-01-01',
        todayStr: '2026-01-10',
      );

      // Should call API again after cache clear
      expect(mockService.getTvDetailsOptimizedCallCount, 2, 
        reason: 'Should call API again after cache clear');
    });
  });
}