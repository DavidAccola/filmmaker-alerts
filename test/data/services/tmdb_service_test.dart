import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late TmdbService tmdbService;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=test_key');
    dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {'api_key': 'test_key'},
    ));
    dioAdapter = DioAdapter(dio: dio);
    tmdbService = TmdbService(dio: dio);
  });

  group('TmdbService Rate Limiting', () {
    test('should retry on 429 and succeed on next attempt', () async {
      int callCount = 0;
      
      dioAdapter.onGet(
        RegExp(r'.*'),
        (server) {
          callCount++;
          if (callCount == 1) {
            server.reply(429, {'status_message': 'Rate limit exceeded'}, headers: {'retry-after': ['1']});
          } else {
            server.reply(200, {'title': 'Success'});
          }
        },
      );

      final events = <RateLimitEvent>[];
      tmdbService.onRateLimit.listen(events.add);

      final response = await tmdbService.getMovieDetails(123);

      expect(response['title'], 'Success');
      expect(events.length, 1);
      expect(events.first.retryCount, 1);
      expect(callCount, 2);
    });
  });
}