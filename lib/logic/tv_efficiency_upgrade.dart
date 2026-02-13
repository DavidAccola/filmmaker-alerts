import '../data/services/tmdb_service.dart';

/// Drop-in replacement for TV processing that follows Copilot's efficiency recommendations
class TvEfficiencyUpgrade {
  final dynamic _tmdbService; // Use dynamic to allow mocking
  
  // Caches scoped to a single check run
  final Map<int, Map<String, dynamic>> _showCache = {};
  final Map<String, Map<String, dynamic>> _seasonCache = {};
  final Map<String, Map<String, dynamic>> _episodeCreditsCache = {};
  
  TvEfficiencyUpgrade(this._tmdbService);
  
  /// Clear caches (call at start of each check run)
  void clearCaches() {
    _showCache.clear();
    _seasonCache.clear();
    _episodeCreditsCache.clear();
  }
  
  /// Optimized TV processing following Copilot's 4-step approach
  Future<List<TvEpisodeNotification>> processPersonTvShows({
    required List<Map<String, dynamic>> tvCredits,
    required String contributorName,
    required List<String> notifyForDepartments,
    required bool allRolesSelected,
    required String startDateStr,
    required String todayStr,
  }) async {
    
    final notifications = <TvEpisodeNotification>[];
    
    // Step 1: Extract unique show IDs from combined_credits
    final showIds = tvCredits
        .map((credit) => credit['id'] as int?)
        .where((id) => id != null)
        .cast<int>()
        .toSet()
        .toList();
    
    // Step 2: Filter candidate shows efficiently
    final candidates = await _filterShowCandidates(showIds, startDateStr);
    
    // Step 3: Process each candidate show
    for (final candidate in candidates) {
      try {
        final episodeNotifications = await _processShow(
          candidate,
          contributorName,
          notifyForDepartments,
          allRolesSelected,
          startDateStr,
          todayStr,
          tvCredits,
        );
        notifications.addAll(episodeNotifications);
      } catch (e) {
      }
    }
    
    return notifications;
  }

  /// Process a single TV show (for integration with existing code)
  Future<List<TvEpisodeNotification>> processSingleTvShow({
    required int showId,
    required List<Map<String, dynamic>> tvCredits,
    required String contributorName,
    required List<String> notifyForDepartments,
    required bool allRolesSelected,
    required String startDateStr,
    required String todayStr,
  }) async {
    
    final notifications = <TvEpisodeNotification>[];
    
    try {
      // Get show details with append_to_response (single efficient call)
      Map<String, dynamic> showDetails;
      if (_showCache.containsKey(showId)) {
        showDetails = _showCache[showId]!;
      } else {
        showDetails = await _tmdbService.getTvDetailsOptimized(showId);
        _showCache[showId] = showDetails;
      }
      
      final candidate = TvShowCandidate.fromTmdbData(showId, showDetails);
      
      // Quick filter using next_episode_to_air/last_episode_to_air
      if (_isShowRelevant(candidate, startDateStr)) {
        final episodeNotifications = await _processShow(
          candidate,
          contributorName,
          notifyForDepartments,
          allRolesSelected,
          startDateStr,
          todayStr,
          tvCredits,
        );
        notifications.addAll(episodeNotifications);
      }
      
    } catch (e) {
    }
    
    return notifications;
  }

  /// Ultra-efficient method using only next/last episode data (no season calls)
  Future<List<TvEpisodeNotification>> processSingleTvShowUltraEfficient({
    required int showId,
    required String contributorName,
    required List<String> notifyForDepartments,
    required bool allRolesSelected,
    required String startDateStr,
    required String todayStr,
  }) async {
    final notifications = <TvEpisodeNotification>[];
    
    try {
      // Use the new efficient method from TMDB service
      final episodes = await _tmdbService.getTvNewEpisodesEfficient(showId, startDateStr, todayStr);
      
      if (episodes.isEmpty) {
        return notifications;
      }
      
      // Get basic show details for name and creators (cached)
      Map<String, dynamic> showDetails;
      if (_showCache.containsKey(showId)) {
        showDetails = _showCache[showId]!;
      } else {
        showDetails = await _tmdbService.getTvDetailsBasic(showId);
        _showCache[showId] = showDetails;
      }
      
      final showName = showDetails['name'] as String? ?? 'Unknown Show';
      
      // Check if this person is actually a creator of the show
      final creators = showDetails['created_by'] as List? ?? [];
      final isCreatorOfShow = creators.any((creator) => 
        (creator['name'] as String?)?.toLowerCase() == contributorName.toLowerCase()
      );
      
      for (final episode in episodes) {
        final seasonNumber = episode['season_number'] as int? ?? 1;
        final episodeNumber = episode['episode_number'] as int? ?? 1;
        final airDate = episode['air_date'] as String? ?? '';
        final episodeName = episode['name'] as String? ?? '';
        
        if (airDate.isEmpty) continue;
        
        // Only notify for creators if this person is actually a creator of the show
        if (isCreatorOfShow && (allRolesSelected || notifyForDepartments.contains('Creator'))) {
          notifications.add(TvEpisodeNotification(
            showId: showId,
            showName: showName,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeName: episodeName,
            airDate: airDate,
            jobTitle: 'Creator',
            department: 'Creator',
          ));
        } else if (!isCreatorOfShow) {
          // Only check episode credits if person is NOT a creator of the show
          // This is the only place we make episode credit calls, and only when necessary
          final roleResult = await _checkEpisodeRole(
            showId,
            seasonNumber,
            episodeNumber,
            contributorName,
            notifyForDepartments,
            allRolesSelected,
            false, // isCreator = false (we already checked above)
          );
          
          if (roleResult.shouldNotify) {
            notifications.add(TvEpisodeNotification(
              showId: showId,
              showName: showName,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
              episodeName: episodeName,
              airDate: airDate,
              jobTitle: roleResult.jobTitle,
              department: roleResult.department,
            ));
          }
        }
      }
      
    } catch (e) {
    }
    
    return notifications;
  }
  
  /// Step 2: Filter shows using efficient single-call data
  Future<List<TvShowCandidate>> _filterShowCandidates(
    List<int> showIds, 
    String startDateStr
  ) async {
    final candidates = <TvShowCandidate>[];
    
    for (final showId in showIds) {
      try {
        // Get show details with append_to_response (single efficient call)
        Map<String, dynamic> showDetails;
        if (_showCache.containsKey(showId)) {
          showDetails = _showCache[showId]!;
        } else {
          showDetails = await _tmdbService.getTvDetailsOptimized(showId);
          _showCache[showId] = showDetails;
        }
        
        final candidate = TvShowCandidate.fromTmdbData(showId, showDetails);
        
        // Quick filter using next_episode_to_air/last_episode_to_air
        if (_isShowRelevant(candidate, startDateStr)) {
          candidates.add(candidate);
        }
        
      } catch (e) {
      }
    }
    
    return candidates;
  }
  
  /// Quick relevance check using efficient data
  bool _isShowRelevant(TvShowCandidate candidate, String startDateStr) {
    // Always relevant if in production or has upcoming episodes
    if (candidate.inProduction || candidate.nextEpisode != null) {
      return true;
    }
    
    // Relevant if ended recently
    if (candidate.status.toLowerCase() == 'ended' && candidate.lastAirDate != null) {
      return candidate.lastAirDate!.compareTo(startDateStr) >= 0;
    }
    
    // Relevant if has recent episode activity
    if (candidate.lastEpisode != null) {
      final lastEpAirDate = candidate.lastEpisode!['air_date'] as String?;
      if (lastEpAirDate != null) {
        return lastEpAirDate.compareTo(startDateStr) >= 0;
      }
    }
    
    return false;
  }
  
  /// Step 3: Process individual show efficiently
  Future<List<TvEpisodeNotification>> _processShow(
    TvShowCandidate candidate,
    String contributorName,
    List<String> notifyForDepartments,
    bool allRolesSelected,
    String startDateStr,
    String todayStr,
    List<Map<String, dynamic>> tvCredits,
  ) async {
    
    final notifications = <TvEpisodeNotification>[];
    
    // Determine if person is a creator
    final isCreator = _isCreatorOfShow(candidate.showId, tvCredits);
    
    // Step 4: Smart season selection using seasons metadata
    final relevantSeasons = _findRelevantSeasons(
      candidate.seasons,
      candidate.nextEpisode,
      candidate.lastEpisode,
      startDateStr,
      todayStr,
    );
    
    // Only call season endpoint when we need episode lists
    for (final seasonInfo in relevantSeasons) {
      final seasonNumber = seasonInfo['season_number'] as int;
      
      final episodes = await _getSeasonEpisodes(candidate.showId, seasonNumber);
      
      for (final episode in episodes) {
        final airDate = episode['air_date'] as String?;
        if (airDate == null || airDate.isEmpty) continue;
        
        // Filter by date range
        if (airDate.compareTo(startDateStr) < 0 || airDate.compareTo(todayStr) > 0) {
          continue;
        }
        
        final episodeNumber = episode['episode_number'] as int;
        
        // Smart episode role checking
        final roleResult = await _checkEpisodeRole(
          candidate.showId,
          seasonNumber,
          episodeNumber,
          contributorName,
          notifyForDepartments,
          allRolesSelected,
          isCreator,
        );
        
        if (roleResult.shouldNotify) {
          notifications.add(TvEpisodeNotification(
            showId: candidate.showId,
            showName: candidate.name,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeName: episode['name'] as String? ?? '',
            airDate: airDate,
            jobTitle: roleResult.jobTitle,
            department: roleResult.department,
          ));
        }
      }
    }
    
    return notifications;
  }
  
  /// Find seasons likely to have episodes in our date range
  List<Map<String, dynamic>> _findRelevantSeasons(
    List seasons,
    Map<String, dynamic>? nextEpisode,
    Map<String, dynamic>? lastEpisode,
    String startDateStr,
    String todayStr,
  ) {
    final relevant = <Map<String, dynamic>>[];
    
    // Use next_episode_to_air and last_episode_to_air for smart targeting
    final nextSeasonNum = nextEpisode?['season_number'] as int?;
    final lastSeasonNum = lastEpisode?['season_number'] as int?;
    
    for (final season in seasons) {
      final seasonMap = season as Map<String, dynamic>;
      final seasonNumber = seasonMap['season_number'] as int? ?? 0;
      
      // Skip specials unless they're specifically mentioned
      if (seasonNumber == 0 && seasonNumber != nextSeasonNum && seasonNumber != lastSeasonNum) {
        continue;
      }
      
      // Include if it has next or last episode
      if (seasonNumber == nextSeasonNum || seasonNumber == lastSeasonNum) {
        relevant.add(seasonMap);
        continue;
      }
      
      // Include recent seasons that might have episodes in range
      final airDate = seasonMap['air_date'] as String?;
      if (airDate != null && airDate.isNotEmpty) {
        if (airDate.compareTo(startDateStr) >= 0) {
          relevant.add(seasonMap);
        }
      }
    }
    
    // If no seasons found via smart targeting, fall back to last 2 seasons
    if (relevant.isEmpty && seasons.isNotEmpty) {
      final sortedSeasons = List<Map<String, dynamic>>.from(seasons)
        ..sort((a, b) => (b['season_number'] as int).compareTo(a['season_number'] as int));
      
      relevant.addAll(sortedSeasons.take(2));
    }
    
    return relevant;
  }
  
  /// Get season episodes with caching
  Future<List> _getSeasonEpisodes(int showId, int seasonNumber) async {
    final cacheKey = '${showId}_$seasonNumber';
    
    if (_seasonCache.containsKey(cacheKey)) {
      final cached = _seasonCache[cacheKey]!;
      return cached['episodes'] as List? ?? [];
    }
    
    final seasonDetails = await _tmdbService.getTvSeasonDetails(showId, seasonNumber);
    _seasonCache[cacheKey] = seasonDetails;
    
    return seasonDetails['episodes'] as List? ?? [];
  }
  
  /// Smart episode role checking - only call episode credits when needed
  Future<EpisodeRoleResult> _checkEpisodeRole(
    int showId,
    int seasonNumber,
    int episodeNumber,
    String contributorName,
    List<String> notifyForDepartments,
    bool allRolesSelected,
    bool isCreator,
  ) async {
    
    // Creators get notified without episode credit check
    if (isCreator && (allRolesSelected || notifyForDepartments.contains('Creator'))) {
      return EpisodeRoleResult(
        shouldNotify: true,
        jobTitle: 'Creator',
        department: 'Creator',
      );
    }
    
    // Only check episode credits if person might have episode-specific roles
    if (!_shouldCheckEpisodeCredits(notifyForDepartments)) {
      return EpisodeRoleResult(
        shouldNotify: false,
        jobTitle: 'Unknown',
        department: 'Unknown',
      );
    }
    
    // Get episode credits with caching
    final cacheKey = '${showId}_${seasonNumber}_$episodeNumber';
    Map<String, dynamic> episodeCredits;
    
    if (_episodeCreditsCache.containsKey(cacheKey)) {
      episodeCredits = _episodeCreditsCache[cacheKey]!;
    } else {
      episodeCredits = await _tmdbService.getTvEpisodeCredits(showId, seasonNumber, episodeNumber);
      _episodeCreditsCache[cacheKey] = episodeCredits;
    }
    
    return _findPersonInEpisodeCredits(episodeCredits, contributorName, notifyForDepartments);
  }
  
  /// Check if we should call episode credits API
  bool _shouldCheckEpisodeCredits(List<String> notifyForDepartments) {
    return notifyForDepartments.any((dept) => 
      dept.toLowerCase().contains('director') ||
      dept.toLowerCase().contains('writer') ||
      dept.toLowerCase().contains('crew') ||
      dept.toLowerCase().contains('acting')
    );
  }
  
  /// Find person in episode credits
  EpisodeRoleResult _findPersonInEpisodeCredits(
    Map<String, dynamic> episodeCredits,
    String contributorName,
    List<String> notifyForDepartments,
  ) {
    final crew = episodeCredits['crew'] as List? ?? [];
    final cast = episodeCredits['cast'] as List? ?? [];
    
    // Check crew roles
    for (final member in crew) {
      final name = member['name'] as String? ?? '';
      final job = member['job'] as String? ?? '';
      final department = member['department'] as String? ?? '';
      
      if (name.toLowerCase() == contributorName.toLowerCase()) {
        if (_isInterestedInJob(job, department, notifyForDepartments)) {
          return EpisodeRoleResult(
            shouldNotify: true,
            jobTitle: job,
            department: department,
          );
        }
      }
    }
    
    // Check cast roles
    for (final member in cast) {
      final name = member['name'] as String? ?? '';
      if (name.toLowerCase() == contributorName.toLowerCase()) {
        if (notifyForDepartments.any((dept) => dept.toLowerCase().contains('acting'))) {
          return EpisodeRoleResult(
            shouldNotify: true,
            jobTitle: 'Actor',
            department: 'Acting',
          );
        }
      }
    }
    
    return EpisodeRoleResult(
      shouldNotify: false,
      jobTitle: 'Unknown',
      department: 'Unknown',
    );
  }
  
  bool _isInterestedInJob(String job, String department, List<String> interests) {
    final jobLower = job.toLowerCase();
    final deptLower = department.toLowerCase();
    
    for (final interest in interests) {
      final interestLower = interest.toLowerCase();
      if (jobLower.contains(interestLower) || 
          deptLower.contains(interestLower) ||
          interestLower.contains(jobLower) ||
          interestLower.contains(deptLower)) {
        return true;
      }
    }
    
    return false;
  }
  
  bool _isCreatorOfShow(int showId, List<Map<String, dynamic>> tvCredits) {
    return tvCredits.any((credit) => 
      credit['id'] == showId && 
      (credit['job'] as String?)?.toLowerCase().contains('creator') == true
    );
  }
}

class TvEpisodeNotification {
  final int showId;
  final String showName;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeName;
  final String airDate;
  final String jobTitle;
  final String department;
  
  TvEpisodeNotification({
    required this.showId,
    required this.showName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeName,
    required this.airDate,
    required this.jobTitle,
    required this.department,
  });
}

class EpisodeRoleResult {
  final bool shouldNotify;
  final String jobTitle;
  final String department;
  
  EpisodeRoleResult({
    required this.shouldNotify,
    required this.jobTitle,
    required this.department,
  });
}