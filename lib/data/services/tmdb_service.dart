import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RateLimitEvent {
  final int waitTimeSeconds;
  final int retryCount;
  final int maxRetries;

  RateLimitEvent({
    required this.waitTimeSeconds,
    required this.retryCount,
    required this.maxRetries,
  });
}

class TmdbService {
  final Dio _dio;
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  
  final _rateLimitController = StreamController<RateLimitEvent>.broadcast();
  Stream<RateLimitEvent> get onRateLimit => _rateLimitController.stream;

  TmdbService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              queryParameters: {'api_key': dotenv.env['TMDB_API_KEY']},
            )) {
    if (dio == null) {
      _dio.interceptors.add(_RateLimitInterceptor(_dio, _emitRateLimitEvent));
    } else {
       // See tmdb_service.dart comments for why we add this even to injected Dio
       _dio.interceptors.add(_RateLimitInterceptor(_dio, _emitRateLimitEvent));
    }
  }

  void _emitRateLimitEvent(RateLimitEvent event) {
    _rateLimitController.add(event);
  }
  
  void dispose() {
    _rateLimitController.close();
  }

  Dio get client => _dio;

  /// Helper method to log API calls
  void _logApiCall(String endpoint, [Map<String, dynamic>? params]) {
  }

  // --- Search ---
  Future<Map<String, dynamic>> searchPerson(String query, {int page = 1}) async {
    final endpoint = '/search/person';
    final params = {'query': query, 'page': page};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> searchCompany(String query, {int page = 1}) async {
    final endpoint = '/search/company';
    final params = {'query': query, 'page': page};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> searchMovie(String query, {int page = 1}) async {
    final endpoint = '/search/movie';
    final params = {'query': query, 'page': page};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> searchCollection(String query, {int page = 1}) async {
    final endpoint = '/search/collection';
    final params = {'query': query, 'page': page};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> searchTv(String query, {int page = 1}) async {
    final endpoint = '/search/tv';
    final params = {'query': query, 'page': page};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  // --- Trending ---
  Future<Map<String, dynamic>> getTrendingMovies() async {
    final response = await _dio.get('/trending/movie/week');
    return response.data;
  }

  Future<Map<String, dynamic>> getTrendingPeople() async {
    final response = await _dio.get('/trending/person/week');
    return response.data;
  }

  Future<Map<String, dynamic>> getPopularPeople() async {
    final response = await _dio.get('/person/popular');
    return response.data;
  }

  Future<Map<String, dynamic>> getUpcomingMovies() async {
    final response = await _dio.get('/movie/upcoming', queryParameters: {'region': 'US'});
    return response.data;
  }

  // --- Details & Credits ---
  Future<Map<String, dynamic>> getPersonDetails(int id) async {
    final endpoint = '/person/$id';
    final params = {'append_to_response': 'external_ids'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getPersonCombinedCredits(int id) async {
    final endpoint = '/person/$id/combined_credits';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  Future<Map<String, dynamic>> getCompanyCredits(int id, String type, {String? since}) async {
    // type is 'movie' or 'tv'
    final endpoint = '/discover/$type';
    final params = {
      'with_companies': id,
      'sort_by': type == 'movie' ? 'primary_release_date.desc' : 'first_air_date.desc',
    };
    if (since != null) {
      if (type == 'movie') {
        params['primary_release_date.gte'] = since;
      } else {
        params['first_air_date.gte'] = since;
      }
    }
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getCompanyTopWorks(int id) async {
    // Try movies first
    try {
      final movieResponse = await _dio.get('/discover/movie', queryParameters: {
        'with_companies': id,
        'sort_by': 'popularity.desc',
        'page': 1,
      });
      final results = movieResponse.data['results'] as List?;
      
      if (results != null && results.isNotEmpty) {
        return movieResponse.data;
      }

      // If no movies found, try TV Shows (Fallback)
      final tvResponse = await _dio.get('/discover/tv', queryParameters: {
        'with_companies': id,
        'sort_by': 'popularity.desc',
        'page': 1,
      });
      
      // Map TV results to use 'title' field (TV uses 'name')
      final tvData = tvResponse.data;
      if (tvData['results'] != null) {
        tvData['results'] = (tvData['results'] as List).map((t) {
           t['title'] = t['name'];
           return t;
        }).toList();
      }
      return tvData;
      
    } catch (_) {
      return {'results': []};
    }
  }

  /// Fetches upcoming movies and TV shows for a company
  /// Uses discover endpoint with future release/air dates
  Future<Map<String, dynamic>> getCompanyUpcomingWorks(int id) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    try {
      // Fetch upcoming movies
      final movieResponse = await _dio.get('/discover/movie', queryParameters: {
        'with_companies': id,
        'primary_release_date.gte': todayStr,
        'sort_by': 'primary_release_date.asc',
        'page': 1,
      });
      
      final movieResults = movieResponse.data['results'] as List? ?? [];
      
      // Fetch upcoming TV shows
      final tvResponse = await _dio.get('/discover/tv', queryParameters: {
        'with_companies': id,
        'first_air_date.gte': todayStr,
        'sort_by': 'first_air_date.asc',
        'page': 1,
      });
      
      final tvResults = tvResponse.data['results'] as List? ?? [];
      
      // Map TV results to use 'title' field (TV uses 'name')
      final mappedTvResults = tvResults.map((t) {
        t['title'] = t['name'];
        t['media_type'] = 'tv';
        return t;
      }).toList();
      
      // Combine and sort by date
      final allResults = [...movieResults, ...mappedTvResults];
      allResults.sort((a, b) {
        final dateA = a['primary_release_date'] ?? a['first_air_date'] ?? '';
        final dateB = b['primary_release_date'] ?? b['first_air_date'] ?? '';
        return dateA.compareTo(dateB);
      });
      
      return {
        'results': allResults,
        'total_results': allResults.length,
      };
    } catch (_) {
      return {'results': []};
    }
  }

  /// Filters a list of discover results to only include works where [companyId]
  /// appears in the work's `production_companies`. This distinguishes actual
  /// production from distribution-only associations.
  ///
  /// Movies are verified via `/movie/{id}`, TV shows via `/tv/{id}`.
  /// Works that fail to fetch details are kept (benefit of the doubt).
  Future<List<dynamic>> filterToProductionOnly(List<dynamic> discoverResults, int companyId) async {
    if (discoverResults.isEmpty) return discoverResults;

    final futures = discoverResults.map((work) async {
      final id = work['id'] as int?;
      if (id == null) return work; // keep if no id

      try {
        final mediaType = work['media_type'] as String?;
        final isTv = mediaType == 'tv' ||
            (work['first_air_date'] != null && work['release_date'] == null);

        final details = isTv
            ? await getTvDetailsBasic(id)
            : await getMovieDetails(id);

        final productionCompanies =
            details['production_companies'] as List? ?? [];
        // Only keep works where this company is in the first 2 positions
        // (primary producer or close co-producer, not a distant distributor/financier)
        final companyIndex = productionCompanies.indexWhere((c) => c['id'] == companyId);
        final isTopProducer = companyIndex >= 0 && companyIndex <= 1;
        
        // TEMP DEBUG: Log production companies for each work
        final title = work['title'] ?? work['name'] ?? 'Unknown';
        final companyNames = productionCompanies.map((c) => '${c['name']}(${c['id']})').toList();
        debugPrint('[FilterProd] "$title" (id=$id) — production_companies: $companyNames — companyId=$companyId — position=$companyIndex — isTopProducer=$isTopProducer');
        
        return isTopProducer ? work : null;
      } catch (_) {
        return work; // keep on error
      }
    });

    final results = await Future.wait(futures);
    return results.where((r) => r != null).toList();
  }

  Future<Map<String, dynamic>> getMovieDetails(int id) async {
    final endpoint = '/movie/$id';
    final params = {'append_to_response': 'release_dates,external_ids'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getMovieCredits(int id) async {
    final endpoint = '/movie/$id/credits';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  Future<Map<String, dynamic>> getCollectionDetails(int id) async {
    final endpoint = '/collection/$id';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  // --- TV Show Details & Credits ---
  Future<Map<String, dynamic>> getTvDetails(int id) async {
    final endpoint = '/tv/$id';
    final params = {'append_to_response': 'external_ids,next_episode_to_air,last_episode_to_air'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  // Lightweight method that gets only basic show info for release checking
  Future<Map<String, dynamic>> getTvDetailsBasic(int id) async {
    final endpoint = '/tv/$id';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  // Method to get show details with next/last episode info (no seasons metadata)
  Future<Map<String, dynamic>> getTvDetailsWithEpisodes(int id) async {
    final endpoint = '/tv/$id';
    final params = {'append_to_response': 'next_episode_to_air,last_episode_to_air'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  // Optimized method that gets show details with smart filtering
  Future<Map<String, dynamic>> getTvDetailsOptimized(int id) async {
    final endpoint = '/tv/$id';
    final params = {'append_to_response': 'next_episode_to_air,last_episode_to_air'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  // Batch method to check if shows are worth processing
  Future<List<TvShowCandidate>> filterTvShowCandidates(List<int> showIds) async {
    final candidates = <TvShowCandidate>[];
    
    for (final showId in showIds) {
      try {
        final details = await getTvDetailsOptimized(showId);
        final candidate = TvShowCandidate.fromTmdbData(showId, details);
        
        if (candidate.isWorthProcessing) {
          candidates.add(candidate);
        }
      } catch (e) {
        // Skip shows that can't be fetched
        continue;
      }
    }
    
    return candidates;
  }

  // Efficient method to check for new episodes using next/last episode data
  Future<List<Map<String, dynamic>>> getTvNewEpisodesEfficient(int showId, String startDate, String endDate) async {
    final details = await getTvDetailsWithEpisodes(showId);
    final episodes = <Map<String, dynamic>>[];
    final episodeDates = <String>{};
    
    // Check next episode to air
    final nextEpisode = details['next_episode_to_air'];
    if (nextEpisode != null) {
      final airDate = nextEpisode['air_date'] as String?;
      if (airDate != null && 
          airDate.compareTo(startDate) >= 0 && 
          airDate.compareTo(endDate) <= 0) {
        episodes.add(nextEpisode);
        episodeDates.add(airDate);
      }
    }
    
    // Check last episode to air (for recently aired episodes)
    final lastEpisode = details['last_episode_to_air'];
    if (lastEpisode != null) {
      final airDate = lastEpisode['air_date'] as String?;
      if (airDate != null && 
          airDate.compareTo(startDate) >= 0 && 
          airDate.compareTo(endDate) <= 0) {
        // Only add if not already added (avoid duplicates)
        if (!episodes.any((e) => e['id'] == lastEpisode['id'])) {
          episodes.add(lastEpisode);
          episodeDates.add(airDate);
        }
      }
    }
    
    // If we found episodes, fetch the full season to get all episodes on those dates
    if (episodes.isNotEmpty && episodeDates.isNotEmpty) {
      final allEpisodesOnDates = <Map<String, dynamic>>[];
      final seenEpisodeIds = <int>{};
      
      for (final episode in episodes) {
        final seasonNumber = episode['season_number'] as int?;
        final airDate = episode['air_date'] as String?;
        
        if (seasonNumber != null && airDate != null) {
          try {
            // Fetch full season to get all episodes on this date
            final seasonDetails = await getTvSeasonDetails(showId, seasonNumber);
            final seasonEpisodes = seasonDetails['episodes'] as List? ?? [];
            
            // Get all episodes that air on the same date (deduplicate by episode ID)
            for (final ep in seasonEpisodes) {
              final epAirDate = ep['air_date'] as String?;
              final epId = ep['id'] as int?;
              if (epAirDate == airDate && epId != null && !seenEpisodeIds.contains(epId)) {
                allEpisodesOnDates.add(ep);
                seenEpisodeIds.add(epId);
              }
            }
          } catch (e) {
            // Fallback to the original episodes
            final epId = episode['id'] as int?;
            if (epId != null && !seenEpisodeIds.contains(epId)) {
              allEpisodesOnDates.add(episode);
              seenEpisodeIds.add(epId);
            }
          }
        }
      }
      
      return allEpisodesOnDates.isNotEmpty ? allEpisodesOnDates : episodes;
    }
    
    return episodes;
  }

  Future<Map<String, dynamic>> getTvSeasonDetails(int showId, int seasonNumber) async {
    final endpoint = '/tv/$showId/season/$seasonNumber';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  Future<Map<String, dynamic>> getTvEpisodeDetails(int showId, int seasonNumber, int episodeNumber) async {
    final endpoint = '/tv/$showId/season/$seasonNumber/episode/$episodeNumber';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  Future<Map<String, dynamic>> getTvCredits(int id) async {
    final endpoint = '/tv/$id/credits';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  Future<Map<String, dynamic>> getTvEpisodeCredits(int showId, int seasonNumber, int episodeNumber) async {
    final endpoint = '/tv/$showId/season/$seasonNumber/episode/$episodeNumber/credits';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  // --- Watch Providers ---
  
  /// Get watch providers for a movie
  /// Returns provider data organized by region
  Future<Map<String, dynamic>> getMovieWatchProviders(int id) async {
    final endpoint = '/movie/$id/watch/providers';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  /// Get watch providers for a TV show
  /// Returns provider data organized by region
  Future<Map<String, dynamic>> getTvWatchProviders(int id) async {
    final endpoint = '/tv/$id/watch/providers';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  /// Get available watch provider regions
  /// Returns list of supported regions/countries
  Future<Map<String, dynamic>> getWatchProviderRegions() async {
    final endpoint = '/watch/providers/regions';
    _logApiCall(endpoint);
    final response = await _dio.get(endpoint);
    return response.data;
  }

  // --- TV Airing Information ---
  Future<Map<String, dynamic>> getTvOnTheAir() async {
    final endpoint = '/tv/on_the_air';
    final params = {'region': 'US'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getTvAiringToday() async {
    final endpoint = '/tv/airing_today';
    final params = {'region': 'US'};
    _logApiCall(endpoint, params);
    final response = await _dio.get(endpoint, queryParameters: params);
    return response.data;
  }
}

class _RateLimitInterceptor extends Interceptor {
  final Dio dio;
  final Function(RateLimitEvent) onRateLimit;

  _RateLimitInterceptor(this.dio, this.onRateLimit);

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    // Check for 429 Too Many Requests
    if (err.response?.statusCode == 429) {
      final retries = err.requestOptions.extra['retry_count'] as int? ?? 0;
      const maxRetries = 3;

      if (retries < maxRetries) {
        // Calculate wait time from header or default to 10s
        int waitTime = 10;
        final retryAfter = err.response?.headers.value('retry-after');
        if (retryAfter != null) {
          waitTime = int.tryParse(retryAfter) ?? 10;
        }

        // Emit event to UI
        onRateLimit(RateLimitEvent(
          waitTimeSeconds: waitTime,
          retryCount: retries + 1,
          maxRetries: maxRetries,
        ));

        // Wait
        await Future.delayed(Duration(seconds: waitTime));

        // Increment retry count
        err.requestOptions.extra['retry_count'] = retries + 1;

        try {
          // Retry the request
          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // If retry fails, continue to next error handler
          return handler.next(err);
        }
      } else {
      }
    }

    return handler.next(err);
  }
}

class TvShowCandidate {
  final int showId;
  final String name;
  final String status;
  final bool inProduction;
  final Map<String, dynamic>? nextEpisode;
  final Map<String, dynamic>? lastEpisode;
  final String? lastAirDate;
  final List seasons;
  
  TvShowCandidate({
    required this.showId,
    required this.name,
    required this.status,
    required this.inProduction,
    this.nextEpisode,
    this.lastEpisode,
    this.lastAirDate,
    required this.seasons,
  });
  
  factory TvShowCandidate.fromTmdbData(int showId, Map<String, dynamic> data) {
    return TvShowCandidate(
      showId: showId,
      name: data['name'] as String? ?? 'Unknown',
      status: data['status'] as String? ?? '',
      inProduction: data['in_production'] as bool? ?? false,
      nextEpisode: data['next_episode_to_air'] as Map<String, dynamic>?,
      lastEpisode: data['last_episode_to_air'] as Map<String, dynamic>?,
      lastAirDate: data['last_air_date'] as String?,
      seasons: data['seasons'] as List? ?? [],
    );
  }
  
  /// Quick filter: is this show worth processing?
  bool get isWorthProcessing {
    // Always process if in production or has upcoming episodes
    if (inProduction || nextEpisode != null) return true;
    
    // Process if recently ended (within last 30 days)
    if (status.toLowerCase() == 'ended' && lastAirDate != null) {
      final lastAir = DateTime.tryParse(lastAirDate!);
      if (lastAir != null) {
        final daysSinceEnd = DateTime.now().difference(lastAir).inDays;
        return daysSinceEnd <= 30;
      }
    }
    
    // Process if has recent episode activity
    if (lastEpisode != null) {
      final lastEpAirDate = lastEpisode!['air_date'] as String?;
      if (lastEpAirDate != null) {
        final lastEpAir = DateTime.tryParse(lastEpAirDate);
        if (lastEpAir != null) {
          final daysSinceLastEp = DateTime.now().difference(lastEpAir).inDays;
          return daysSinceLastEp <= 14; // Recent episode within 2 weeks
        }
      }
    }
    
    return false;
  }
}