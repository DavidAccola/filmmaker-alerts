import 'package:flutter/foundation.dart';
import '../models/contributor_detail.dart';
import 'tmdb_service.dart';

/// Service for fetching streaming provider information from TMDB
/// Uses TMDB's native watch/providers endpoints for reliable, official data
class StreamingService {
  final TmdbService _tmdbService;
  
  // Cache for provider logos and metadata
  static final Map<String, String> _providerLogoCache = {};

  StreamingService(this._tmdbService);

  /// Get streaming options for a movie in a specific region
  /// 
  /// Returns a list of StreamingOption objects organized by type
  /// Falls back gracefully if data is unavailable
  Future<List<StreamingOption>> getMovieStreamingOptions({
    required int tmdbId,
    required String regionCode,
  }) async {
    try {
      final data = await _tmdbService.getMovieWatchProviders(tmdbId);
      return _parseWatchProviders(data, regionCode);
    } catch (e) {
      debugPrint('[StreamingService] Error fetching movie watch providers: $e');
      return [];
    }
  }

  /// Get streaming options for a TV show in a specific region
  /// 
  /// Returns a list of StreamingOption objects organized by type
  /// Falls back gracefully if data is unavailable
  Future<List<StreamingOption>> getTvStreamingOptions({
    required int tmdbId,
    required String regionCode,
  }) async {
    try {
      final data = await _tmdbService.getTvWatchProviders(tmdbId);
      return _parseWatchProviders(data, regionCode);
    } catch (e) {
      debugPrint('[StreamingService] Error fetching TV watch providers: $e');
      return [];
    }
  }

  /// Parse watch provider data from TMDB API response
  /// 
  /// TMDB returns data in format:
  /// {
  ///   "results": {
  ///     "US": {
  ///       "link": "https://www.themoviedb.org/movie/550/watch",
  ///       "flatrate": [{"logo_path": "/...", "provider_id": 8, "provider_name": "Netflix", ...}],
  ///       "rent": [...],
  ///       "buy": [...]
  ///     }
  ///   }
  /// }
  List<StreamingOption> _parseWatchProviders(
    Map<String, dynamic> data,
    String regionCode,
  ) {
    final options = <StreamingOption>[];
    String? watchLink;

    try {
      final results = data['results'] as Map<String, dynamic>? ?? {};
      
      // Get data for the requested region, fallback to US if not available
      final regionData = results[regionCode.toUpperCase()] as Map<String, dynamic>? ??
          results['US'] as Map<String, dynamic>?;
      
      if (regionData == null) {
        debugPrint('[StreamingService] No watch provider data for region: $regionCode');
        return options;
      }

      // Capture the watch link from the response
      watchLink = regionData['link'] as String?;

      // Parse each provider type
      _parseProviderType(regionData, 'flatrate', StreamingType.subscription, options, watchLink);
      _parseProviderType(regionData, 'free', StreamingType.free, options, watchLink);
      _parseProviderType(regionData, 'rent', StreamingType.rent, options, watchLink);
      _parseProviderType(regionData, 'buy', StreamingType.buy, options, watchLink);

    } catch (e) {
      debugPrint('[StreamingService] Error parsing watch providers: $e');
    }

    return options;
  }

  /// Parse a specific provider type (subscription, free, rent, buy)
  void _parseProviderType(
    Map<String, dynamic> regionData,
    String typeKey,
    StreamingType streamingType,
    List<StreamingOption> options,
    String? watchLink,
  ) {
    try {
      final providers = regionData[typeKey] as List? ?? [];
      
      for (final provider in providers) {
        final providerId = provider['provider_id']?.toString() ?? '';
        final providerName = provider['provider_name'] as String? ?? 'Unknown';
        final logoPath = provider['logo_path'] as String?;

        if (providerId.isEmpty) continue;

        // Build TMDB logo URL
        final fullLogoPath = logoPath != null
            ? 'https://image.tmdb.org/t/p/original$logoPath'
            : null;

        // Cache the logo path for future use
        if (fullLogoPath != null) {
          _providerLogoCache[providerId] = fullLogoPath;
        }

        options.add(StreamingOption(
          providerId: providerId,
          providerName: providerName,
          logoPath: fullLogoPath,
          type: streamingType,
          price: null, // TMDB doesn't provide pricing
          deepLink: '', // Will be set by UI if needed
          watchLink: watchLink,
        ));
      }
    } catch (e) {
      debugPrint('[StreamingService] Error parsing provider type $typeKey: $e');
    }
  }

  /// Get available watch provider regions
  /// 
  /// Returns a map of region codes to region names
  /// Useful for user region selection
  Future<Map<String, String>> getAvailableRegions() async {
    try {
      final data = await _tmdbService.getWatchProviderRegions();
      final regions = <String, String>{};

      final results = data['results'] as List? ?? [];
      for (final region in results) {
        final iso = region['iso_3166_1'] as String?;
        final name = region['english_name'] as String?;
        
        if (iso != null && name != null) {
          regions[iso] = name;
        }
      }

      return regions;
    } catch (e) {
      debugPrint('[StreamingService] Error fetching available regions: $e');
      return {};
    }
  }

  /// Get cached provider logo URL
  /// 
  /// Returns the cached logo URL if available, otherwise null
  String? getCachedProviderLogo(String providerId) {
    return _providerLogoCache[providerId];
  }

  /// Clear the provider logo cache
  /// 
  /// Useful when switching regions or refreshing data
  void clearLogoCache() {
    _providerLogoCache.clear();
  }
}
