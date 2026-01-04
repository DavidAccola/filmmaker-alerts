import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/models/contributor.dart';
import '../data/models/movie_cache_entry.dart';
import '../data/models/notification_history.dart';
import '../data/models/preferences.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/tmdb_service.dart';
import '../core/tmdb_mapping.dart';

class ReleaseChecker {
  final TmdbService _tmdbService;
  final ContributorRepository _contributorRepository;
  final PreferencesRepository _preferencesRepository;
  final HistoryRepository _historyRepository;
  final MovieCacheRepository _movieCacheRepository;

  ReleaseChecker(
    this._tmdbService,
    this._contributorRepository,
    this._preferencesRepository,
    this._historyRepository,
    this._movieCacheRepository,
  );

  Future<List<NotificationHistoryEntry>> findNewReleases({DateTime? sinceDate}) async {
    final prefs = _preferencesRepository.getPreferences();
    final contributors = _contributorRepository.getContributors();
    
    // 1. Date Logic
    final DateTime realToday = DateTime.now();
    DateTime effectiveToday = realToday;
    DateTime start;
    
    // Check if we're in debug mode with a future pretend date
    bool isDebugFutureMode = false;
    if (prefs.pretendToday != null && prefs.pretendToday!.isNotEmpty) {
      try {
        final pretendDate = DateTime.parse(prefs.pretendToday!);
        if (pretendDate.isAfter(realToday)) {
          // Debug mode: pretend date is in the future
          isDebugFutureMode = true;
          start = realToday;
          effectiveToday = pretendDate;
          debugPrint('[ReleaseChecker] Debug future mode: checking from real today ($realToday) to pretend date ($pretendDate)');
        } else {
          // Normal pretend mode: pretend date is in past/present
          effectiveToday = pretendDate;
          start = sinceDate ?? pretendDate.subtract(const Duration(days: 7));
          debugPrint('[ReleaseChecker] Debug past mode: using pretend today ($pretendDate)');
        }
      } catch (e) {
        debugPrint('[ReleaseChecker] Invalid pretendToday format: $e');
        start = sinceDate ?? realToday.subtract(const Duration(days: 7));
      }
    } else {
      // Normal operation mode
      if (sinceDate != null) {
        start = sinceDate;
        debugPrint('[ReleaseChecker] Normal mode: checking from provided sinceDate ($sinceDate) to today ($realToday)');
      } else {
        // Check if we have a last check time stored
        if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty) {
          try {
            start = DateTime.parse(prefs.lastCheckTime!);
            debugPrint('[ReleaseChecker] Normal mode: checking from last check time ($start) to today ($realToday)');
          } catch (e) {
            debugPrint('[ReleaseChecker] Invalid lastCheckTime format: $e, falling back to 7 days');
            start = realToday.subtract(const Duration(days: 7));
          }
        } else {
          // First time check - go back 7 days
          start = realToday.subtract(const Duration(days: 7));
          debugPrint('[ReleaseChecker] First time check: checking last 7 days from today ($realToday)');
        }
      }
    }

    // Normalize to YYYY-MM-DD strings for comparison
    final startDateStr = DateFormat('yyyy-MM-dd').format(start);
    final todayStr = DateFormat('yyyy-MM-dd').format(effectiveToday);

    debugPrint('[ReleaseChecker] Checking releases from $startDateStr to $todayStr');

    final List<NotificationHistoryEntry> newNotifications = [];

    // Track processed IDs to avoid re-fetching details for the same movie
    final Set<int> processedMovieIds = {};

    // 2. Iterate Contributors
    for (final contributor in contributors) {
      // Throttling (250ms)
      await Future.delayed(const Duration(milliseconds: 250));

      try {
        List<dynamic> credits = [];
        
        // Fetch Credits based on type
        if (contributor.type == ContributorType.person) {
          final data = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
          credits = [...(data['cast'] ?? []), ...(data['crew'] ?? [])];
        } else if (contributor.type == ContributorType.company) {
          // Companies: Fetch movies and TV
          final movies = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'movie', since: startDateStr);
          final tv = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'tv', since: startDateStr);
          credits = [...(movies['results'] ?? []), ...(tv['results'] ?? [])];
        } else if (contributor.type == ContributorType.movie) {
             // Treat the movie itself as the credit
             credits = [await _tmdbService.getMovieDetails(contributor.tmdbId)];
             debugPrint('[ReleaseChecker] Movie ${contributor.name} details: ${credits.first}');
        }

        // --- GROUPING & OPTIMIZATION ---
        // Group credits by Movie ID. This handles cases where a person has multiple roles
        // (e.g. Director and Editor) on the same film.
        final Map<int, List<dynamic>> moviesMap = {};
        for (final credit in credits) {
          final int id = credit['id'];
          if (!moviesMap.containsKey(id)) {
            moviesMap[id] = [];
          }
          moviesMap[id]!.add(credit);
        }

        debugPrint('[ReleaseChecker] ${contributor.name} has ${moviesMap.length} movies to check');

        for (final entry in moviesMap.entries) {
          final int movieId = entry.key;
          final List<dynamic> groupCredits = entry.value;

          // A. Department Check
          // A. Department Check
          final interestedDepartments = contributor.notifyForDepartments;
          // True All Logic: If allRolesSelected is true, ignore list and allow all.
          final isTrueAll = contributor.allRolesSelected ?? false;

          final matchingCredits = groupCredits.where((c) {
             final dept = c['department'] ?? '';
             final job = c['job'] ?? '';
             final role = TmdbMapping.mapTmdbDeptToRole(dept, job: job);
             
             return isTrueAll || 
                    interestedDepartments.contains(role) || 
                    // 'Movie' type contributors generally don't have department fields in the same way, 
                    // or we automatically want them.
                    contributor.type == ContributorType.movie;
          }).toList();

          if (matchingCredits.isEmpty) continue; // Skip if no relevant roles

          final credit = groupCredits.first; // Representative credit for metadata
          final String? releaseDate = credit['release_date'] ?? credit['first_air_date'];
          
          if (releaseDate == null || releaseDate.isEmpty) continue;

          // B. Basic Window Check (Optimization)
          // Check if the release date falls within our search window
          if (releaseDate.compareTo(startDateStr) < 0 || releaseDate.compareTo(todayStr) > 0) {
            continue;
          }

          final mediaType = credit['media_type'] ?? (contributor.type == ContributorType.movie ? 'movie' : null);

          // C. Deduplication (If processed, just add reason if we already found it)
          if (processedMovieIds.contains(movieId)) {
             // Check if this movie matches an existing newNotification
             final existing = newNotifications.where((n) => n.tmdbId == movieId).firstOrNull;
             if (existing != null) {
                // Add new reasons (roles)
                for (var match in matchingCredits) {
                   _addReasonToEntry(existing, contributor, match);
                }
             }
             continue; // Don't re-fetch details
          }

          if (mediaType == 'tv') {
             // TV Logic
             if (prefs.effectiveNotifyTV && !_hasBeenNotified(movieId, 'TV')) {
               processedMovieIds.add(movieId);
               _addNotification(newNotifications, contributor, matchingCredits, 'TV', todayStr);
             }
             continue;
          }

          // D. Movie Logic - Fetch Details
          final details = await _tmdbService.getMovieDetails(movieId);
          processedMovieIds.add(movieId); // Mark processed regardless of success to avoid loops

          final releaseDatesResults = details['release_dates']?['results'] as List?;

          if (releaseDatesResults == null) continue;

          // Cache Movie Details
          await _movieCacheRepository.addOrUpdateMovieInCache(MovieCacheEntry(
            tmdbId: movieId,
            title: details['title'] ?? 'Unknown',
            posterPath: details['poster_path'],
            releaseDate: details['release_date'] ?? '',
            imdbId: details['external_ids']?['imdb_id'],
          ));

          // Region Priority
          var regionReleases = releaseDatesResults.where(
            (r) => r['iso_3166_1'] == 'US',
          ).firstOrNull;

          List<dynamic> releases = [];
          if (regionReleases != null) {
            releases = regionReleases['release_dates'];
          } else {
            // Fallback: Check all
             for (var r in releaseDatesResults) {
              releases.addAll(r['release_dates']);
            }
          }

          for (final release in releases) {
            final String rDate = (release['release_date'] as String).substring(0, 10);
            final int type = release['type'];

            // Window Check for specific release
            if (rDate.compareTo(startDateStr) < 0 || rDate.compareTo(todayStr) > 0) continue;

            // Preference Check
            if (!_isNotificationEnabled(type, prefs)) continue;

            // History Check
            final typeStr = _getReleaseTypeString(type);
            if (_hasBeenNotified(movieId, typeStr)) continue;

            // Add Notification
            _addNotification(newNotifications, contributor, matchingCredits, typeStr, todayStr);
          }
        }

      } catch (e) {
        debugPrint('[ReleaseChecker] Error processing ${contributor.name}: $e');
      }
    }

    return newNotifications; 
  }

  void _addReasonToEntry(NotificationHistoryEntry entry, Contributor contributor, dynamic credit) {
    final reason = NotificationReason(
      contributorId: contributor.tmdbId,
      contributorName: contributor.name,
      department: credit['department'] ?? 'Unknown',
      job: credit['job'] ?? credit['character'],
    );
     if (!entry.reasons.any((r) => r.contributorId == reason.contributorId && r.job == reason.job)) {
        entry.reasons.add(reason);
     }
  }

  bool _isNotificationEnabled(int type, Preferences prefs) {
    switch (type) {
      case 1: // Premiere
      case 2: // Theatrical Limited
      case 3: // Theatrical
        return prefs.effectiveNotifyTheatre;
      case 4: // Digital
        return prefs.effectiveNotifyStreaming;
      case 5: // Physical
        return prefs.effectiveNotifyPhysical;
      case 6: // TV
        return prefs.effectiveNotifyTV;
      default:
        return false;
    }
  }

  String _getReleaseTypeString(int type) {
    const types = {1: 'Premiere', 2: 'Theatrical (Limited)', 3: 'Theatrical', 4: 'Digital', 5: 'Physical', 6: 'TV'};
    return types[type] ?? 'Unknown';
  }

  bool _hasBeenNotified(int tmdbId, String releaseType) {
    final history = _historyRepository.getHistory();
    final entry = history.where((h) => h.entry.tmdbId == tmdbId).firstOrNull;
    
    if (entry == null) return false;
    
    return entry.entry.notificationEvents.any((e) => e.releaseType == releaseType);
  }

  void _addNotification(
    List<NotificationHistoryEntry> list,
    Contributor contributor,
    List<dynamic> credits,
    String releaseType,
    String todayStr,
  ) {
    if (credits.isEmpty) return;
    final int movieId = credits.first['id'];
    
    // Check if we already have this movie in our "newNotifications" list (Aggregation)
    var existing = list.where((n) => n.tmdbId == movieId).firstOrNull;

    // Use current time with millisecond precision to maintain order within batch
    final now = DateTime.now();
    final notificationTime = now.add(Duration(milliseconds: list.length)).toIso8601String();

    final event = NotificationEvent(
      releaseType: releaseType,
      releaseDate: (credits.first['release_date'] ?? credits.first['first_air_date'] ?? '').toString(),
      notifiedAt: notificationTime, // Each notification gets a slightly different timestamp
    );

    if (existing != null) {
      // Merge Reasons
      for (final c in credits) {
         _addReasonToEntry(existing, contributor, c);
      }
      // Merge Event
      if (!existing.notificationEvents.any((e) => e.releaseType == releaseType)) {
        existing.notificationEvents.add(event);
      }
    } else {
      // Create New
      final reasons = credits.map((c) => NotificationReason(
        contributorId: contributor.tmdbId,
        contributorName: contributor.name,
        department: c['department'] ?? 'Unknown',
        job: c['job'] ?? c['character'],
      )).toList();

      list.add(NotificationHistoryEntry(
        tmdbId: movieId,
        reasons: reasons,
        notificationEvents: [event],
      ));
    }
  }
}