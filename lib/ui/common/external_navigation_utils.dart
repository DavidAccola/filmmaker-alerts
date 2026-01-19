import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'snackbar_utils.dart';

/// Utility class for handling external navigation to TMDB and IMDB
class ExternalNavigationUtils {
  /// Launch JustWatch homepage
  static Future<void> launchJustWatch(BuildContext context) async {
    const url = 'https://www.justwatch.com';
    await _launchUrl(context, url, 'JustWatch');
  }

  /// Launch TMDB URL for a movie or TV show watch page
  /// Uses the link from the streaming provider data if available
  /// Appends locale parameter if provided
  static Future<void> launchTmdbWatchPage(
    BuildContext context, {
    required int tmdbId,
    required bool isTV,
    String? watchLink,
    String? locale,
  }) async {
    // Use the link from TMDB API response if available, otherwise construct it
    var url = watchLink ?? _constructWatchUrl(tmdbId, isTV);
    
    // Append locale parameter if provided
    if (locale != null && locale.isNotEmpty) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}locale=$locale';
    }
    
    await _launchUrl(context, url, 'TMDB');
  }

  /// Construct the watch URL if not provided by API
  static String _constructWatchUrl(int tmdbId, bool isTV) {
    final typePath = isTV ? 'tv' : 'movie';
    return 'https://www.themoviedb.org/$typePath/$tmdbId/watch';
  }

  /// Launch TMDB URL for a movie or TV show
  static Future<void> launchTmdbTitle(
    BuildContext context, {
    required int tmdbId,
    required bool isTV,
  }) async {
    final typePath = isTV ? 'tv' : 'movie';
    final url = 'https://www.themoviedb.org/$typePath/$tmdbId';
    await _launchUrl(context, url, 'TMDB');
  }

  /// Launch TMDB URL for a specific TV episode
  static Future<void> launchTmdbEpisode(
    BuildContext context, {
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final url = 'https://www.themoviedb.org/tv/$showId/season/$seasonNumber/episode/$episodeNumber';
    await _launchUrl(context, url, 'TMDB');
  }

  /// Launch TMDB URL for a specific TV season
  static Future<void> launchTmdbSeason(
    BuildContext context, {
    required int showId,
    required int seasonNumber,
  }) async {
    final url = 'https://www.themoviedb.org/tv/$showId/season/$seasonNumber';
    await _launchUrl(context, url, 'TMDB');
  }

  /// Launch TMDB URL for a person
  static Future<void> launchTmdbPerson(
    BuildContext context, {
    required int tmdbId,
  }) async {
    final url = 'https://www.themoviedb.org/person/$tmdbId';
    await _launchUrl(context, url, 'TMDB');
  }

  /// Launch IMDB URL for a title (movie or TV show)
  static Future<void> launchImdbTitle(
    BuildContext context, {
    required String imdbId,
  }) async {
    if (imdbId.isEmpty) {
      if (context.mounted) {
        showSimpleSnackBar(context, 'IMDb ID not available for this title');
      }
      return;
    }

    final url = 'https://www.imdb.com/title/$imdbId/';
    await _launchUrl(context, url, 'IMDb');
  }

  /// Launch IMDB URL for a person
  static Future<void> launchImdbPerson(
    BuildContext context, {
    required String imdbId,
  }) async {
    if (imdbId.isEmpty) {
      if (context.mounted) {
        showSimpleSnackBar(context, 'IMDb ID not available for this person');
      }
      return;
    }

    final url = 'https://www.imdb.com/name/$imdbId/';
    await _launchUrl(context, url, 'IMDb');
  }

  /// Helper method to launch URL with error handling
  static Future<void> _launchUrl(
    BuildContext context,
    String urlString,
    String provider,
  ) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showSimpleSnackBar(context, 'Could not open $provider page');
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSimpleSnackBar(context, 'Error opening $provider: $e');
      }
    }
  }
}
