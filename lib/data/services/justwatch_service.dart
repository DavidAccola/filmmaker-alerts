import 'package:dio/dio.dart';
import '../models/contributor_detail.dart';

class JustWatchService {
  final Dio _dio;
  static const String _baseUrl = 'https://api.justwatch.com';

  JustWatchService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  Dio get client => _dio;

  /// Get streaming options for a movie
  /// 
  /// Returns a list of StreamingOption objects for the given movie ID and country code
  Future<List<StreamingOption>> getMovieStreamingOptions({
    required int tmdbId,
    required String countryCode,
  }) async {
    try {
      final response = await _dio.get(
        '/offers/v2/query',
        queryParameters: {
          'content_type': 'movie',
          'external_id': 'tmdb:$tmdbId',
          'country': countryCode.toUpperCase(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _parseStreamingOptions(data, countryCode);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get streaming options for a TV show
  /// 
  /// Returns a list of StreamingOption objects for the given TV show ID and country code
  Future<List<StreamingOption>> getTvStreamingOptions({
    required int tmdbId,
    required String countryCode,
  }) async {
    try {
      final response = await _dio.get(
        '/offers/v2/query',
        queryParameters: {
          'content_type': 'show',
          'external_id': 'tmdb:$tmdbId',
          'country': countryCode.toUpperCase(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return _parseStreamingOptions(data, countryCode);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Parse streaming options from JustWatch API response
  List<StreamingOption> _parseStreamingOptions(
    Map<String, dynamic> data,
    String countryCode,
  ) {
    final options = <StreamingOption>[];

    try {
      // Get the offers for the specific country
      final offers = data['offers'] as List?;
      if (offers == null || offers.isEmpty) {
        return options;
      }

      // Get provider information
      final providers = data['providers'] as Map<String, dynamic>? ?? {};

      for (final offer in offers) {
        final offerId = offer['provider_id'] as int?;
        final type = offer['monetization_type'] as String?;
        final url = offer['url'] as String?;

        if (offerId == null || type == null || url == null) continue;

        // Get provider details
        final providerInfo = providers[offerId.toString()] as Map<String, dynamic>?;
        final providerName = providerInfo?['clear_name'] as String? ?? 'Unknown';
        final logoPath = providerInfo?['icon_url'] as String?;

        // Map monetization type to StreamingType
        final streamingType = _mapMonetizationType(type);

        options.add(StreamingOption(
          providerId: offerId.toString(),
          providerName: providerName,
          logoPath: logoPath,
          type: streamingType,
          price: null, // JustWatch API doesn't provide pricing in this endpoint
          deepLink: url,
        ));
      }
    } catch (e) {
    }

    return options;
  }

  /// Map JustWatch monetization type to StreamingType
  StreamingType _mapMonetizationType(String type) {
    switch (type.toLowerCase()) {
      case 'subscription':
        return StreamingType.subscription;
      case 'rent':
        return StreamingType.rent;
      case 'buy':
        return StreamingType.buy;
      case 'free':
        return StreamingType.free;
      default:
        return StreamingType.subscription;
    }
  }

  /// Get list of supported countries
  /// 
  /// Returns a map of country codes to country names
  Future<Map<String, String>> getSupportedCountries() async {
    try {
      final response = await _dio.get('/reference/countries');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final countries = <String, String>{};

        final countryList = data['countries'] as List?;
        if (countryList != null) {
          for (final country in countryList) {
            final code = country['iso_3166_1_alpha_2'] as String?;
            final name = country['name'] as String?;
            if (code != null && name != null) {
              countries[code] = name;
            }
          }
        }

        return countries;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
