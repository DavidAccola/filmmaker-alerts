import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TmdbService service;
  late Dio dio;

  setUp(() {
    dotenv.env['TMDB_API_KEY'] = 'testkey';
    dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
    // Interceptors are added by the service constructor
    service = TmdbService(dio: dio);
  });

  test('searchPerson returns results on 200 OK', () async {
    dio.httpClientAdapter = _MockAdapter((options) {
      return ResponseBody.fromString(
        '{"results": []}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final result = await service.searchPerson('Nolan');
    expect(result['results'], isA<List>());
  });

  test('Retries on 429 and succeeds', () async {
    int callCount = 0;

    dio.httpClientAdapter = _MockAdapter((options) {
      callCount++;
      if (callCount == 1) {
        // First attempt: 429
        return ResponseBody.fromString(
          '{}',
          429,
          headers: {
            'retry-after': ['1'], // 1 second
          },
        );
      } else {
        // Second attempt: 200 OK
        return ResponseBody.fromString(
          '{"success": true}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    });

    final result = await service.getMovieDetails(123);
    
    expect(callCount, 2); // Should have retried once
    expect(result['success'], true);
  });
  
  test('Fails after max retries', () async {
    int callCount = 0;

    dio.httpClientAdapter = _MockAdapter((options) {
      callCount++;
      return ResponseBody.fromString(
        '{}',
        429,
        headers: {'retry-after': ['0']}, // 0 for speed
      );
    });

    try {
      await service.searchMovie('Inception');
      fail('Should have thrown DioException');
    } catch (e) {
      expect(e, isA<DioException>());
    }
    
    expect(callCount, 4); 
  });

  // Property-based test for TV search validation
  test('Property 1: TV Search Result Validation - Property Test', () async {
    // **Property 1: TV Search Result Validation**
    // **Validates: Requirements 1.1, 1.2**
    
    // Test with various mock TV search responses
    for (int i = 0; i < 100; i++) {
      final mockResults = _generateMockTvResults(i);
      
      dio.httpClientAdapter = _MockAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode({'results': mockResults}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await service.searchTv('test query');
      final results = result['results'] as List;
      
      // Property: For any valid TV show search query, the returned results 
      // SHALL contain only entries with valid tmdbId (positive integer), 
      // name (non-empty string), and first air year (valid year or null)
      for (final tvShow in results) {
        // Validate tmdbId is positive integer
        expect(tvShow['id'], isA<int>(), 
          reason: 'tmdbId should be an integer');
        expect(tvShow['id'], greaterThan(0), 
          reason: 'tmdbId should be positive');
        
        // Validate name is non-empty string
        expect(tvShow['name'], isA<String>(), 
          reason: 'name should be a string');
        expect(tvShow['name'], isNotEmpty, 
          reason: 'name should not be empty');
        
        // Validate first_air_date is valid year or null
        final firstAirDate = tvShow['first_air_date'];
        if (firstAirDate != null) {
          expect(firstAirDate, isA<String>(), 
            reason: 'first_air_date should be a string when not null');
          if (firstAirDate.isNotEmpty) {
            final year = int.tryParse(firstAirDate.split('-')[0]);
            expect(year, isNotNull, 
              reason: 'first_air_date should contain a valid year');
            expect(year!, greaterThanOrEqualTo(1900), 
              reason: 'year should be reasonable (>= 1900)');
            expect(year, lessThanOrEqualTo(2050), 
              reason: 'year should be reasonable (<= 2050)');
          }
        }
      }
    }
  });
}

List<Map<String, dynamic>> _generateMockTvResults(int seed) {
  // Generate different mock TV show results based on seed
  final List<Map<String, dynamic>> results = [];
  
  final numResults = (seed % 5) + 1; // 1-5 results
  
  for (int i = 0; i < numResults; i++) {
    final id = (seed * 100) + i + 1; // Ensure positive ID
    final name = 'Test Show ${seed}_$i';
    
    // Vary first_air_date: sometimes null, sometimes valid date
    String? firstAirDate;
    if (seed % 3 != 0) { // 2/3 of the time, include a date
      final year = 2000 + (seed % 25); // Years 2000-2024
      final month = (i % 12) + 1;
      final day = (i % 28) + 1;
      firstAirDate = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
    
    results.add({
      'id': id,
      'name': name,
      'first_air_date': firstAirDate,
      'poster_path': '/test_poster_$i.jpg',
      'overview': 'Test overview for show $i',
      'vote_average': 7.5 + (i * 0.1),
    });
  }
  
  return results;
}

class _MockAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
