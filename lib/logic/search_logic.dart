import '../data/models/contributor.dart';
import '../data/services/tmdb_service.dart';
import 'package:flutter/foundation.dart';
import '../core/tmdb_mapping.dart';

class SearchPageResult {
  final List<Contributor> results;
  final int totalPages;
  final int currentPage;
  final int totalResults;

  SearchPageResult({
    required this.results,
    required this.totalPages,
    required this.currentPage,
    required this.totalResults,
  });
}

class SearchLogic {
  final TmdbService _tmdbService;
  
  // Cache for trending data to make dynamic hints efficient
  Map<String, dynamic>? _cachedTrendingMovies;
  Map<String, dynamic>? _cachedTrendingPeople;
  Map<String, dynamic>? _cachedUpcomingMovies;
  List<Map<String, dynamic>>? _cachedFeaturedPeople;
  DateTime? _cacheTime;

  SearchLogic(this._tmdbService);

  bool _isCacheValid() {
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < const Duration(minutes: 60);
  }

  Future<SearchPageResult> getContributorSuggestions(
    String query,
    ContributorType type, {
    bool includeCollections = true,
  }) async {
    if (query.length < 2) return SearchPageResult(results: [], totalPages: 0, currentPage: 0, totalResults: 0);

    List<dynamic> rawResults = [];
    int totalPages = 1;
    int totalResults = 0;

    try {
      switch (type) {
        case ContributorType.person:
          final data = await _tmdbService.searchPerson(query);
          rawResults = data['results'] ?? [];
          totalPages = data['total_pages'] ?? 1;
          totalResults = data['total_results'] ?? 0;
          break;

        case ContributorType.company:
          final data = await _tmdbService.searchCompany(query);
          rawResults = data['results'] ?? [];
          totalPages = data['total_pages'] ?? 1;
          totalResults = data['total_results'] ?? 0;
          // Deep Sort: Enrich top 15 companies with their top works to sort by popularity
          // We take more than 5 initially because the default TMDB sort might place
          // popular/relevant companies lower down (e.g. Walt Disney Animation Studios vs DisneyToon).
          rawResults = await _enrichCompaniesWithTopWorks(rawResults.take(15).toList());
          break;

        case ContributorType.movie:
          final movieData = await _tmdbService.searchMovie(query);
          rawResults = List.from(movieData['results'] ?? []);
          totalPages = movieData['total_pages'] ?? 1;
          totalResults = movieData['total_results'] ?? 0;

          if (includeCollections) {
            final collectionData = await _tmdbService.searchCollection(query);
            var collections = collectionData['results'] as List? ?? [];
            
            // Deep Sort: Enrich collections with their parts' max popularity
            collections = await _enrichCollectionsWithMaxPopularity(collections.take(10).toList());

            // Mark them as collections for later processing
            for (var c in collections) {
              c['media_type'] = 'collection';
            }
            rawResults.addAll(collections);
          }
          break;

        case ContributorType.collection:
          final data = await _tmdbService.searchCollection(query);
          var collections = data['results'] as List? ?? [];
          totalPages = data['total_pages'] ?? 1;
          totalResults = data['total_results'] ?? 0;

          // Deep Sort for collections
          rawResults = await _enrichCollectionsWithMaxPopularity(collections.take(15).toList());
          break;

        case ContributorType.tvShow:
          final data = await _tmdbService.searchTv(query);
          rawResults = data['results'] ?? [];
          totalPages = data['total_pages'] ?? 1;
          totalResults = data['total_results'] ?? 0;
          break;
      }
    } catch (e) {
      debugPrint('Search error: $e');
      return SearchPageResult(results: [], totalPages: 0, currentPage: 0, totalResults: 0);
    }

    // Sort Results
    rawResults.sort((a, b) => _sortAlgorithm(a, b, query, type));

    // Map to Contributor objects (Transient, not saved to Hive yet)
    final results = rawResults.take(20).map((json) => _mapToContributor(json, type)).toList();

    return SearchPageResult(
      results: results,
      totalPages: totalPages,
      currentPage: 1,
      totalResults: totalResults,
    );
  }

  Future<String> getDynamicHint(
    ContributorType type, {
    List<String> preferredRoles = const [],
    bool collectionsEnabled = true,
  }) async {
    try {
      // Warm up cache if needed
      if (!_isCacheValid()) {
        _cachedTrendingMovies = await _tmdbService.getTrendingMovies();
        _cachedTrendingPeople = await _tmdbService.getTrendingPeople();
        _cachedUpcomingMovies = await _tmdbService.getUpcomingMovies();
        
        // PIVOT: Fetch people from upcoming movies for Person hints
        final upcomingResults = (_cachedUpcomingMovies?['results'] as List? ?? []).take(5);
        final List<Map<String, dynamic>> featured = [];
        for (var movie in upcomingResults) {
          try {
            final credits = await _tmdbService.getMovieCredits(movie['id']);
            final crew = credits['crew'] as List? ?? [];
            for (var c in crew) {
              final job = c['job'];
              final role = TmdbMapping.mapTmdbDeptToRole(c['department'] ?? '', job: job);
              if (role == 'Director' || role == 'Writer' || role == 'Production') {
                featured.add({
                  'name': c['name'],
                  'job': job,
                  'id': c['id']
                });
              }
            }
          } catch (_) {}
        }
        _cachedFeaturedPeople = featured;
        _cacheTime = DateTime.now();
      }

      final random = DateTime.now().millisecond;

      switch (type) {
        case ContributorType.movie:
          // 20% chance to show a collection example if enabled
          if (collectionsEnabled && (random % 5 == 0)) {
            final examples = ["The Avengers Collection", "Spider-Man (MCU) Collection"];
            return "e.g., ${examples[random % examples.length]}";
          }
          
          // Use Upcoming Movies for hints
          final currentYear = DateTime.now().year.toString();
          final results = (_cachedUpcomingMovies?['results'] as List? ?? [])
              .where((m) {
                final releaseDate = m['release_date'] as String? ?? '';
                final isEn = m['original_language'] == 'en';
                final isCurrentYear = releaseDate.startsWith(currentYear);
                return isEn && isCurrentYear;
              })
              .toList();

          if (results.isNotEmpty) {
             // Pick from top 5 for variety
             final index = random % (results.length > 5 ? 5 : results.length);
             return "e.g., ${results[index]['title']}";
          }
          return "e.g., The Sandlot";

        case ContributorType.person:
          // 1. Try Featured People (from upcoming movies) matching preferred roles
          if (_cachedFeaturedPeople != null && _cachedFeaturedPeople!.isNotEmpty) {
            // Shuffle for variety if we have many
            final shuffled = List<Map<String, dynamic>>.from(_cachedFeaturedPeople!)..shuffle();
            for (var p in shuffled) {
              final mappedRole = TmdbMapping.mapTmdbDeptToRole('', job: p['job']);
              if (preferredRoles.isEmpty || preferredRoles.contains(mappedRole)) {
                return "e.g., ${p['name']}";
              }
            }
            // If no role match, just pick one of the featured people
            return "e.g., ${_cachedFeaturedPeople!.first['name']}";
          }

          // 2. Fallback to Trending People
          final trendingResults = (_cachedTrendingPeople?['results'] as List? ?? [])
              .where((p) {
                final knownFor = p['known_for'] as List? ?? [];
                return knownFor.any((work) => work['original_language'] == 'en' || work['original_country']?.contains('US') == true);
              })
              .toList();

          if (trendingResults.isNotEmpty) {
            return "e.g., ${trendingResults.first['name']}";
          }

          final fallbacks = ["Steven Spielberg", "Christopher Nolan", "Greta Gerwig"];
          return "e.g., ${fallbacks[random % fallbacks.length]}";

        case ContributorType.company:
          // DYNAMIC COMPANY: Pick a top trending movie and find its production company
          final results = (_cachedTrendingMovies?['results'] as List? ?? [])
              .where((m) => m['original_language'] == 'en')
              .toList();

          if (results.isNotEmpty) {
            final index = random % (results.length > 3 ? 3 : results.length);
            final topMovieId = results[index]['id'];
            
            // Get production company for this trending movie
            final details = await _tmdbService.getMovieDetails(topMovieId);
            final productionCompanies = details['production_companies'] as List? ?? [];
            
            if (productionCompanies.isNotEmpty) {
              return "e.g., ${productionCompanies.first['name']}";
            }
          }
          
          final examples = ["Pixar", "Disney"];
          return "e.g., ${examples[random % examples.length]}";

        case ContributorType.tvShow:
          final examples = ["Breaking Bad", "The Office", "Stranger Things"];
          return "e.g., ${examples[random % examples.length]}";
          
        default:
          return "e.g., Greta Gerwig";
      }
    } catch (e) {
      debugPrint('Error getting dynamic hint: $e');
      return "e.g., Search...";
    }
  }

  /// Performs a paginated search for a specific type.
  Future<SearchPageResult> searchGlobal(
    String query,
    ContributorType type, {
    int page = 1,
    bool includeCollections = false,
  }) async {
    dynamic data;
    
    try {
      switch (type) {
        case ContributorType.person:
          data = await _tmdbService.searchPerson(query, page: page);
          break;
        case ContributorType.company:
          data = await _tmdbService.searchCompany(query, page: page);
          break;
        case ContributorType.movie:
          final movieData = await _tmdbService.searchMovie(query, page: page);
          
          if (includeCollections && page == 1) {
            final collectionData = await _tmdbService.searchCollection(query, page: 1);
            final List movieResults = movieData['results'] as List? ?? [];
            List collectionResults = collectionData['results'] as List? ?? [];
            
            // Enrich collections for proper sorting
            collectionResults = await _enrichCollectionsWithMaxPopularity(collectionResults.take(10).toList());

            // Mark collections for mapping
            for (var c in collectionResults) {
              c['media_type'] = 'collection';
            }
            
            movieResults.addAll(collectionResults);
            
            // Adjust totals for UI
            final totalResults = (movieData['total_results'] ?? 0) + (collectionData['total_results'] ?? 0);
            
            data = {
              ...movieData,
              'results': movieResults,
              'total_results': totalResults,
            };
          } else {
            data = movieData;
          }
          break;
        case ContributorType.collection:
          data = await _tmdbService.searchCollection(query, page: page);
          break;
        case ContributorType.tvShow:
          data = await _tmdbService.searchTv(query, page: page);
          break;
      }

      final results = (data['results'] as List? ?? [])
          .map((json) => _mapToContributor(json, type))
          .toList();

      return SearchPageResult(
        results: results,
        totalPages: data['total_pages'] ?? 1,
        currentPage: data['page'] ?? 1,
        totalResults: data['total_results'] ?? results.length,
      );
    } catch (e) {
      debugPrint('Global search error: $e');
      return SearchPageResult(results: [], totalPages: 0, currentPage: 0, totalResults: 0);
    }
  }

  Contributor _mapToContributor(dynamic json, ContributorType type) {
    final isCollection = json['media_type'] == 'collection' || type == ContributorType.collection;
    
    // Determine Known For text
    String knownFor = '';
    if (type == ContributorType.person) {
      final dept = json['known_for_department'] ?? '';
      final mappedDept = TmdbMapping.mapTmdbDeptToRole(dept);

      final knownForList = json['known_for'] as List?;
      String works = '';
      if (knownForList != null) {
        works = knownForList.map((k) => k['title'] ?? k['name'] ?? '').where((s) => s.isNotEmpty).join(', ');
      }
      
      if (mappedDept.isNotEmpty && works.isNotEmpty) {
        knownFor = '$mappedDept • $works';
      } else {
        knownFor = mappedDept.isNotEmpty ? mappedDept : works;
      }
    } else if (type == ContributorType.company) {
      knownFor = json['origin_country'] ?? '';
      // If we enriched it, we might have stored top works titles (custom logic)
      if (json['top_work_titles'] != null) {
        knownFor = json['top_work_titles'];
      }
    } else if (isCollection) {
      knownFor = 'Collection';
    } else if (type == ContributorType.tvShow) {
      knownFor = (json['first_air_date'] as String?)?.split('-').first ?? 'Upcoming';
    } else {
      knownFor = (json['release_date'] as String?)?.split('-').first ?? 'Upcoming';
    }

    return Contributor(
      tmdbId: json['id'],
      name: json['name'] ?? json['title'] ?? 'Unknown',
      type: isCollection ? ContributorType.collection : type,
      profilePath: json['profile_path'] ?? json['logo_path'] ?? json['poster_path'],
      notifyForDepartments: [], // Set later
      availableDepartments: [], // Set later
      knownFor: knownFor,
    );
  }

  int _sortAlgorithm(dynamic a, dynamic b, String query, ContributorType type) {
    final nameA = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
    final nameB = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();
    final q = query.toLowerCase();

    final exactA = nameA == q;
    final exactB = nameB == q;

    // Exact Match Gate: Only prioritize exact match if popularity > 0 OR it's a company/collection
    final popA = (a['popularity'] as num?) ?? 0;
    final popB = (b['popularity'] as num?) ?? 0;
    
    final effectivePopA = (a['max_popularity'] as num?) ?? popA;
    final effectivePopB = (b['max_popularity'] as num?) ?? popB;

    final isMajorType = type == ContributorType.company || type == ContributorType.collection || type == ContributorType.movie;
    final validExactA = exactA && (effectivePopA > 0 || isMajorType);
    final validExactB = exactB && (effectivePopB > 0 || isMajorType);

    if (validExactA && !validExactB) return -1;
    if (!validExactA && validExactB) return 1;

    // Starts With
    if (type != ContributorType.company && type != ContributorType.collection) {
      final startsA = nameA.startsWith(q);
      final startsB = nameB.startsWith(q);

      if (startsA && !startsB) return -1;
      if (!startsA && startsB) return 1;
    }

    // Popularity Descending
    return effectivePopB.compareTo(effectivePopA);
  }

  Future<List<dynamic>> _enrichCollectionsWithMaxPopularity(List<dynamic> collections) async {
    for (var collection in collections) {
      try {
        final details = await _tmdbService.getCollectionDetails(collection['id']);
        final parts = details['parts'] as List? ?? [];
        if (parts.isNotEmpty) {
          double maxPop = 0;
          for (var part in parts) {
            final p = (part['popularity'] as num?)?.toDouble() ?? 0.0;
            if (p > maxPop) maxPop = p;
          }
          collection['max_popularity'] = maxPop;
          collection['top_work_titles'] = parts.take(2).map((w) => w['title']).join(', ');
        }
      } catch (_) {
        // Silently skip - TMDB search sometimes returns movie IDs as collections
        collection['max_popularity'] = 0;
      }
    }
    return collections;
  }

  Future<List<dynamic>> _enrichCompaniesWithTopWorks(List<dynamic> companies) async {
    for (var company in companies) {
      // Skip if no logo (proxy for "official")
      if (company['logo_path'] == null) {
        company['max_popularity'] = 0;
        continue;
      }

      final topWorksData = await _tmdbService.getCompanyTopWorks(company['id']);
      final results = topWorksData['results'] as List? ?? [];

      if (results.isNotEmpty) {
        // Calculate max popularity from top works
        double maxPop = 0;
        for (var work in results) {
          final p = (work['popularity'] as num?)?.toDouble() ?? 0.0;
          if (p > maxPop) maxPop = p;
        }
        company['max_popularity'] = maxPop;
        company['top_work_titles'] = results.take(2).map((w) => w['title']).join(', ');
      }
    }
    return companies;
  }
}