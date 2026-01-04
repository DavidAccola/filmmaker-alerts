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

  // --- Search ---
  Future<Map<String, dynamic>> searchPerson(String query, {int page = 1}) async {
    final response = await _dio.get('/search/person', queryParameters: {'query': query, 'page': page});
    return response.data;
  }

  Future<Map<String, dynamic>> searchCompany(String query, {int page = 1}) async {
    final response = await _dio.get('/search/company', queryParameters: {'query': query, 'page': page});
    return response.data;
  }

  Future<Map<String, dynamic>> searchMovie(String query, {int page = 1}) async {
    final response = await _dio.get('/search/movie', queryParameters: {'query': query, 'page': page});
    return response.data;
  }

  Future<Map<String, dynamic>> searchCollection(String query, {int page = 1}) async {
    final response = await _dio.get('/search/collection', queryParameters: {'query': query, 'page': page});
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
  Future<Map<String, dynamic>> getPersonCombinedCredits(int id) async {
    final response = await _dio.get('/person/$id/combined_credits');
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

  Future<Map<String, dynamic>> getMovieDetails(int id) async {
    final response = await _dio.get('/movie/$id', queryParameters: {
      'append_to_response': 'release_dates,external_ids',
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getMovieCredits(int id) async {
    final response = await _dio.get('/movie/$id/credits');
    return response.data;
  }

  Future<Map<String, dynamic>> getCollectionDetails(int id) async {
    final response = await _dio.get('/collection/$id');
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

        debugPrint(
            '[TMDB] Rate limit hit. Waiting $waitTime seconds. Retry ${retries + 1}/$maxRetries');
            
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
        debugPrint('[TMDB] Max retries reached for rate limiting.');
      }
    }

    return handler.next(err);
  }
}