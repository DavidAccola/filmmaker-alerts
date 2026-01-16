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
import '../data/repositories/tv_cache_repository.dart';
import '../data/services/tmdb_service.dart';
import '../core/tmdb_mapping.dart';
import '../data/models/tv_cache.dart';
import '../data/models/contributor_detail.dart';
import '../data/repositories/contributor_detail_repository.dart';
import 'tv_efficiency_upgrade.dart';
import 'work_sorting_logic.dart';
import 'tv_show_display_logic.dart';

class ReleaseChecker {
  final TmdbService _tmdbService;
  final ContributorRepository _contributorRepository;
  final PreferencesRepository _preferencesRepository;
  final HistoryRepository _historyRepository;
  final MovieCacheRepository _movieCacheRepository;
  final TvCacheRepository _tvCacheRepository;
  final ContributorDetailRepository? _contributorDetailRepository;
  
  // TV Efficiency Optimization
  late final TvEfficiencyUpgrade _tvEfficiency;
  
  // Feature flag for controlled rollout
  static const bool _useOptimizedTvProcessing = true;
  
  // Debug mode for testing
  bool isDebugFutureMode = false;

  ReleaseChecker(
    this._tmdbService,
    this._contributorRepository,
    this._preferencesRepository,
    this._historyRepository,
    this._movieCacheRepository,
    this._tvCacheRepository, {
    ContributorDetailRepository? contributorDetailRepository,
  }) : _contributorDetailRepository = contributorDetailRepository {
    _tvEfficiency = TvEfficiencyUpgrade(_tmdbService);
  }

  Future<List<NotificationHistoryEntry>> findNewReleases({DateTime? sinceDate}) async {
    final prefs = _preferencesRepository.getPreferences();
    final contributors = _contributorRepository.getContributors();
    
    debugPrint('[ReleaseChecker] === DEBUG: Starting findNewReleases ===');
    debugPrint('[ReleaseChecker] DEBUG: Total contributors: ${contributors.length}');
    debugPrint('[ReleaseChecker] DEBUG: Using optimized TV processing: $_useOptimizedTvProcessing');
    
    // Clear TV efficiency caches for this check run
    if (_useOptimizedTvProcessing) {
      _tvEfficiency.clearCaches();
    }
    
    // Debug: Log all contributors and their types
    for (final contributor in contributors) {
      debugPrint('[ReleaseChecker] DEBUG: Contributor "${contributor.name}" - Type: ${contributor.type} - ID: ${contributor.tmdbId}');
    }
    
    // In-memory caches for this check run (Phase 1 optimization)
    final Map<int, Map<String, dynamic>> processedShowDetails = {};
    final Map<String, Map<String, dynamic>> processedSeasonDetails = {};
    
    // 1. Date Logic
    final DateTime realToday = DateTime.now();
    DateTime effectiveToday = realToday;
    DateTime start;
    
    // Check if we're in debug mode with a future pretend date
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

    // Check TV shows first
    debugPrint('[ReleaseChecker] DEBUG: About to check TV releases...');
    final tvNotifications = await _checkTvReleases(startDateStr, todayStr, processedShowDetails, processedSeasonDetails);
    debugPrint('[ReleaseChecker] DEBUG: TV releases check returned ${tvNotifications.length} notifications');
    newNotifications.addAll(tvNotifications);

    // 2. Iterate Contributors (excluding TV shows, which are handled separately)
    debugPrint('[ReleaseChecker] DEBUG: Starting main contributor loop...');
    final nonTvContributors = contributors.where((c) => c.type != ContributorType.tvShow).toList();
    debugPrint('[ReleaseChecker] DEBUG: Processing ${nonTvContributors.length} non-TV contributors (${contributors.length - nonTvContributors.length} TV shows excluded)');
    
    for (final contributor in nonTvContributors) {
      debugPrint('[ReleaseChecker] DEBUG: Processing contributor "${contributor.name}" (${contributor.type})');
      
      // Only process people and companies
      if (contributor.type != ContributorType.person && contributor.type != ContributorType.company && contributor.type != ContributorType.movie) {
        debugPrint('[ReleaseChecker] DEBUG: Skipping ${contributor.name} - not a person/company/movie');
        continue;
      }
      
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - notifyForDepartments: ${contributor.notifyForDepartments}');
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - allRolesSelected: ${contributor.allRolesSelected}');
      
      // Throttling (250ms)
      await Future.delayed(const Duration(milliseconds: 250));

      try {
        List<dynamic> credits = [];
        
        // Fetch Credits based on type
        if (contributor.type == ContributorType.person) {
          // Fetch person details to get IMDB ID
          final personDetails = await _tmdbService.getPersonDetails(contributor.tmdbId);
          final imdbId = personDetails['external_ids']?['imdb_id'];
          
          // Update contributor with IMDB ID if not already set
          if (imdbId != null && imdbId.isNotEmpty && (contributor.imdbId == null || contributor.imdbId!.isEmpty)) {
            contributor.imdbId = imdbId;
            await _contributorRepository.updateContributor(contributor);
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Stored IMDB ID: $imdbId');
          }
          
          final data = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
          credits = [...(data['cast'] ?? []), ...(data['crew'] ?? [])];
          debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Fetched ${credits.length} total credits (${(data['cast'] ?? []).length} cast, ${(data['crew'] ?? []).length} crew)');
          
          // Update contributor detail with all fetched credits
          await _updateContributorDetail(contributor, credits);
          
          // Debug: Log TV credits
          final tvCredits = credits.where((c) => c['media_type'] == 'tv').toList();
          debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - TV credits: ${tvCredits.length}');
          for (final tv in tvCredits.take(5)) {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - TV: ${tv['name']} (${tv['id']}) - ${tv['job'] ?? tv['character'] ?? 'unknown role'}');
          }
        } else if (contributor.type == ContributorType.company) {
          // Companies: Fetch movies and TV
          final movies = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'movie', since: startDateStr);
          final tv = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'tv', since: startDateStr);
          credits = [...(movies['results'] ?? []), ...(tv['results'] ?? [])];
          
          // For companies, also fetch top works to ensure the detail screen is well-populated
          final topWorksResponse = await _tmdbService.getCompanyTopWorks(contributor.tmdbId);
          final topWorks = topWorksResponse['results'] as List? ?? [];
          
          // Combine check-window credits with top works for the detail update
          final detailCredits = [...credits, ...topWorks];
          await _updateContributorDetail(contributor, detailCredits);
        } else if (contributor.type == ContributorType.movie) {
             // Treat the movie itself as the credit
             credits = [await _tmdbService.getMovieDetails(contributor.tmdbId)];
             debugPrint('[ReleaseChecker] Movie ${contributor.name} details: ${credits.first}');
             
             // Update detail for the movie itself
             await _updateContributorDetail(contributor, credits);
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
        
        // Debug: Log TV shows in moviesMap
        for (final entry in moviesMap.entries) {
          final credit = entry.value.first;
          if (credit['media_type'] == 'tv') {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - TV show in map: ${credit['name']} (${entry.key})');
          }
        }

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

          final credit = groupCredits.first; // Representative credit for metadata
          final String? releaseDate = credit['release_date'] ?? credit['first_air_date'];
          final mediaType = credit['media_type'] ?? (contributor.type == ContributorType.movie ? 'movie' : null);

          debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - movieId: $movieId, mediaType: $mediaType, releaseDate: $releaseDate');

          // For TV shows, allow processing even if matchingCredits is empty (to check for creator episodes)
          // For other media types, skip if no relevant roles
          if (matchingCredits.isEmpty && mediaType != 'tv') {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping $movieId (no matching credits and not TV)');
            continue;
          }

          // For TV shows, skip the show premiere date check and instead check individual episode air dates
          // For movies, we need a valid release date
          if (mediaType != 'tv') {
            if (releaseDate == null || releaseDate.isEmpty) {
              debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping $movieId (no release date)');
              continue;
            }

            // B. Basic Window Check (Optimization)
            // Check if the release date falls within our search window
            if (releaseDate.compareTo(startDateStr) < 0 || releaseDate.compareTo(todayStr) > 0) {
              debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping $movieId (release date $releaseDate outside window $startDateStr-$todayStr)');
              continue;
            }
          } else {
            // For TV shows, we'll check episode air dates instead of show premiere date
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - TV show $movieId: skipping show premiere date check, will check episode air dates instead');
          }

          // C. Deduplication (If processed, just add reason if we already found it)
          if (processedMovieIds.contains(movieId)) {
             debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Already processed $movieId, adding reason');
             // Check if this movie matches an existing newNotification
             final existing = newNotifications.where((n) => n.tmdbId == movieId).firstOrNull;
             if (existing != null) {
                // Add new reasons (roles)
                for (var match in matchingCredits) {
                   _addReasonToEntry(existing, contributor, match);
                }
             } else if (mediaType == 'tv') {
                // For TV shows, if no notification exists yet but we have a creator/director role,
                // we should still process it to generate notifications for episodes
                debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - TV show $movieId already processed but no notification found, will process for creator/director roles');
                // Fall through to process TV show
             } else {
                continue; // Don't re-fetch details for non-TV media
             }
          }

          if (mediaType == 'tv') {
             debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Processing TV show $movieId');
             // TV Logic - Enhanced for person contributors
             if (prefs.effectiveNotifyTV) {
               // For person contributors, we process TV shows even if already processed by _checkTvReleases
               // because they may be creators/directors who should get notifications
               final alreadyProcessedByTvCheck = processedMovieIds.contains(movieId);
               if (!alreadyProcessedByTvCheck) {
                 processedMovieIds.add(movieId);
               }
               
               debugPrint('[ReleaseChecker] DEBUG: Processing TV show ${credit['name']} for person ${contributor.name}');
               
               // Use optimized TV processing if enabled
               if (_useOptimizedTvProcessing) {
                 await _processPersonTvShowOptimized(
                   newNotifications,
                   contributor,
                   movieId,
                   groupCredits,
                   prefs,
                   startDateStr,
                   todayStr,
                 );
               } else {
                 // Original TV processing logic (fallback)
                 await _processPersonTvShowOriginal(
                   newNotifications,
                   contributor,
                   movieId,
                   groupCredits,
                   prefs,
                   startDateStr,
                   todayStr,
                   processedShowDetails,
                   processedSeasonDetails,
                 );
               }
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

      // Determine media type based on credit data or release type
      String? mediaType;
      final credit = credits.first;
      if (credit['media_type'] != null) {
        mediaType = credit['media_type'];
      } else if (releaseType.toLowerCase() == 'tv' || credit['first_air_date'] != null) {
        mediaType = 'tv';
      } else if (credit['release_date'] != null) {
        mediaType = 'movie';
      }

      list.add(NotificationHistoryEntry(
        tmdbId: movieId,
        reasons: reasons,
        notificationEvents: [event],
        mediaType: mediaType,
      ));
    }
  }

  /// Check for new TV episodes for followed TV shows
  Future<List<NotificationHistoryEntry>> _checkTvReleases(
    String startDateStr,
    String todayStr,
    Map<int, Map<String, dynamic>> processedShowDetails,
    Map<String, Map<String, dynamic>> processedSeasonDetails,
  ) async {
    final List<NotificationHistoryEntry> tvNotifications = [];
    final contributors = _contributorRepository.getContributors();
    final prefs = _preferencesRepository.getPreferences();
    
    debugPrint('[ReleaseChecker] DEBUG: === _checkTvReleases called ===');
    debugPrint('[ReleaseChecker] DEBUG: TV notifications enabled: ${prefs.effectiveNotifyTV}');
    
    // Check if TV notifications are enabled globally
    if (!prefs.effectiveNotifyTV) {
      debugPrint('[ReleaseChecker] TV notifications are disabled globally, skipping TV show checks');
      return tvNotifications;
    }
    
    // Get all followed TV shows
    final tvShows = contributors.where((c) => c.type == ContributorType.tvShow).toList();
    
    debugPrint('[ReleaseChecker] DEBUG: Found ${tvShows.length} TV shows to check');
    for (final tvShow in tvShows) {
      debugPrint('[ReleaseChecker] DEBUG: TV Show: "${tvShow.name}" - ID: ${tvShow.tmdbId}');
    }
    
    debugPrint('[ReleaseChecker] Checking ${tvShows.length} followed TV shows for new episodes');
    
    for (final tvShow in tvShows) {
      debugPrint('[ReleaseChecker] DEBUG: Processing TV show "${tvShow.name}"...');
      try {
        // Throttling
        await Future.delayed(const Duration(milliseconds: 250));
        
        debugPrint('[ReleaseChecker] DEBUG: Getting TV details for "${tvShow.name}" (ID: ${tvShow.tmdbId})');
        
        // Phase 1 Optimization: Check in-memory cache first
        Map<String, dynamic> showDetails;
        if (processedShowDetails.containsKey(tvShow.tmdbId)) {
          debugPrint('[ReleaseChecker] DEBUG: Using cached show details for "${tvShow.name}"');
          showDetails = processedShowDetails[tvShow.tmdbId]!;
        } else {
          debugPrint('[ReleaseChecker] DEBUG: Fetching show details for "${tvShow.name}"');
          showDetails = await _tmdbService.getTvDetails(tvShow.tmdbId);
          processedShowDetails[tvShow.tmdbId] = showDetails;
        }
        
        debugPrint('[ReleaseChecker] DEBUG: Got TV details for "${tvShow.name}": ${showDetails.keys.toList()}');
        
        // Update contributor detail for the TV Show itself
        final List<Map<String, dynamic>> showCredits = [];
        if (showDetails['next_episode_to_air'] != null) {
          final nextEp = Map<String, dynamic>.from(showDetails['next_episode_to_air']);
          nextEp['media_type'] = 'tv';
          // Format title to include show name and episode code
          nextEp['name'] = '${showDetails['name']} - S${nextEp['season_number'].toString().padLeft(2, '0')}E${nextEp['episode_number'].toString().padLeft(2, '0')} - ${nextEp['name']}';
          showCredits.add(nextEp);
        }
        if (showDetails['last_episode_to_air'] != null) {
          final lastEp = Map<String, dynamic>.from(showDetails['last_episode_to_air']);
          lastEp['media_type'] = 'tv';
          lastEp['name'] = '${showDetails['name']} - S${lastEp['season_number'].toString().padLeft(2, '0')}E${lastEp['episode_number'].toString().padLeft(2, '0')} - ${lastEp['name']}';
          showCredits.add(lastEp);
        }
        
        // Also add the show itself as a Work so it can show up in hits/releases
        final showAsWork = Map<String, dynamic>.from(showDetails);
        showAsWork['media_type'] = 'tv';
        showCredits.add(showAsWork);
        
        await _updateContributorDetail(tvShow, showCredits);
        
        // Cache the show details
        await _tvCacheRepository.addOrUpdateShow(TvShowCacheEntry(
          tmdbId: tvShow.tmdbId,
          name: showDetails['name'] ?? 'Unknown',
          posterPath: showDetails['poster_path'],
          firstAirDate: showDetails['first_air_date'],
          status: showDetails['status'],
          creators: (showDetails['created_by'] as List?)?.map((c) => c['name'] as String).toList() ?? [],
          numberOfSeasons: showDetails['number_of_seasons'],
          imdbId: showDetails['external_ids']?['imdb_id'],
          lastAirDate: showDetails['last_air_date'],
          nextEpisodeToAir: showDetails['next_episode_to_air'] as Map<String, dynamic>?,
        ));
        
        // Check for upcoming episodes using TMDB's on-the-air endpoint
        debugPrint('[ReleaseChecker] DEBUG: Checking on-the-air and airing-today endpoints...');
        final onTheAir = await _tmdbService.getTvOnTheAir();
        final airingToday = await _tmdbService.getTvAiringToday();
        
        debugPrint('[ReleaseChecker] DEBUG: On-the-air results: ${onTheAir['results']?.length ?? 0} shows');
        debugPrint('[ReleaseChecker] DEBUG: Airing-today results: ${airingToday['results']?.length ?? 0} shows');
        
        // Combine both lists and filter for our show
        final allAiringShows = [
          ...(onTheAir['results'] as List? ?? []),
          ...(airingToday['results'] as List? ?? [])
        ];
        
        debugPrint('[ReleaseChecker] DEBUG: Total airing shows: ${allAiringShows.length}');
        
        final ourShowAiring = allAiringShows.where((show) => show['id'] == tvShow.tmdbId);
        
        debugPrint('[ReleaseChecker] DEBUG: Found ${ourShowAiring.length} matches for "${tvShow.name}" in airing shows');
        
        if (ourShowAiring.isNotEmpty) {
          debugPrint('[ReleaseChecker] DEBUG: "${tvShow.name}" is currently airing, checking seasons...');
          
          // Collect all episodes for this show, grouped by air date
          final Map<String, List<Map<String, dynamic>>> episodesByDate = {};
          
          // Get detailed season information to find specific episodes
          final seasons = showDetails['seasons'] as List? ?? [];
          
          debugPrint('[ReleaseChecker] DEBUG: "${tvShow.name}" has ${seasons.length} seasons');
          
          for (final season in seasons) {
            final seasonNumber = season['season_number'] as int;
            
            debugPrint('[ReleaseChecker] DEBUG: Processing season $seasonNumber for "${tvShow.name}"');
            
            try {
              // Phase 1 Optimization: Check in-memory cache first
              final cacheKey = '${tvShow.tmdbId}_$seasonNumber';
              Map<String, dynamic> seasonDetails;
              if (processedSeasonDetails.containsKey(cacheKey)) {
                debugPrint('[ReleaseChecker] DEBUG: Using cached season details for S$seasonNumber');
                seasonDetails = processedSeasonDetails[cacheKey]!;
              } else {
                debugPrint('[ReleaseChecker] DEBUG: Fetching season details for S$seasonNumber');
                seasonDetails = await _tmdbService.getTvSeasonDetails(tvShow.tmdbId, seasonNumber);
                processedSeasonDetails[cacheKey] = seasonDetails;
              }
              
              final episodes = seasonDetails['episodes'] as List? ?? [];
              
              debugPrint('[ReleaseChecker] DEBUG: Season $seasonNumber has ${episodes.length} episodes');
              
              for (final episode in episodes) {
                final airDate = episode['air_date'] as String?;
                if (airDate == null || airDate.isEmpty) {
                  debugPrint('[ReleaseChecker] DEBUG: Episode ${episode['episode_number']} has no air date, skipping');
                  continue;
                }
                
                debugPrint('[ReleaseChecker] DEBUG: Episode ${episode['episode_number']} airs on $airDate');
                
                // Skip rebroadcasts/reruns - TMDB doesn't explicitly mark these,
                // but we can filter based on episode metadata when available
                if (_isRebroadcast(episode)) {
                  debugPrint('[ReleaseChecker] DEBUG: Episode ${episode['episode_number']} is a rebroadcast, skipping');
                  continue;
                }
                
                // Check if episode is in our date range
                if (airDate.compareTo(startDateStr) < 0 || airDate.compareTo(todayStr) > 0) {
                  debugPrint('[ReleaseChecker] DEBUG: Episode ${episode['episode_number']} air date $airDate is outside range $startDateStr to $todayStr, skipping');
                  continue;
                }
                
                debugPrint('[ReleaseChecker] DEBUG: Episode ${episode['episode_number']} is in date range, processing...');
                
                // TODO: When TMDB provides streaming release dates for TV episodes,
                // we should also check those dates here. For now, we use air_date
                // which covers both broadcast and streaming for most shows.
                
                final episodeNumber = episode['episode_number'] as int;
                final seasonNum = episode['season_number'] as int;
                final episodeName = episode['name'] as String? ?? '';
                
                // Cache episode details
                await _tvCacheRepository.addOrUpdateEpisode(TvEpisodeCacheEntry(
                  tmdbId: episode['id'],
                  showId: tvShow.tmdbId,
                  seasonNumber: seasonNum,
                  episodeNumber: episodeNumber,
                  name: episodeName,
                  airDate: airDate,
                  stillPath: episode['still_path'],
                  directors: (episode['crew'] as List?)
                      ?.where((c) => c['job'] == 'Director')
                      .map((c) => c['name'] as String)
                      .toList() ?? [],
                ));
                
                // Determine episode type and check if user wants notifications for it
                final episodeType = _classifyEpisode(seasonNum, episodeNumber, episodes.length, showDetails);
                
                if (!_shouldNotifyForEpisodeType(episodeType, tvShow.tvNotificationPrefs, prefs.defaultTvNotificationPrefs)) {
                  continue;
                }
                
                // Check if we've already notified for this episode
                if (_hasBeenNotifiedForTvEpisode(tvShow.tmdbId, seasonNum, episodeNumber, episodeType)) {
                  continue;
                }
                
                // Add episode to the date group
                if (!episodesByDate.containsKey(airDate)) {
                  episodesByDate[airDate] = [];
                }
                
                // Add episode type to the episode data for later use
                final episodeWithType = Map<String, dynamic>.from(episode);
                episodeWithType['episode_type'] = episodeType;
                episodesByDate[airDate]!.add(episodeWithType);
              }
            } catch (e) {
              debugPrint('[ReleaseChecker] Error fetching season $seasonNumber for ${tvShow.name}: $e');
            }
          }
          
          // Create notifications for each date, grouping episodes that air on the same day
          for (final entry in episodesByDate.entries) {
            final airDate = entry.key;
            final episodes = entry.value;
            
            if (episodes.length == 1) {
              // Single episode - create individual notification
              final episode = episodes.first;
              final episodeType = episode['episode_type'] as String;
              
              _addTvNotification(
                tvNotifications,
                tvShow,
                episode,
                episodeType,
                airDate,
              );
            } else {
              // Multiple episodes on same day - create grouped notification
              _addGroupedTvNotification(
                tvNotifications,
                tvShow,
                episodes,
                airDate,
              );
            }
          }
        }
        
        // Also check for person TV work if this show has creators/directors we follow
        await _checkPersonTvWork(tvShow, showDetails, startDateStr, todayStr, tvNotifications);
        
      } catch (e) {
        debugPrint('[ReleaseChecker] Error checking TV show ${tvShow.name}: $e');
      }
    }
    
    return tvNotifications;
  }

  /// Classify an episode as series premiere, season premiere, season finale, special, or regular episode
  String _classifyEpisode(int seasonNumber, int episodeNumber, int totalEpisodesInSeason, Map<String, dynamic> showDetails) {
    // Specials are in season 0
    if (seasonNumber == 0) {
      return 'special';
    }
    
    // Series premiere is S1E1
    if (seasonNumber == 1 && episodeNumber == 1) {
      return 'series_premiere';
    }
    
    // Season premiere is first episode of any season
    if (episodeNumber == 1) {
      return 'season_premiere';
    }
    
    // Season finale is last episode of a season
    if (episodeNumber == totalEpisodesInSeason) {
      return 'season_finale';
    }
    
    // Regular episode
    return 'episode';
  }

  /// Check if user wants notifications for this episode type
  bool _shouldNotifyForEpisodeType(String episodeType, TvNotificationPreferences? showPrefs, TvNotificationPreferences? globalPrefs) {
    // Use show-specific preferences if available, otherwise fall back to global
    final prefs = showPrefs ?? globalPrefs ?? TvNotificationPreferences();
    
    switch (episodeType) {
      case 'series_premiere':
        return prefs.seriesPremiere;
      case 'season_premiere':
        return prefs.seasonPremieres;
      case 'season_finale':
        return prefs.seasonFinales;
      case 'special':
        return prefs.specials;
      case 'episode':
        return prefs.newEpisodes;
      default:
        return false;
    }
  }

  /// Check if we've already been notified for this specific TV episode
  bool _hasBeenNotifiedForTvEpisode(int showId, int seasonNumber, int episodeNumber, String episodeType) {
    final history = _historyRepository.getHistory();
    
    return history.any((h) => 
      h.entry.tmdbId == showId &&
      h.entry.mediaType == 'tv' &&
      h.entry.seasonNumber == seasonNumber &&
      h.entry.episodeNumber == episodeNumber &&
      h.entry.tvNotificationType == episodeType
    );
  }

  /// Add a TV notification to the list
  void _addTvNotification(
    List<NotificationHistoryEntry> list,
    Contributor tvShow,
    Map<String, dynamic> episode,
    String episodeType,
    String airDate,
  ) {
    final now = DateTime.now();
    final notificationTime = now.add(Duration(milliseconds: list.length)).toIso8601String();
    
    final event = NotificationEvent(
      releaseType: episodeType,
      releaseDate: airDate,
      notifiedAt: notificationTime,
    );
    
    final reason = NotificationReason(
      contributorId: tvShow.tmdbId,
      contributorName: tvShow.name,
      department: 'TV Show',
      job: 'Followed Show',
    );
    
    list.add(NotificationHistoryEntry(
      tmdbId: tvShow.tmdbId,
      reasons: [reason],
      notificationEvents: [event],
      mediaType: 'tv',
      seasonNumber: episode['season_number'] as int?,
      episodeNumber: episode['episode_number'] as int?,
      episodeTitle: episode['name'] as String?,
      tvNotificationType: episodeType,
    ));
  }

  /// Add a grouped TV notification for multiple episodes airing on the same day
  void _addGroupedTvNotification(
    List<NotificationHistoryEntry> list,
    Contributor tvShow,
    List<Map<String, dynamic>> episodes,
    String airDate,
  ) {
    final now = DateTime.now();
    final notificationTime = now.add(Duration(milliseconds: list.length)).toIso8601String();
    
    // Determine the primary episode type for the group
    // Priority: series_premiere > season_premiere > season_finale > special > episode
    String groupType = 'grouped_episodes';
    final episodeTypes = episodes.map((e) => e['episode_type'] as String).toSet();
    
    if (episodeTypes.contains('series_premiere')) {
      groupType = 'series_premiere';
    } else if (episodeTypes.contains('season_premiere')) {
      groupType = 'season_premiere';
    } else if (episodeTypes.contains('season_finale')) {
      groupType = 'season_finale';
    } else if (episodeTypes.contains('special')) {
      groupType = 'special';
    }
    
    // Create one NotificationEvent per episode to preserve individual episode details
    final events = episodes.map((episode) {
      // Encode episode information in releaseType field using a more robust format
      // Format: "episode_type|season|episode|title"
      final episodeType = episode['episode_type'] as String;
      final seasonNum = episode['season_number'] as int;
      final episodeNum = episode['episode_number'] as int;
      final episodeTitle = episode['name'] as String? ?? 'Episode $episodeNum';
      
      return NotificationEvent(
        releaseType: '$episodeType|$seasonNum|$episodeNum|$episodeTitle',
        releaseDate: airDate,
        notifiedAt: notificationTime,
      );
    }).toList();
    
    final reason = NotificationReason(
      contributorId: tvShow.tmdbId,
      contributorName: tvShow.name,
      department: 'TV Show',
      job: 'Followed Show',
    );
    
    // Use the first episode for basic info, but indicate it's a group
    final firstEpisode = episodes.first;
    
    list.add(NotificationHistoryEntry(
      tmdbId: tvShow.tmdbId,
      reasons: [reason],
      notificationEvents: events, // Store all episodes as separate events
      mediaType: 'tv',
      seasonNumber: firstEpisode['season_number'] as int?,
      episodeNumber: episodes.length, // Store episode count in episodeNumber field
      episodeTitle: '${episodes.length} episodes', // Indicate multiple episodes
      tvNotificationType: groupType,
    ));
  }

  /// Check if followed people work on this TV show as creators or episode directors
  Future<void> _checkPersonTvWork(
    Contributor tvShow,
    Map<String, dynamic> showDetails,
    String startDateStr,
    String todayStr,
    List<NotificationHistoryEntry> notifications,
  ) async {
    final contributors = _contributorRepository.getContributors();
    final prefs = _preferencesRepository.getPreferences();
    final people = contributors.where((c) => c.type == ContributorType.person).toList();
    
    // Check creators (series premiere notifications)
    final creators = showDetails['created_by'] as List? ?? [];
    for (final creator in creators) {
      final creatorName = creator['name'] as String?;
      if (creatorName == null) continue;
      
      // Find if we follow this creator
      final followedCreator = people.where((p) => p.name.toLowerCase() == creatorName.toLowerCase()).firstOrNull;
      if (followedCreator == null) continue;
      
      // Check if this is a series premiere (S1E1) and we haven't notified yet
      final seriesPremiere = notifications.where((n) => 
        n.tmdbId == tvShow.tmdbId && 
        n.tvNotificationType == 'series_premiere'
      ).firstOrNull;
      
      if (seriesPremiere != null) {
        // Add creator reason to existing series premiere notification
        final creatorReason = NotificationReason(
          contributorId: followedCreator.tmdbId,
          contributorName: followedCreator.name,
          department: 'Creator',
          job: 'Creator',
        );
        
        if (!seriesPremiere.reasons.any((r) => r.contributorId == creatorReason.contributorId)) {
          seriesPremiere.reasons.add(creatorReason);
        }
      }
    }
    
    // Check episode directors (if enabled)
    final shouldNotifyEpisodeWork = prefs.notifyPersonTvEpisodes ?? true;
    if (!shouldNotifyEpisodeWork) return;
    
    for (final notification in notifications) {
      if (notification.mediaType != 'tv' || notification.seasonNumber == null || notification.episodeNumber == null) continue;
      
      try {
        final episodeCredits = await _tmdbService.getTvEpisodeCredits(
          tvShow.tmdbId,
          notification.seasonNumber!,
          notification.episodeNumber!,
        );
        
        final directors = episodeCredits['crew'] as List? ?? [];
        for (final director in directors) {
          if (director['job'] != 'Director') continue;
          
          final directorName = director['name'] as String?;
          if (directorName == null) continue;
          
          // Find if we follow this director
          final followedDirector = people.where((p) => p.name.toLowerCase() == directorName.toLowerCase()).firstOrNull;
          if (followedDirector == null) continue;
          
          // Check person-specific preference override
          final personNotifyTvEpisodes = followedDirector.notifyTvEpisodeWork ?? shouldNotifyEpisodeWork;
          if (!personNotifyTvEpisodes) continue;
          
          // Add director reason to notification
          final directorReason = NotificationReason(
            contributorId: followedDirector.tmdbId,
            contributorName: followedDirector.name,
            department: 'Directing',
            job: 'Director',
          );
          
          if (!notification.reasons.any((r) => r.contributorId == directorReason.contributorId)) {
            notification.reasons.add(directorReason);
          }
        }
      } catch (e) {
        debugPrint('[ReleaseChecker] Error fetching episode credits for S${notification.seasonNumber}E${notification.episodeNumber}: $e');
      }
    }
  }

  /// Add a TV notification for a person contributor to the list
  void _addPersonTvNotification(
    List<NotificationHistoryEntry> list,
    Contributor person,
    Map<String, dynamic> episode,
    String episodeType,
    String airDate,
    int showId,
  ) {
    final now = DateTime.now();
    final notificationTime = now.add(Duration(milliseconds: list.length)).toIso8601String();
    
    final event = NotificationEvent(
      releaseType: episodeType,
      releaseDate: airDate,
      notifiedAt: notificationTime,
    );
    
    final reason = NotificationReason(
      contributorId: person.tmdbId,
      contributorName: person.name,
      department: episode['person_department'] as String? ?? 'Unknown',
      job: episode['person_job'] as String? ?? 'Unknown',
    );
    
    list.add(NotificationHistoryEntry(
      tmdbId: showId,
      reasons: [reason],
      notificationEvents: [event],
      mediaType: 'tv',
      seasonNumber: episode['season_number'] as int?,
      episodeNumber: episode['episode_number'] as int?,
      episodeTitle: episode['name'] as String?,
      tvNotificationType: episodeType,
    ));
  }

  /// Add a grouped TV notification for a person contributor for multiple episodes airing on the same day
  void _addPersonGroupedTvNotification(
    List<NotificationHistoryEntry> list,
    Contributor person,
    List<Map<String, dynamic>> episodes,
    String airDate,
    int showId,
  ) {
    final now = DateTime.now();
    final notificationTime = now.add(Duration(milliseconds: list.length)).toIso8601String();
    
    // Determine the primary episode type for the group
    String groupType = 'grouped_episodes';
    final episodeTypes = episodes.map((e) => e['episode_type'] as String).toSet();
    
    if (episodeTypes.contains('series_premiere')) {
      groupType = 'series_premiere';
    } else if (episodeTypes.contains('season_premiere')) {
      groupType = 'season_premiere';
    } else if (episodeTypes.contains('season_finale')) {
      groupType = 'season_finale';
    } else if (episodeTypes.contains('special')) {
      groupType = 'special';
    }
    
    // Create one NotificationEvent per episode to preserve individual episode details
    final events = episodes.map((episode) {
      final episodeType = episode['episode_type'] as String;
      final seasonNum = episode['season_number'] as int;
      final episodeNum = episode['episode_number'] as int;
      final episodeTitle = episode['name'] as String? ?? 'Episode $episodeNum';
      
      return NotificationEvent(
        releaseType: '$episodeType|$seasonNum|$episodeNum|$episodeTitle',
        releaseDate: airDate,
        notifiedAt: notificationTime,
      );
    }).toList();
    
    // Use the person's role from the first episode (should be consistent across episodes)
    final firstEpisode = episodes.first;
    final reason = NotificationReason(
      contributorId: person.tmdbId,
      contributorName: person.name,
      department: firstEpisode['person_department'] as String? ?? 'Unknown',
      job: firstEpisode['person_job'] as String? ?? 'Unknown',
    );
    
    list.add(NotificationHistoryEntry(
      tmdbId: showId,
      reasons: [reason],
      notificationEvents: events,
      mediaType: 'tv',
      seasonNumber: firstEpisode['season_number'] as int?,
      episodeNumber: episodes.length, // Store episode count
      episodeTitle: '${episodes.length} episodes',
      tvNotificationType: groupType,
    ));
  }

  /// Check if an episode is a rebroadcast/rerun
  /// TMDB doesn't explicitly mark rebroadcasts, but we can use heuristics
  bool _isRebroadcast(Map<String, dynamic> episode) {
    // For now, we don't have reliable rebroadcast detection from TMDB
    // This method is a placeholder for future enhancement when better data is available
    
    // Potential heuristics (not implemented yet due to data limitations):
    // - Episode title contains "rerun", "repeat", "encore"
    // - Episode has already aired and is airing again
    // - Special episode metadata indicating rebroadcast
    
    final episodeName = (episode['name'] as String? ?? '').toLowerCase();
    
    // Basic heuristic: filter out episodes with rerun/repeat in the title
    if (episodeName.contains('rerun') || 
        episodeName.contains('repeat') || 
        episodeName.contains('encore') ||
        episodeName.contains('rebroadcast')) {
      return true;
    }
    
    return false;
  }

  /// Optimized TV processing using TvEfficiencyUpgrade
  Future<void> _processPersonTvShowOptimized(
    List<NotificationHistoryEntry> newNotifications,
    Contributor contributor,
    int showId,
    List<dynamic> groupCredits,
    Preferences prefs,
    String startDateStr,
    String todayStr,
  ) async {
    try {
      debugPrint('[ReleaseChecker] DEBUG: Using optimized TV processing for ${contributor.name} - Show $showId');
      
      // Extract TV credits for this show
      final tvCredits = groupCredits.where((credit) => 
        credit['media_type'] == 'tv' && credit['id'] == showId
      ).cast<Map<String, dynamic>>().toList();
      
      // Use the ultra-efficient TV efficiency processor for single show
      final notifications = await _tvEfficiency.processSingleTvShowUltraEfficient(
        showId: showId,
        contributorName: contributor.name,
        notifyForDepartments: contributor.notifyForDepartments,
        allRolesSelected: contributor.allRolesSelected ?? false,
        startDateStr: startDateStr,
        todayStr: todayStr,
      );
      
      debugPrint('[ReleaseChecker] DEBUG: Optimized processing found ${notifications.length} notifications for ${contributor.name}');
      
      // Group episodes by air date to match original behavior
      final Map<String, List<Map<String, dynamic>>> episodesByDate = {};
      
      // Convert TvEpisodeNotification to episode data and group by date
      for (final notification in notifications) {
        // Check if we've already notified for this episode
        final episodeType = _classifyEpisodeFromNotification(notification);
        if (_hasBeenNotifiedForTvEpisode(
          notification.showId, 
          notification.seasonNumber, 
          notification.episodeNumber, 
          episodeType
        )) {
          debugPrint('[ReleaseChecker] DEBUG: Already notified for S${notification.seasonNumber}E${notification.episodeNumber}');
          continue;
        }
        
        // Create episode data structure
        final episodeData = {
          'id': notification.showId * 1000000 + notification.seasonNumber * 1000 + notification.episodeNumber,
          'name': notification.episodeName,
          'air_date': notification.airDate,
          'season_number': notification.seasonNumber,
          'episode_number': notification.episodeNumber,
          'episode_type': episodeType,
          'person_job': notification.jobTitle,
          'person_department': notification.department,
        };
        
        // Cache episode details
        await _tvCacheRepository.addOrUpdateEpisode(TvEpisodeCacheEntry(
          tmdbId: episodeData['id'] as int,
          showId: notification.showId,
          seasonNumber: notification.seasonNumber,
          episodeNumber: notification.episodeNumber,
          name: notification.episodeName,
          airDate: notification.airDate,
          stillPath: null,
          directors: notification.jobTitle == 'Director' ? [contributor.name] : [],
        ));
        
        // Group by air date
        final airDate = notification.airDate;
        if (!episodesByDate.containsKey(airDate)) {
          episodesByDate[airDate] = [];
        }
        episodesByDate[airDate]!.add(episodeData);
      }
      
      // Create notifications for each date, grouping episodes that air on the same day
      for (final entry in episodesByDate.entries) {
        final airDate = entry.key;
        final episodes = entry.value;
        
        if (episodes.length == 1) {
          // Single episode - create individual notification
          final episode = episodes.first;
          final episodeType = episode['episode_type'] as String;
          
          _addPersonTvNotification(
            newNotifications,
            contributor,
            episode,
            episodeType,
            airDate,
            showId,
          );
        } else {
          // Multiple episodes on same day - create grouped notification
          _addPersonGroupedTvNotification(
            newNotifications,
            contributor,
            episodes,
            airDate,
            showId,
          );
        }
      }
      
    } catch (e) {
      debugPrint('[ReleaseChecker] Error in optimized TV processing for ${contributor.name}: $e');
      // Fall back to original processing on error
      debugPrint('[ReleaseChecker] Falling back to original TV processing');
      await _processPersonTvShowOriginal(
        newNotifications,
        contributor,
        showId,
        groupCredits,
        prefs,
        startDateStr,
        todayStr,
        {},
        {},
      );
    }
  }

  /// Original TV processing logic (fallback)
  Future<void> _processPersonTvShowOriginal(
    List<NotificationHistoryEntry> newNotifications,
    Contributor contributor,
    int movieId,
    List<dynamic> groupCredits,
    Preferences prefs,
    String startDateStr,
    String todayStr,
    Map<int, Map<String, dynamic>> processedShowDetails,
    Map<String, Map<String, dynamic>> processedSeasonDetails,
  ) async {
    try {
      debugPrint('[ReleaseChecker] DEBUG: Using original TV processing for ${contributor.name} - Show $movieId');
      
      // Get TV show details and check for new episodes
      // Phase 1 Optimization: Check in-memory cache first
      Map<String, dynamic> showDetails;
      if (processedShowDetails.containsKey(movieId)) {
        debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Using cached show details for $movieId');
        showDetails = processedShowDetails[movieId]!;
      } else {
        debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Fetching show details for $movieId');
        showDetails = await _tmdbService.getTvDetails(movieId);
        processedShowDetails[movieId] = showDetails;
      }
      
      final showStatus = showDetails['status'] as String? ?? '';
      final lastAirDate = showDetails['last_air_date'] as String?;
      
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Show status: $showStatus, last air date: $lastAirDate');
      
      // Optimization: Skip shows that have ended and their last episode aired before our window
      if (showStatus.toLowerCase() == 'ended' && lastAirDate != null) {
        if (lastAirDate.compareTo(startDateStr) < 0) {
          debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping $movieId (show ended on $lastAirDate, before window $startDateStr)');
          return;
        }
      }
      
      // Cache the show details
      await _tvCacheRepository.addOrUpdateShow(TvShowCacheEntry(
        tmdbId: movieId,
        name: showDetails['name'] ?? 'Unknown',
        posterPath: showDetails['poster_path'],
        firstAirDate: showDetails['first_air_date'],
        status: showDetails['status'],
        creators: (showDetails['created_by'] as List?)?.map((c) => c['name'] as String).toList() ?? [],
        numberOfSeasons: showDetails['number_of_seasons'],
        imdbId: showDetails['external_ids']?['imdb_id'],
        lastAirDate: showDetails['last_air_date'],
        nextEpisodeToAir: showDetails['next_episode_to_air'] as Map<String, dynamic>?,
      ));
      
      // Check if this person is a creator of the show
      final creators = showDetails['created_by'] as List? ?? [];
      final isCreator = creators.any((creator) => 
        (creator['name'] as String?)?.toLowerCase() == contributor.name.toLowerCase()
      );
      
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - isCreator of show: $isCreator');
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Show creators: ${creators.map((c) => c['name']).toList()}');
      
      // Collect all episodes for this show in our date range
      final Map<String, List<Map<String, dynamic>>> episodesByDate = {};
      
      // Get detailed season information to find specific episodes
      final seasons = showDetails['seasons'] as List? ?? [];
      
      debugPrint('[ReleaseChecker] DEBUG: TV show ${showDetails['name']} has ${seasons.length} seasons');
      
      // Optimization: Only check recent seasons (last 3 seasons or those with air dates in our window)
      final recentSeasons = seasons.where((season) {
        final seasonNumber = season['season_number'] as int;
        if (seasonNumber == 0) return false; // Skip specials
        
        final seasonAirDate = season['air_date'] as String?;
        if (seasonAirDate == null) return true; // Include seasons with no air date (might be upcoming)
        
        // Include if aired within our window or in last 3 seasons
        final isInWindow = seasonAirDate.compareTo(startDateStr) >= 0 && seasonAirDate.compareTo(todayStr) <= 0;
        final isRecent = seasons.length - seasonNumber <= 3; // Last 3 seasons
        
        return isInWindow || isRecent;
      }).toList();
      
      debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Checking ${recentSeasons.length} recent seasons out of ${seasons.length}');
      
      for (final season in recentSeasons) {
        final seasonNumber = season['season_number'] as int;
        final seasonAirDate = season['air_date'] as String?;
        
        // Optimization: Skip seasons that haven't aired yet or aired before our window
        if (seasonAirDate != null) {
          if (seasonAirDate.compareTo(todayStr) > 0) {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping season $seasonNumber (airs in future on $seasonAirDate, after window $todayStr)');
            continue;
          }
        }
        
        try {
          // Phase 1 Optimization: Check in-memory cache first
          final cacheKey = '${movieId}_$seasonNumber';
          Map<String, dynamic> seasonDetails;
          if (processedSeasonDetails.containsKey(cacheKey)) {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Using cached season details for S$seasonNumber');
            seasonDetails = processedSeasonDetails[cacheKey]!;
          } else {
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Fetching season details for S$seasonNumber');
            seasonDetails = await _tmdbService.getTvSeasonDetails(movieId, seasonNumber);
            processedSeasonDetails[cacheKey] = seasonDetails;
          }
          
          final episodes = seasonDetails['episodes'] as List? ?? [];
          
          debugPrint('[ReleaseChecker] DEBUG: Season $seasonNumber has ${episodes.length} episodes');
          
          for (final episode in episodes) {
            final airDate = episode['air_date'] as String?;
            if (airDate == null || airDate.isEmpty) continue;
            
            // Check if episode is in our date range
            if (airDate.compareTo(startDateStr) < 0 || airDate.compareTo(todayStr) > 0) {
              continue;
            }
            
            debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Episode ${episode['episode_number']} airs on $airDate (in range)');
            
            // Skip rebroadcasts
            if (_isRebroadcast(episode)) {
              debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Skipping episode ${episode['episode_number']} (rebroadcast)');
              continue;
            }
            
            final episodeNumber = episode['episode_number'] as int;
            final seasonNum = episode['season_number'] as int;
            final episodeName = episode['name'] as String? ?? '';
            
            // Cache episode details
            await _tvCacheRepository.addOrUpdateEpisode(TvEpisodeCacheEntry(
              tmdbId: episode['id'],
              showId: movieId,
              seasonNumber: seasonNum,
              episodeNumber: episodeNumber,
              name: episodeName,
              airDate: airDate,
              stillPath: episode['still_path'],
              directors: (episode['crew'] as List?)
                  ?.where((c) => c['job'] == 'Director')
                  .map((c) => c['name'] as String)
                  .toList() ?? [],
            ));
            
            // Determine episode type
            final episodeType = _classifyEpisode(seasonNum, episodeNumber, episodes.length, showDetails);
            
            // Check if we've already notified for this episode
            if (_hasBeenNotifiedForTvEpisode(movieId, seasonNum, episodeNumber, episodeType)) {
              debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Already notified for S${seasonNum}E${episodeNumber}');
              continue;
            }
            
            // Check if person should be notified for this episode
            bool shouldNotify = false;
            String jobTitle = 'Unknown';
            String department = 'Unknown';
            
            if (isCreator) {
              // Creator gets notified for all episodes (if they have Creator role selected OR if TV notifications are enabled)
              final interestedDepartments = contributor.notifyForDepartments;
              final isTrueAll = contributor.allRolesSelected ?? false;
              
              debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} - Checking creator notification: isTrueAll=$isTrueAll, hasCreator=${interestedDepartments.contains('Creator')}, notifyPersonTvEpisodes=${prefs.notifyPersonTvEpisodes}');
              
              // Notify if: True All is enabled, Creator is in departments, or TV episode notifications are globally enabled
              if (isTrueAll || interestedDepartments.contains('Creator') || (prefs.notifyPersonTvEpisodes ?? true)) {
                shouldNotify = true;
                jobTitle = 'Creator';
                department = 'Creator';
                debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} should be notified as Creator for S${seasonNum}E${episodeNumber}');
              }
            }
            
            // Check if person is director of this specific episode
            if (!shouldNotify) {
              try {
                final episodeCredits = await _tmdbService.getTvEpisodeCredits(movieId, seasonNum, episodeNumber);
                final directors = episodeCredits['crew'] as List? ?? [];
                
                final isDirector = directors.any((director) => 
                  director['job'] == 'Director' && 
                  (director['name'] as String?)?.toLowerCase() == contributor.name.toLowerCase()
                );
                
                if (isDirector) {
                  final interestedDepartments = contributor.notifyForDepartments;
                  final isTrueAll = contributor.allRolesSelected ?? false;
                  
                  if (isTrueAll || interestedDepartments.contains('Director')) {
                    shouldNotify = true;
                    jobTitle = 'Director';
                    department = 'Directing';
                    debugPrint('[ReleaseChecker] DEBUG: ${contributor.name} should be notified as Director');
                  }
                }
              } catch (e) {
                debugPrint('[ReleaseChecker] Error fetching episode credits: $e');
              }
            }
            
            if (shouldNotify) {
              // Add episode to the date group
              if (!episodesByDate.containsKey(airDate)) {
                episodesByDate[airDate] = [];
              }
              
              // Add episode with person's role information
              final episodeWithRole = Map<String, dynamic>.from(episode);
              episodeWithRole['episode_type'] = episodeType;
              episodeWithRole['person_job'] = jobTitle;
              episodeWithRole['person_department'] = department;
              episodesByDate[airDate]!.add(episodeWithRole);
            }
          }
        } catch (e) {
          debugPrint('[ReleaseChecker] Error fetching season $seasonNumber: $e');
        }
      }
      
      // Create notifications for each date, grouping episodes that air on the same day
      for (final entry in episodesByDate.entries) {
        final airDate = entry.key;
        final episodes = entry.value;
        
        if (episodes.length == 1) {
          // Single episode - create individual notification
          final episode = episodes.first;
          final episodeType = episode['episode_type'] as String;
          
          _addPersonTvNotification(
            newNotifications,
            contributor,
            episode,
            episodeType,
            airDate,
            movieId,
          );
        } else {
          // Multiple episodes on same day - create grouped notification
          _addPersonGroupedTvNotification(
            newNotifications,
            contributor,
            episodes,
            airDate,
            movieId,
          );
        }
      }
      
    } catch (e) {
      debugPrint('[ReleaseChecker] Error in original TV processing for ${contributor.name}: $e');
    }
  }

  /// Helper method to classify episode type from TvEpisodeNotification
  String _classifyEpisodeFromNotification(TvEpisodeNotification notification) {
    // Simple classification based on season and episode numbers
    if (notification.seasonNumber == 1 && notification.episodeNumber == 1) {
      return 'Series Premiere';
    } else if (notification.episodeNumber == 1) {
      return 'Season Premiere';
    } else {
      return 'Regular Episode';
    }
  }

  /// Private helper to update cached contributor details
  Future<void> _updateContributorDetail(Contributor contributor, List<dynamic> allCredits) async {
    if (_contributorDetailRepository == null) {
      debugPrint('[ReleaseChecker] ContributorDetailRepository is null, skipping detail update for ${contributor.name}');
      return;
    }

    debugPrint('[ReleaseChecker] Updating contributor detail for ${contributor.name} (${contributor.tmdbId}) with ${allCredits.length} credits');

    final now = DateTime.now();
    final List<Work> allWorks = [];
    
    // Group credits by ID to combine roles (e.g. Director and Writer on same film)
    final Map<int, List<dynamic>> groupedCredits = {};
    for (final credit in allCredits) {
      if (credit == null || credit['id'] == null) continue;
      final id = credit['id'] as int;
      groupedCredits.putIfAbsent(id, () => []).add(credit);
    }

    for (final entry in groupedCredits.entries) {
      final id = entry.key;
      final credits = entry.value;
      final first = credits.first;
      
      final mediaType = first['media_type'] as String?;
      
      // Determine work type
      WorkType workType;
      if (mediaType == 'tv') {
        // Check if it's an episode (has episode_number)
        if (first['episode_number'] != null) {
          workType = WorkType.tvEpisode;
        } else {
          workType = WorkType.tvShow;
        }
      } else {
        workType = WorkType.movie;
      }
      
      // Release dates can be under various keys depending on API endpoint
      final releaseDateStr = (first['release_date'] ?? first['first_air_date'] ?? first['air_date']) as String?;
      DateTime? releaseDate;
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        // Only take the YYYY-MM-DD part
        final datePart = releaseDateStr.length >= 10 ? releaseDateStr.substring(0, 10) : releaseDateStr;
        releaseDate = DateTime.tryParse(datePart);
      }

      final roles = credits.map((c) {
        // For cast members (actors), TMDB doesn't provide a department field
        // We need to detect this and set it to 'Acting' so it maps to 'Actor'
        String? department = c['department'] as String?;
        final character = c['character'] as String?;
        final job = c['job'] as String?;
        
        // If we have a character field (even if empty) and no job, this is a cast member (actor)
        // Cast members have 'character' field, crew members have 'job' field
        if (character != null && job == null && (department == null || department == 'null' || department.isEmpty)) {
          department = 'Acting';
        }
        
        return ContributorRole(
          contributorId: contributor.tmdbId,
          contributorName: contributor.name,
          role: (job ?? character ?? (contributor.type == ContributorType.movie ? 'Movie' : (c['media_type'] == 'tv' ? 'TV Show' : 'Cast/Crew'))) as String,
          department: department,
          character: character,
        );
      }).toList();

      allWorks.add(Work(
        tmdbId: id,
        title: (first['title'] ?? first['name'] ?? 'Unknown') as String,
        posterPath: first['poster_path'] ?? first['still_path'] as String?,
        releaseDate: releaseDate,
        type: workType,
        tmdbRating: (first['vote_average'] as num?)?.toDouble(),
        popularity: (first['popularity'] as num?)?.toDouble(),
        voteCount: first['vote_count'] as int?,
        contributorRoles: roles,
        imdbId: first['external_ids']?['imdb_id'] ?? first['imdb_id'] as String?,
        seasonNumber: first['season_number'] as int?,
        episodeNumber: first['episode_number'] as int?,
      ));
    }

    // Separate upcoming vs past/present
    // For "upcoming", we want future dates
    final upcoming = allWorks.where((w) => w.releaseDate != null && w.releaseDate!.isAfter(now)).toList();
    // For "latest", we want past or present dates
    final past = allWorks.where((w) => w.releaseDate != null && !w.releaseDate!.isAfter(now)).toList();
    
    // Use WorkSortingLogic to sort and limit
    var sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(upcoming);
    var sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(past);
    var sortedHits = WorkSortingLogic.rankBiggestHits(allWorks);

    // ENHANCEMENT: Fetch all episodes from seasons where person has credits
    if (contributor.type == ContributorType.person) {
      final List<Work> relevantTvShows = [
        ...sortedUpcoming.where((w) => w.type == WorkType.tvShow),
        ...sortedLatest.where((w) => w.type == WorkType.tvShow),
        ...sortedHits.where((w) => w.type == WorkType.tvShow),
      ].toSet().take(10).toList();

      if (relevantTvShows.isNotEmpty) {
        debugPrint('[ReleaseChecker] Enriched detail: Fetching episodes for ${relevantTvShows.length} shows');
        
        // First, identify which seasons have the person's credits
        final Map<int, Set<int>> showSeasons = {}; // showId -> set of season numbers
        
        for (final credit in allCredits) {
          if (credit == null || credit['media_type'] != 'tv') continue;
          final showId = credit['id'] as int?;
          final seasonNum = credit['season_number'] as int?;
          
          if (showId != null && seasonNum != null) {
            showSeasons.putIfAbsent(showId, () => {}).add(seasonNum);
          }
        }
        
        // Now fetch all episodes from those seasons
        for (final show in relevantTvShows) {
          try {
            final seasons = showSeasons[show.tmdbId] ?? {};
            
            if (seasons.isEmpty) {
              // Fallback: fetch next and last episodes if no season info
              final details = await _tmdbService.getTvDetailsWithEpisodes(show.tmdbId);
              final List<Map<String, dynamic>> episodes = [];
              if (details['next_episode_to_air'] != null) episodes.add(Map<String, dynamic>.from(details['next_episode_to_air']));
              if (details['last_episode_to_air'] != null) episodes.add(Map<String, dynamic>.from(details['last_episode_to_air']));
              
              for (final ep in episodes) {
                _addEpisodeToWorks(allWorks, show, ep);
              }
            } else {
              // Fetch all episodes from the seasons where person has credits
              for (final seasonNum in seasons) {
                try {
                  final seasonDetails = await _tmdbService.getTvSeasonDetails(show.tmdbId, seasonNum);
                  final seasonEpisodes = seasonDetails['episodes'] as List? ?? [];
                  
                  for (final ep in seasonEpisodes) {
                    _addEpisodeToWorks(allWorks, show, ep);
                  }
                } catch (e) {
                  debugPrint('[ReleaseChecker] Error fetching season $seasonNum for show ${show.title}: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('[ReleaseChecker] Error fetching episodes for show ${show.title}: $e');
          }
        }

        // Re-sort everything after adding episodes and filter out duplicates
        final allWorksEnriched = List<Work>.from(allWorks);
        
        // Logical de-duplication: If we have episodes for a show, remove the generic show entry from history/hits
        final Set<String> showsWithEpisodes = allWorksEnriched
            .where((w) => w.type == WorkType.tvEpisode)
            .map((w) => TvShowDisplayLogic.extractShowTitle(w.title))
            .toSet();
        
        final filteredWorks = allWorksEnriched.where((w) {
          if (w.type == WorkType.tvShow) {
            return !showsWithEpisodes.contains(w.title);
          }
          return true;
        }).toList();

        final upcomingEnriched = filteredWorks.where((w) => w.releaseDate != null && w.releaseDate!.isAfter(now)).toList();
        final pastEnriched = filteredWorks.where((w) => w.releaseDate != null && !w.releaseDate!.isAfter(now)).toList();
        
        sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(upcomingEnriched);
        sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(pastEnriched);
        
        // For hits: Get top hits FIRST, then filter and sort by date
        final topHits = WorkSortingLogic.rankBiggestHits(filteredWorks);
        sortedHits = List<Work>.from(topHits)..sort((a, b) {
          if (a.releaseDate == null && b.releaseDate == null) return 0;
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return b.releaseDate!.compareTo(a.releaseDate!);
        });
      }
    }

    final detail = ContributorDetail(
      tmdbId: contributor.tmdbId,
      name: contributor.name,
      profilePath: contributor.profilePath,
      imdbId: contributor.imdbId,
      type: contributor.type,
      upcomingWorks: sortedUpcoming,
      latestReleases: sortedLatest,
      biggestHits: sortedHits,
      lastUpdated: now,
    );

    await _contributorDetailRepository!.cacheContributorDetail(detail);
    debugPrint('[ReleaseChecker] Successfully cached contributor detail for ${contributor.name}');
  }

  /// Helper method to add an episode to the works list
  void _addEpisodeToWorks(List<Work> works, Work show, Map<String, dynamic> ep) {
    final airDateStr = ep['air_date'] as String?;
    DateTime? airDate;
    if (airDateStr != null && airDateStr.isNotEmpty) {
      airDate = DateTime.tryParse(airDateStr);
    }

    works.add(Work(
      tmdbId: ep['id'],
      title: '${show.title} - S${ep['season_number'].toString().padLeft(2, '0')}E${ep['episode_number'].toString().padLeft(2, '0')} - ${ep['name']}',
      posterPath: show.posterPath ?? ep['still_path'],
      releaseDate: airDate,
      type: WorkType.tvEpisode,
      tmdbRating: (ep['vote_average'] as num?)?.toDouble(),
      voteCount: ep['vote_count'] as int?,
      popularity: show.popularity,
      contributorRoles: show.contributorRoles,
      imdbId: show.imdbId,
      seasonNumber: ep['season_number'],
      episodeNumber: ep['episode_number'],
      showId: show.tmdbId,
    ));
  }
}