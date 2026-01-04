import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TmdbService service;
  late Dio dio;

  setUp(() {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=testkey');
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
