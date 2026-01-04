import '../data/models/contributor.dart';
import '../data/services/tmdb_service.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/tmdb_mapping.dart';

class LatestWorkLogic {
  final TmdbService _tmdbService;

  LatestWorkLogic(this._tmdbService);

  Future<LatestWork?> calculateLatestWork(Contributor contributor, {String? pretendToday}) async {
    try {
      switch (contributor.type) {
        case ContributorType.collection:
          return _getLatestForCollection(contributor);
        case ContributorType.movie:
          return _getLatestForMovie(contributor);
        case ContributorType.person:
        case ContributorType.company:
          return _getLatestForPersonOrCompany(contributor, pretendToday);
      }
    } catch (e) {
      debugPrint('Error calculating latest work for ${contributor.name}: $e');
      return null;
    }
  }

  Future<LatestWork?> _getLatestForCollection(Contributor contributor) async {
    final data = await _tmdbService.getCollectionDetails(contributor.tmdbId);
    final parts = (data['parts'] as List?) ?? [];

    if (parts.isEmpty) return null;

    // Sort by release date descending
    parts.sort((a, b) {
      final dateA = a['release_date'] ?? '';
      final dateB = b['release_date'] ?? '';
      return dateB.compareTo(dateA);
    });

    final latest = parts.first;
    return LatestWork(
      title: latest['title'] ?? 'Unknown',
      releaseYear: (latest['release_date'] as String?)?.split('-').first ?? '',
      releaseDate: latest['release_date'] ?? '',
      department: 'Collection',
      job: 'Part of Collection',
      posterPath: latest['poster_path'],
    );
  }

  Future<LatestWork?> _getLatestForMovie(Contributor contributor) async {
    final data = await _tmdbService.getMovieDetails(contributor.tmdbId);
    final releaseDatesResults = data['release_dates']?['results'] as List?;

    if (releaseDatesResults == null || releaseDatesResults.isEmpty) return null;

    // Region Priority: US -> Flatten all
    var regionReleases = releaseDatesResults.firstWhere(
      (r) => r['iso_3166_1'] == 'US',
      orElse: () => null,
    );

    List<dynamic> releases = [];
    if (regionReleases != null) {
      releases = regionReleases['release_dates'];
    } else {
      // Flatten all regions
      for (var r in releaseDatesResults) {
        releases.addAll(r['release_dates']);
      }
    }

    // Sort by date ascending
    releases.sort((a, b) => (a['release_date'] ?? '').compareTo(b['release_date'] ?? ''));

    if (releases.isEmpty) return null;

    // Original: First non-limited (Type != 2)
    var original = releases.firstWhere((r) => r['type'] != 2, orElse: () => releases.first);
    var latest = releases.last;

    return LatestWork(
      title: data['title'],
      releaseYear: (original['release_date'] as String?)?.split('-').first ?? '',
      releaseDate: original['release_date']?.toString().substring(0, 10) ?? '',
      department: 'Movie',
      posterPath: data['poster_path'],
      originalReleaseDate: original['release_date']?.toString().substring(0, 10),
      originalReleaseType: _getReleaseTypeString(original['type']),
      latestReleaseDate: latest['release_date']?.toString().substring(0, 10),
      latestReleaseType: _getReleaseTypeString(latest['type']),
    );
  }

  Future<LatestWork?> _getLatestForPersonOrCompany(Contributor contributor, String? pretendToday) async {
    List<dynamic> credits = [];
    
    if (contributor.type == ContributorType.person) {
      final data = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
      final cast = (data['cast'] as List? ?? []).map((c) {
        if (c is Map) (c as Map)['_is_cast'] = true;
        return c;
      }).toList();
      final crew = (data['crew'] as List? ?? []).map((c) {
        if (c is Map) (c as Map)['_is_cast'] = false;
        return c;
      }).toList();
      credits = [...cast, ...crew];
    } else {
      // Company: Fetch movies and TV
      final movies = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'movie');
      final tv = await _tmdbService.getCompanyCredits(contributor.tmdbId, 'tv');
      credits = [...(movies['results'] ?? []), ...(tv['results'] ?? [])];
    }

    final today = pretendToday ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Filter and Sort
    // Filter and Sort
    final validCredits = credits.where((c) {
      final date = c['release_date'] ?? c['first_air_date'];
      if (date == null || date == '') return false;
      
      // Future Release Filter
      if (date.compareTo(today) > 0) return false;

      // Department Filter
      // We only care about departments the user is following.
      // If we don't filter, we might show "Self" or "Thanks" credits instead of "Director".
      if (contributor.notifyForDepartments.isNotEmpty) {
        final dept = c['department'] ?? '';
        final job = c['job'] ?? '';
        String mappedDept = TmdbMapping.mapTmdbDeptToRole(dept, job: job);
        
        if (c['_is_cast'] == true) {
          mappedDept = 'Actor';
        }

        if (!contributor.notifyForDepartments.contains(mappedDept)) {
          return false;
        }
      }

      return true;
    }).toList();

    validCredits.sort((a, b) {
      final dateA = a['release_date'] ?? a['first_air_date'];
      final dateB = b['release_date'] ?? b['first_air_date'];
      return dateB.compareTo(dateA);
    });

    if (validCredits.isEmpty) return null;

    final latest = validCredits.first;
    
    // Aggregation: Find all credits for this specific movie/show to list all roles (e.g. Director, Writer)
    final allRolesForLatest = validCredits.where((c) => c['id'] == latest['id']);
    final Set<String> distinctJobs = {};
    
    for (var role in allRolesForLatest) {
      final job = role['job'] ?? role['department'] ?? role['character'];
      if (job != null && job.isNotEmpty) {
        distinctJobs.add(job);
      }
    }

    return LatestWork(
      title: latest['title'] ?? latest['name'] ?? 'Unknown',
      releaseYear: (latest['release_date'] ?? latest['first_air_date'])?.split('-').first ?? '',
      releaseDate: latest['release_date'] ?? latest['first_air_date'],
      department: latest['department'] ?? (contributor.type == ContributorType.company ? 'Production' : 'Actor'),
      job: distinctJobs.join(', '), // Aggregated jobs
      posterPath: latest['poster_path'],
    );
  }

  String _getReleaseTypeString(int? type) {
    const types = {1: 'Premiere', 2: 'Theatrical (Limited)', 3: 'Theatrical', 4: 'Digital', 5: 'Physical', 6: 'TV'};
    return types[type] ?? 'Unknown';
  }
}