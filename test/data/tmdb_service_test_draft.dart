import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late TmdbService service;
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() async {
    // Mock dotenv
    dotenv.testLoad(fileInput: 'TMDB_API_KEY=testkey');

    dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
    dioAdapter = DioAdapter(dio: dio);
    service = TmdbService(dio: dio);
  });

  test('searchPerson returns results on 200 OK', () async {
    dioAdapter.onGet(
      '/search/person',
      (server) => server.reply(200, {'results': []}),
      queryParameters: {'query': 'Nolan', 'api_key': 'testkey'},
    );

    final result = await service.searchPerson('Nolan');
    expect(result['results'], isA<List>());
  });

  test('Retries on 429 and succeeds', () async {
    // TODO: Implement retry logic test
    // DioAdapter doesn't support sequential responses easily
    // Consider using Mockito for complex retry scenarios
  });
}
