import 'package:flutter/foundation.dart';
import '../models/contributor_detail.dart';
import '../services/justwatch_service.dart';

class StreamingRepository {
  final JustWatchService _justWatchService;

  StreamingRepository({JustWatchService? justWatchService})
      : _justWatchService = justWatchService ?? JustWatchService();

  /// Get streaming options for a movie
  /// 
  /// Returns a list of StreamingOption objects for the given movie ID and country code
  Future<List<StreamingOption>> getMovieStreamingOptions({
    required int tmdbId,
    required String countryCode,
  }) async {
    try {
      return await _justWatchService.getMovieStreamingOptions(
        tmdbId: tmdbId,
        countryCode: countryCode,
      );
    } catch (e) {
      debugPrint('[StreamingRepository] Error getting movie streaming options: $e');
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
      return await _justWatchService.getTvStreamingOptions(
        tmdbId: tmdbId,
        countryCode: countryCode,
      );
    } catch (e) {
      debugPrint('[StreamingRepository] Error getting TV streaming options: $e');
      return [];
    }
  }

  /// Get streaming options for a work (movie or TV show)
  /// 
  /// Automatically determines the content type based on the work type
  Future<List<StreamingOption>> getWorkStreamingOptions({
    required Work work,
    required String countryCode,
  }) async {
    try {
      if (work.type == WorkType.movie) {
        return await getMovieStreamingOptions(
          tmdbId: work.tmdbId,
          countryCode: countryCode,
        );
      } else if (work.type == WorkType.tvShow) {
        return await getTvStreamingOptions(
          tmdbId: work.tmdbId,
          countryCode: countryCode,
        );
      }
      return [];
    } catch (e) {
      debugPrint('[StreamingRepository] Error getting work streaming options: $e');
      return [];
    }
  }

  /// Get supported countries from JustWatch
  /// 
  /// Returns a map of country codes to country names
  Future<Map<String, String>> getSupportedCountries() async {
    try {
      return await _justWatchService.getSupportedCountries();
    } catch (e) {
      debugPrint('[StreamingRepository] Error getting supported countries: $e');
      return {};
    }
  }
}
