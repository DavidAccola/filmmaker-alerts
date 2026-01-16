import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'snackbar_utils.dart';

/// Utility class for handling external navigation to TMDB and IMDB
class ExternalNavigationUtils {
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
