import 'package:flutter/foundation.dart';
import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/watchlist_entry.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/contributor_detail_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/tmdb_service.dart';
import 'latest_work_logic.dart';
import 'work_sorting_logic.dart';
import 'watchlist_logic.dart';
import '../core/tmdb_mapping.dart';
import 'tv_show_display_logic.dart';

class ContributorLogic {
  final ContributorRepository _contributorRepository;
  final TmdbService _tmdbService;
  final LatestWorkLogic _latestWorkLogic;
  final PreferencesRepository _preferencesRepository;
  final ContributorDetailRepository? _contributorDetailRepository;

  ContributorLogic(
    this._contributorRepository,
    this._tmdbService,
    this._latestWorkLogic,
    this._preferencesRepository, {
    ContributorDetailRepository? contributorDetailRepository,
  }) : _contributorDetailRepository = contributorDetailRepository;

  /// Clears all cached contributor details.
  Future<void> clearAllContributorDetails() async {
    if (_contributorDetailRepository != null) {
      await _contributorDetailRepository!.clearAllCache();
      debugPrint('[ContributorLogic] All contributor details cleared from cache.');
    }
  }

  /// Fetches available departments for any contributor type.
  Future<List<String>> getAvailableDepartments(Contributor contributor) async {
    if (contributor.type == ContributorType.person) {
      final creditData = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
      final cast = creditData['cast'] as List? ?? [];
      final crew = creditData['crew'] as List? ?? [];

      final Set<String> depts = {};
      
      // Actors are in the 'cast' array
      if (cast.isNotEmpty) {
        depts.add('Actor');
      }

      for (var c in crew) {
        String dept = c['department'] ?? '';
        String job = c['job'] ?? '';
        String role = TmdbMapping.mapTmdbDeptToRole(dept, job: job);
        
        if (role.isNotEmpty) {
          depts.add(role);
        }
      }

      return depts.toList()..sort();
    } else if (contributor.type == ContributorType.company) {
      return ['Production'];
    } else if (contributor.type == ContributorType.movie) {
      return ['Movie'];
    } else if (contributor.type == ContributorType.collection) {
      return ['Collection'];
    } else if (contributor.type == ContributorType.tvShow) {
      return ['TV Show'];
    }
    return [];
  }

  /// Forces a refresh of the detailed credit information for a single contributor
  Future<void> refreshContributorDetail(Contributor contributor) async {
    debugPrint('[ContributorLogic] Forcing refresh of details for ${contributor.name}');
    List<dynamic> credits = [];
    if (contributor.type == ContributorType.person) {
      final data = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
      credits = [...(data['cast'] ?? []), ...(data['crew'] ?? [])];
    } else if (contributor.type == ContributorType.company) {
      final data = await _tmdbService.getCompanyTopWorks(contributor.tmdbId);
      final topWorks = data['results'] as List? ?? [];
      
      // Also fetch upcoming works
      final upcomingData = await _tmdbService.getCompanyUpcomingWorks(contributor.tmdbId);
      final upcomingWorks = upcomingData['results'] as List? ?? [];
      
      credits = [...upcomingWorks, ...topWorks];
    } else if (contributor.type == ContributorType.movie) {
      credits = [await _tmdbService.getMovieDetails(contributor.tmdbId)];
    } else if (contributor.type == ContributorType.tvShow) {
      final data = await _tmdbService.getTvDetails(contributor.tmdbId);
      final List<Map<String, dynamic>> showCredits = [];
      if (data['next_episode_to_air'] != null) {
        final nextEp = Map<String, dynamic>.from(data['next_episode_to_air']);
        nextEp['media_type'] = 'tv';
        nextEp['name'] = '${data['name']} - S${nextEp['season_number'].toString().padLeft(2, '0')}E${nextEp['episode_number'].toString().padLeft(2, '0')} - ${nextEp['name']}';
        showCredits.add(nextEp);
      }
      if (data['last_episode_to_air'] != null) {
        final lastEp = Map<String, dynamic>.from(data['last_episode_to_air']);
        lastEp['media_type'] = 'tv';
        lastEp['name'] = '${data['name']} - S${lastEp['season_number'].toString().padLeft(2, '0')}E${lastEp['episode_number'].toString().padLeft(2, '0')} - ${lastEp['name']}';
        showCredits.add(lastEp);
      }
      final showAsWork = Map<String, dynamic>.from(data);
      showAsWork['media_type'] = 'tv';
      showCredits.add(showAsWork);
      credits = showCredits;
    }
    
    await updateContributorDetail(contributor, credits);
  }

  /// Enriches a sparse contributor and adds it to the repository.
  /// NOTE: Movies, TV shows, and collections should be added to watchlist instead
  Future<bool> addEnrichedContributor(
    Contributor sparseContributor, {
    List<String>? overrideNotifyDepts,
    List<String>? overrideAvailableDepts,
    bool allRolesSelected = false,
  }) async {
    // Reject media types - they should go to watchlist
    if (sparseContributor.type == ContributorType.movie || 
        sparseContributor.type == ContributorType.tvShow ||
        sparseContributor.type == ContributorType.collection) {
      debugPrint('[ContributorLogic] ERROR: Movies/TV shows/collections should be added to watchlist, not contributors');
      throw ArgumentError('Movies/TV shows/collections should be added to watchlist, not contributors. Use WatchlistLogic.addWorkToWatchlist() instead.');
    }

    final prefs = _preferencesRepository.getPreferences();

    debugPrint('[ContributorLogic] addEnrichedContributor called for ${sparseContributor.name}');
    debugPrint('[ContributorLogic] sparseContributor.knownFor: "${sparseContributor.knownFor}"');
    debugPrint('[ContributorLogic] overrideNotifyDepts: $overrideNotifyDepts');
    debugPrint('[ContributorLogic] overrideAvailableDepts: $overrideAvailableDepts');

    // 1. Fetch Credits & Determine Available Departments (unless provided)
    final availableDepts = overrideAvailableDepts ?? await getAvailableDepartments(sparseContributor);

    // 2. Initial Department Selection
    List<String> notifyDepts = [];
    if (overrideNotifyDepts != null) {
      notifyDepts = overrideNotifyDepts;
      debugPrint('[ContributorLogic] Using overrideNotifyDepts: $notifyDepts');
    } else if (sparseContributor.type == ContributorType.person) {
      // Include both default departments AND the person's knownFor category
      final defaultDepts = availableDepts.where((d) => prefs.effectiveDefaultDepartments.contains(d)).toList();
      // Extract just the role part from knownFor (before the "•" separator)
      final knownForRole = sparseContributor.knownFor.isNotEmpty 
          ? sparseContributor.knownFor.split('•').first.trim()
          : '';
      debugPrint('[ContributorLogic] extracted knownForRole: "$knownForRole"');
      final knownForDept = knownForRole.isNotEmpty ? [knownForRole] : <String>[];
      notifyDepts = <String>{...defaultDepts, ...knownForDept}.toList();
      debugPrint('[ContributorLogic] Computed notifyDepts: $notifyDepts');
    } else {
      notifyDepts = List.from(availableDepts);
    }

    // 3. Calculate Latest Work
    final tempContributor = Contributor(
      tmdbId: sparseContributor.tmdbId,
      name: sparseContributor.name,
      type: sparseContributor.type,
      profilePath: sparseContributor.profilePath,
      notifyForDepartments: notifyDepts,
      availableDepartments: availableDepts,
      knownFor: sparseContributor.knownFor,
      allRolesSelected: allRolesSelected,
    );

    final latestWork = await _latestWorkLogic.calculateLatestWork(
      tempContributor,
      pretendToday: prefs.pretendToday,
    );

    // 4. Apply global TV preferences if needed
    TvNotificationPreferences? finalTvPrefs = sparseContributor.tvNotificationPrefs;
    if (sparseContributor.type == ContributorType.tvShow && finalTvPrefs == null) {
      // Apply global TV preferences as defaults
      finalTvPrefs = prefs.defaultTvNotificationPrefs ?? TvNotificationPreferences();
    }

    // 5. Create Final Enriched Contributor
    final enrichedContributor = Contributor(
      tmdbId: sparseContributor.tmdbId,
      name: sparseContributor.name,
      type: sparseContributor.type,
      profilePath: sparseContributor.profilePath,
      notifyForDepartments: notifyDepts,
      availableDepartments: availableDepts,
      knownFor: sparseContributor.knownFor,
      latestWork: latestWork,
      followedAt: DateTime.now(),
      allRolesSelected: allRolesSelected,
      tvNotificationPrefs: finalTvPrefs,
      notifyTvEpisodeWork: sparseContributor.notifyTvEpisodeWork,
      showStatus: sparseContributor.showStatus,
      totalSeasons: sparseContributor.totalSeasons,
      nextEpisodeDate: sparseContributor.nextEpisodeDate,
    );

    debugPrint('[ContributorLogic] Final enrichedContributor.notifyForDepartments: ${enrichedContributor.notifyForDepartments}');
    debugPrint('[ContributorLogic] Final enrichedContributor.availableDepartments: ${enrichedContributor.availableDepartments}');
    debugPrint('[ContributorLogic] Final enrichedContributor.allRolesSelected: ${enrichedContributor.allRolesSelected}');

    // Update contributor detail if repository is available
    if (sparseContributor.type == ContributorType.person) {
      try {
        final creditData = await _tmdbService.getPersonCombinedCredits(sparseContributor.tmdbId);
        final credits = [...(creditData['cast'] ?? []), ...(creditData['crew'] ?? [])];
        await updateContributorDetail(enrichedContributor, credits);
      } catch (e) {
        debugPrint('[ContributorLogic] Error updating detail during addition: $e');
      }
    } else if (sparseContributor.type == ContributorType.company) {
       try {
         final topWorksResponse = await _tmdbService.getCompanyTopWorks(sparseContributor.tmdbId);
         final topWorks = topWorksResponse['results'] as List? ?? [];
         await updateContributorDetail(enrichedContributor, topWorks);
       } catch (e) {
         debugPrint('[ContributorLogic] Error updating company detail during addition: $e');
       }
    }

    return await _contributorRepository.addContributor(enrichedContributor);
  }

  /// Adds a movie or TV show contributor to both the contributor repository and the watchlist
  /// DEPRECATED: This method creates duplicate systems. Use watchlist directly for movies/shows/collections.
  @Deprecated('Use watchlist directly for movies/shows/collections instead of contributor system')
  Future<bool> addEnrichedContributorWithWatchlist(
    Contributor sparseContributor, {
    List<String>? overrideNotifyDepts,
    List<String>? overrideAvailableDepts,
    bool allRolesSelected = false,
    required WatchlistLogic watchlistLogic,
  }) async {
    debugPrint('[ContributorLogic] WARNING: addEnrichedContributorWithWatchlist is deprecated');
    debugPrint('[ContributorLogic] Movies/shows/collections should be added directly to watchlist');
    
    // For now, just add to watchlist only (not to contributors)
    if (sparseContributor.type == ContributorType.movie || 
        sparseContributor.type == ContributorType.tvShow ||
        sparseContributor.type == ContributorType.collection) {
      
      // Create contributor snapshot for the watchlist entry
      final contributorSnapshot = ContributorSnapshot(
        contributorId: sparseContributor.tmdbId,
        name: sparseContributor.name,
        role: sparseContributor.type == ContributorType.movie ? 'Movie' : 
              sparseContributor.type == ContributorType.tvShow ? 'TV Show' : 'Collection',
      );

      // Determine work type and release type
      WorkType workType;
      ReleaseType releaseType = ReleaseType.theatrical; // Default
      
      if (sparseContributor.type == ContributorType.movie) {
        workType = WorkType.movie;
        releaseType = ReleaseType.theatrical;
      } else if (sparseContributor.type == ContributorType.tvShow) {
        workType = WorkType.tvShow;
        releaseType = ReleaseType.streaming;
      } else {
        workType = WorkType.movie; // Collections are treated as movies
        releaseType = ReleaseType.theatrical;
      }

      try {
        await watchlistLogic.addWorkToWatchlist(
          tmdbId: sparseContributor.tmdbId,
          type: workType,
          title: sparseContributor.name,
          posterPath: sparseContributor.profilePath,
          releaseDate: null, // Will be populated from TMDB data if needed
          releaseType: releaseType,
          followedContributors: [contributorSnapshot],
        );
        
        debugPrint('[ContributorLogic] Added ${sparseContributor.name} to watchlist only');
        return true;
      } catch (e) {
        debugPrint('[ContributorLogic] Error adding ${sparseContributor.name} to watchlist: $e');
        return false;
      }
    }

    // For non-media types, fall back to regular method
    return await addEnrichedContributor(
      sparseContributor,
      overrideNotifyDepts: overrideNotifyDepts,
      overrideAvailableDepts: overrideAvailableDepts,
      allRolesSelected: allRolesSelected,
    );
  }

  /// Updates a contributor's followed roles and recalculates their latest work.
  Future<void> updateContributorRoles(Contributor contributor, List<String> newRoles) async {
    final prefs = _preferencesRepository.getPreferences();
    
    final updatedTemp = Contributor(
      tmdbId: contributor.tmdbId,
      name: contributor.name,
      type: contributor.type,
      profilePath: contributor.profilePath,
      notifyForDepartments: newRoles,
      availableDepartments: contributor.availableDepartments,
      knownFor: contributor.knownFor,
      followedAt: contributor.followedAt,
      allRolesSelected: contributor.allRolesSelected,
      tvNotificationPrefs: contributor.tvNotificationPrefs, // Preserve TV preferences
      showStatus: contributor.showStatus,
      totalSeasons: contributor.totalSeasons,
      nextEpisodeDate: contributor.nextEpisodeDate,
    );

    final latestWork = await _latestWorkLogic.calculateLatestWork(
      updatedTemp,
      pretendToday: prefs.pretendToday,
    );

    final finalUpdated = Contributor(
      tmdbId: contributor.tmdbId,
      name: contributor.name,
      type: contributor.type,
      profilePath: contributor.profilePath,
      notifyForDepartments: newRoles,
      availableDepartments: contributor.availableDepartments,
      knownFor: contributor.knownFor,
      latestWork: latestWork,
      followedAt: contributor.followedAt,
      allRolesSelected: contributor.allRolesSelected,
      tvNotificationPrefs: contributor.tvNotificationPrefs, // Preserve TV preferences
      showStatus: contributor.showStatus,
      totalSeasons: contributor.totalSeasons,
      nextEpisodeDate: contributor.nextEpisodeDate,
    );

    await _contributorRepository.updateContributor(finalUpdated);
  }

  /// Refreshes the enrichment data (Latest Work & available departments) for all followed contributors.
  Future<void> refreshAllContributors() async {
    final contributors = _contributorRepository.getContributors();
    final prefs = _preferencesRepository.getPreferences();

    for (final contributor in contributors) {
      try {
        // Fetch person credits to update departments and latest work
        if (contributor.type == ContributorType.person) {
          final creditData = await _tmdbService.getPersonCombinedCredits(contributor.tmdbId);
          final cast = creditData['cast'] as List? ?? [];
          final crew = creditData['crew'] as List? ?? [];
          final allCredits = [...cast, ...crew];

          final Set<String> depts = {};
          for (var c in allCredits) {
            String dept = c['department'] ?? '';
            String job = c['job'] ?? '';
            String role = TmdbMapping.mapTmdbDeptToRole(dept, job: job);

            if (role.isNotEmpty) {
              depts.add(role);
            }
          }
          final availableDepts = depts.toList()..sort();

          final latestWork = await _latestWorkLogic.calculateLatestWork(
            contributor,
            pretendToday: prefs.pretendToday,
          );

          final updated = Contributor(
            tmdbId: contributor.tmdbId,
            name: contributor.name,
            type: contributor.type,
            profilePath: contributor.profilePath,
            notifyForDepartments: contributor.notifyForDepartments,
            availableDepartments: availableDepts,
            knownFor: contributor.knownFor,
            latestWork: latestWork,
            followedAt: contributor.followedAt,
            allRolesSelected: contributor.allRolesSelected,
            tvNotificationPrefs: contributor.tvNotificationPrefs, // Preserve TV preferences
            showStatus: contributor.showStatus,
            totalSeasons: contributor.totalSeasons,
            nextEpisodeDate: contributor.nextEpisodeDate,
          );
          await _contributorRepository.updateContributor(updated);
          
          // Also update details during refresh
          await updateContributorDetail(updated, allCredits);
        } else if (contributor.type == ContributorType.company) {
           // For companies, update latestWork and details
           final latestWork = await _latestWorkLogic.calculateLatestWork(
            contributor,
            pretendToday: prefs.pretendToday,
          );
           final updated = Contributor(
            tmdbId: contributor.tmdbId,
            name: contributor.name,
            type: contributor.type,
            profilePath: contributor.profilePath,
            notifyForDepartments: contributor.notifyForDepartments,
            availableDepartments: contributor.availableDepartments,
            knownFor: contributor.knownFor,
            latestWork: latestWork,
            followedAt: contributor.followedAt,
            allRolesSelected: contributor.allRolesSelected,
            tvNotificationPrefs: contributor.tvNotificationPrefs,
            showStatus: contributor.showStatus,
            totalSeasons: contributor.totalSeasons,
            nextEpisodeDate: contributor.nextEpisodeDate,
          );
          await _contributorRepository.updateContributor(updated);
          
          try {
            // Fetch both top works and upcoming works for companies
            final topWorksResponse = await _tmdbService.getCompanyTopWorks(contributor.tmdbId);
            final topWorks = topWorksResponse['results'] as List? ?? [];
            
            final upcomingResponse = await _tmdbService.getCompanyUpcomingWorks(contributor.tmdbId);
            final upcomingWorks = upcomingResponse['results'] as List? ?? [];
            
            // Combine both lists for processing
            final allWorks = [...upcomingWorks, ...topWorks];
            await updateContributorDetail(updated, allWorks);
          } catch (e) {
            debugPrint('[ContributorLogic] Error refreshing company detail: $e');
          }
        } else {
           // For others, just update latestWork
           final latestWork = await _latestWorkLogic.calculateLatestWork(
            contributor,
            pretendToday: prefs.pretendToday,
          );
           final updated = Contributor(
            tmdbId: contributor.tmdbId,
            name: contributor.name,
            type: contributor.type,
            profilePath: contributor.profilePath,
            notifyForDepartments: contributor.notifyForDepartments,
            availableDepartments: contributor.availableDepartments,
            knownFor: contributor.knownFor,
            latestWork: latestWork,
            followedAt: contributor.followedAt,
            allRolesSelected: contributor.allRolesSelected,
            tvNotificationPrefs: contributor.tvNotificationPrefs, // Preserve TV preferences
            showStatus: contributor.showStatus,
            totalSeasons: contributor.totalSeasons,
            nextEpisodeDate: contributor.nextEpisodeDate,
          );
          await _contributorRepository.updateContributor(updated);
        }
      } catch (e) {
        debugPrint('Error refreshing ${contributor.name}: $e');
      }
    }
  }

  /// Private helper to update cached contributor details
  Future<void> updateContributorDetail(Contributor contributor, List<dynamic> allCredits) async {
    if (_contributorDetailRepository == null) {
      debugPrint('[ContributorLogic] ContributorDetailRepository is null, skipping detail update for ${contributor.name}');
      return;
    }

    debugPrint('[ContributorLogic] Updating contributor detail for ${contributor.name} (${contributor.tmdbId}) with ${allCredits.length} credits');

    final now = DateTime.now();
    final Set<Work> allWorksSet = {};
    
    // Group credits by ID and WorkType to combine roles (e.g. Director and Writer on same film)
    // TMDB IDs are only unique WITHIN a media type, so we must group by both.
    final Map<String, List<dynamic>> groupedCredits = {};
    for (final credit in allCredits) {
      if (credit == null || credit['id'] == null) continue;
      final id = credit['id'] as int;
      
      final mediaType = credit['media_type'] ?? (contributor.type == ContributorType.movie ? 'movie' : 'tv');
      final isEpisode = credit['episode_number'] != null;
      final key = '${mediaType}_${id}_$isEpisode';
      groupedCredits.putIfAbsent(key, () => []).add(credit);
    }

    for (final entry in groupedCredits.entries) {
      final credits = entry.value;
      final first = credits.first;
      final id = first['id'] as int;
      
      final mediaType = first['media_type'] as String?;
      
      // Release dates can be under various keys depending on API endpoint
      final releaseDateStr = (first['release_date'] ?? first['first_air_date'] ?? first['air_date']) as String?;
      DateTime? releaseDate;
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        // Only take the YYYY-MM-DD part
        final datePart = releaseDateStr.length >= 10 ? releaseDateStr.substring(0, 10) : releaseDateStr;
        releaseDate = DateTime.tryParse(datePart);
      }

      final roles = credits.map((c) {
        // For cast members (actors), TMDB doesn't provide a department field
        // We need to detect this and set it to 'Acting' so it maps to 'Actor'
        String? department = c['department'] as String?;
        final character = c['character'] as String?;
        final job = c['job'] as String?;
        
        // If we have a character field (even if empty) and no job, this is a cast member (actor)
        // Cast members have 'character' field, crew members have 'job' field
        if (character != null && job == null && (department == null || department == 'null' || department.isEmpty)) {
          department = 'Acting';
        }
        
        debugPrint('[ContributorLogic] Creating ContributorRole: dept="$department", job="$job", char="$character"');
        
        return ContributorRole(
          contributorId: contributor.tmdbId,
          contributorName: contributor.name,
          role: job ?? character ?? (contributor.type == ContributorType.movie ? 'Movie' : (c['media_type'] == 'tv' ? 'TV Show' : 'Cast/Crew')),
          department: department,
          character: character,
        );
      }).toList();

      if (mediaType == 'tv') {
        // Always ensure we have a "Show" object for TV credits to store show-level metadata (endDate, status)
        final showWork = Work(
          tmdbId: id,
          title: (first['name'] ?? first['title'] ?? 'Unknown') as String,
          posterPath: first['poster_path'] ?? first['still_path'] as String?,
          releaseDate: releaseDate,
          type: WorkType.tvShow,
          tmdbRating: (first['vote_average'] as num?)?.toDouble(),
          popularity: (first['popularity'] as num?)?.toDouble(),
          voteCount: first['vote_count'] as int?,
          contributorRoles: roles,
          imdbId: first['external_ids']?['imdb_id'] ?? first['imdb_id'] as String?,
          status: first['status'] as String?,
        );
        allWorksSet.add(showWork);

        // Also add all unique episodes found in the credits group
        final Set<String> seenEpisodes = {};
        for (final credit in credits) {
          final episodeNum = credit['episode_number'] as int?;
          final seasonNum = credit['season_number'] as int?;
          final episodeTitle = (credit['title'] ?? credit['name'] ?? 'Unknown') as String;
          
          if (episodeNum != null) {
            final epKey = '${seasonNum}_${episodeNum}_$episodeTitle';
            if (!seenEpisodes.contains(epKey)) {
              seenEpisodes.add(epKey);
              
                allWorksSet.add(Work(
                  tmdbId: credit['id'] as int, // Actually the EPISODE id if provided, but combined credits often return showId as 'id'
                  showId: id, // id is the group key id, which is showId
                  title: episodeTitle,
                  posterPath: credit['still_path'] ?? credit['poster_path'] ?? first['poster_path'] as String?,
                  releaseDate: _parseDate(credit['release_date'] ?? credit['first_air_date'] ?? credit['air_date']),
                  type: WorkType.tvEpisode,
                  tmdbRating: (credit['vote_average'] as num?)?.toDouble(),
                  popularity: (credit['popularity'] as num?)?.toDouble(),
                  voteCount: credit['vote_count'] as int?,
                  contributorRoles: roles,
                  imdbId: credit['external_ids']?['imdb_id'] ?? credit['imdb_id'] as String?,
                  seasonNumber: seasonNum,
                  episodeNumber: episodeNum,
                  status: credit['status'] as String?,
                  showName: (first['name'] ?? first['title'] ?? 'Unknown') as String,
                ));
            }
          }
        }
      } else {
        // Movie Logic
        allWorksSet.add(Work(
          tmdbId: id,
          title: (first['title'] ?? first['name'] ?? 'Unknown') as String,
          posterPath: first['poster_path'] ?? first['still_path'] as String?,
          releaseDate: releaseDate,
          type: WorkType.movie,
          tmdbRating: (first['vote_average'] as num?)?.toDouble(),
          popularity: (first['popularity'] as num?)?.toDouble(),
          voteCount: first['vote_count'] as int?,
          contributorRoles: roles,
          imdbId: first['external_ids']?['imdb_id'] ?? first['imdb_id'] as String?,
          status: first['status'] as String?,
        ));
      }
    }

    final List<Work> allWorks = allWorksSet.toList();

    // Requirements: Things in status of Planned or without release date go to Upcoming.
    // Also including In Production and Post Production for consistency with "Upcoming"
    final upcomingPoolStatuses = {'planned', 'in production', 'post production', 'rumored'};
    
    final upcoming = allWorks.where((w) {
      final status = w.status?.toLowerCase() ?? '';
      if (upcomingPoolStatuses.contains(status)) return true;
      if (w.releaseDate == null && w.type != WorkType.tvEpisode) return true;
      return w.releaseDate != null && w.releaseDate!.isAfter(now);
    }).toList();

    final past = allWorks.where((w) {
      final status = w.status?.toLowerCase() ?? '';
      if (upcomingPoolStatuses.contains(status)) return false;
      if (w.releaseDate == null) return false;
      return !w.releaseDate!.isAfter(now);
    }).toList();
    
    // Use WorkSortingLogic to sort and limit
    var sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(upcoming);
    var sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(past);
    
    // Filter out works that don't have both rating and popularity
    // ENHANCEMENT: Also filter out TV Episodes from Hits to avoid cluttering with 
    // every single directed episode when the show itself is a hit.
    // CRITICAL: Exclude Upcoming works from being ranked as Biggest Hits.
    final worksWithMetrics = allWorks.where((work) {
      final isUpcoming = upcoming.contains(work);
      return !isUpcoming && work.tmdbRating != null && work.popularity != null && work.type != WorkType.tvEpisode;
    }).toList();
    
    debugPrint('[ContributorLogic] Hits Pool: ${worksWithMetrics.length} works (Total allWorks: ${allWorks.length})');
    var sortedHits = WorkSortingLogic.rankBiggestHits(worksWithMetrics);

    List<Work> finalAllWorks = allWorks;

    // ENHANCEMENT: Fetch latest episodes for top TV shows to enable grouping
    if (contributor.type == ContributorType.person) {
      // Collect IDs of shows that have episodes in sortedLatest
      final latestShowTitles = sortedLatest
          .where((w) => w.type == WorkType.tvEpisode)
          .map((w) => w.title)
          .toSet();
          
      final showsForLatestEpisodes = allWorks.where((w) => 
        w.type == WorkType.tvShow && latestShowTitles.contains(w.title)
      ).toList();

      final List<Work> relevantTvShows = {
        ...sortedUpcoming.where((w) => w.type == WorkType.tvShow),
        ...sortedLatest.where((w) => w.type == WorkType.tvShow),
        ...sortedHits.where((w) => w.type == WorkType.tvShow),
        ...showsForLatestEpisodes,
      }.take(20).toList(); // Increased limit to 20 for more thorough Latest Releases coverage

      if (relevantTvShows.isNotEmpty) {
        debugPrint('[ContributorLogic] Enrichment: Fetching episodes for ${relevantTvShows.length} shows');
        for (final show in relevantTvShows) {
          try {
            if (show.title.toLowerCase().contains('far cry')) {
              debugPrint('[DEBUG] Enrichment: Processing "Far Cry" (ID: ${show.tmdbId}). Current Status in Work object: ${show.status}');
            }
            if (show.title.toLowerCase().contains('flag means death')) {
              debugPrint('[DEBUG] Processing "Our Flag Means Death" for episodes');
            }
            // First get show details to find seasons
            final details = await _tmdbService.getTvDetailsWithEpisodes(show.tmdbId);
            final List<Map<String, dynamic>> episodesToProcess = [];
            
            // Update the show object with end date and status if we have it
            final showStatus = details['status'] as String?;
            final lastAirDateStr = details['last_air_date'] as String?;
            DateTime? showEndDate;
            
            if (lastAirDateStr != null && lastAirDateStr.isNotEmpty) {
               // Only treat as "Ended" if the status says so
               final lowerStatus = showStatus?.toLowerCase() ?? '';
               if (lowerStatus == 'ended' || lowerStatus == 'canceled') {
                 showEndDate = DateTime.tryParse(lastAirDateStr);
               }
            }

            final showIndex = allWorks.indexWhere((w) => w.tmdbId == show.tmdbId && w.type == WorkType.tvShow);
            if (showIndex != -1) {
              allWorks[showIndex] = allWorks[showIndex].copyWith(
                endDate: showEndDate,
                status: showStatus,
              );
              if (show.title.contains('Legion') || show.title.contains('Fargo')) {
                debugPrint('[DEBUG] Updated ${show.title} with status=$showStatus, endDate=$showEndDate in allWorks');
              }
            }
            
            // Check if this person is a "Creator" on the show
            final isCreator = show.contributorRoles.any((role) => 
               role.role.toLowerCase() == 'creator' ||
               role.department?.toLowerCase() == 'creator'
            );

            // 1. Add next/last episodes as priority ONLY for followed TV Shows or Creators
            // This prevents guest actors/directors from having the show's latest episodes 
            // injected into their history if they weren't involved in them.
            if (contributor.type == ContributorType.tvShow || isCreator) {
              if (details['next_episode_to_air'] != null) episodesToProcess.add(Map<String, dynamic>.from(details['next_episode_to_air']));
              if (details['last_episode_to_air'] != null) episodesToProcess.add(Map<String, dynamic>.from(details['last_episode_to_air']));
            }

            // 2. ENHANCEMENT: If the person is a director on this show, fetch the most recent full season
            // to find more directed episodes.
            final isDirectorOnShow = show.contributorRoles.any((r) => 
               r.role.toLowerCase() == 'director' || r.department?.toLowerCase() == 'directing'
            );
            final isWriterOnShow = show.contributorRoles.any((r) => 
               r.role.toLowerCase().contains('writer') || r.department?.toLowerCase() == 'writing' || r.role.toLowerCase().contains('screenplay')
            );
            
            if (show.title.contains('Legion')) {
              debugPrint('[DEBUG Legion] isDirectorOnShow: $isDirectorOnShow, isWriterOnShow: $isWriterOnShow');
              debugPrint('[DEBUG Legion] Show roles: ${show.contributorRoles.map((r) => '${r.role}/${r.department}').toList()}');
            }
            
            // If they are EITHER, we should check episodes to be granular
            if ((isDirectorOnShow || isWriterOnShow) && details['seasons'] != null) {
              final seasons = details['seasons'] as List;
              for (final season in seasons) {
                final seasonNum = season['season_number'] as int? ?? 0;
                if (seasonNum == 0) continue; // Skip specials usually
                
                debugPrint('[ContributorLogic] Fetching season $seasonNum for show ${show.title}');
                try {
                  final seasonDetails = await _tmdbService.getTvSeasonDetails(show.tmdbId, seasonNum);
                  final seasonEpisodes = seasonDetails['episodes'] as List? ?? [];
                  
                  if (show.title.contains('Legion')) {
                    debugPrint('[DEBUG Legion] Season $seasonNum has ${seasonEpisodes.length} episodes');
                  }
                  
                  for (final epData in seasonEpisodes) {
                    if (!episodesToProcess.any((e) => e['id'] == epData['id'])) {
                      final epCrew = epData['crew'] as List? ?? [];
                      final myCrewCredits = epCrew.where((c) => c['id'] == contributor.tmdbId || c['name'] == contributor.name).toList();

                      bool didDirect = false;
                      bool didWrite = false;
                      
                      for (final c in myCrewCredits) {
                        final job = c['job']?.toString().toLowerCase() ?? '';
                        if (job == 'director') didDirect = true;
                        if (['writer', 'screenplay', 'teleplay', 'story with', 'story by'].contains(job)) didWrite = true;
                      }
                      
                      if (show.title.contains('Legion') && (didDirect || didWrite)) {
                        debugPrint('[DEBUG Legion] Episode ${epData['name']}: didDirect=$didDirect, didWrite=$didWrite');
                        debugPrint('[DEBUG Legion]   Crew jobs: ${myCrewCredits.map((c) => c['job']).toList()}');
                      }
                      
                      if (didDirect || didWrite) {
                         // Attach roles to the raw map so we can read them later
                         final epMap = Map<String, dynamic>.from(epData);
                         epMap['__derived_roles'] = <String>[];
                         if (didDirect) (epMap['__derived_roles'] as List).add('Director');
                         if (didWrite) (epMap['__derived_roles'] as List).add('Writer');
                         
                         episodesToProcess.add(epMap);
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('[ContributorLogic] Error fetching season $seasonNum: $e');
                }
              }
            }

            if (show.title.contains('Legion')) {
              debugPrint('[DEBUG Legion] Total episodes to process: ${episodesToProcess.length}');
            }
            
            for (final ep in episodesToProcess) {
              final airDateStr = ep['air_date'] as String?;
              DateTime? airDate;
              if (airDateStr != null && airDateStr.isNotEmpty) {
                airDate = DateTime.tryParse(airDateStr);
              }

              // De-duplicate: Ensure we don't add the same episode multiple times to allWorks
              final epId = ep['id'];
              if (allWorks.any((w) => w.type == WorkType.tvEpisode && w.tmdbId == epId)) {
                continue;
              }
              
              final derivedRoles = ep['__derived_roles'] as List<dynamic>?;
              if (show.title.contains('Legion') && derivedRoles != null) {
                debugPrint('[DEBUG Legion] Episode ${ep['name']} __derived_roles: $derivedRoles');
              }
              
              allWorks.add(Work(
                tmdbId: epId,
                showId: show.tmdbId,
                title: '${show.title} - S${ep['season_number'].toString().padLeft(2, '0')}E${ep['episode_number'].toString().padLeft(2, '0')} - ${ep['name']}',
                posterPath: show.posterPath ?? ep['still_path'],
                releaseDate: airDate,
                type: WorkType.tvEpisode,
                tmdbRating: (ep['vote_average'] as num?)?.toDouble(),
                voteCount: ep['vote_count'] as int?,
                popularity: show.popularity,
                contributorRoles: derivedRoles?.map((r) {
                  return ContributorRole(
                    contributorId: contributor.tmdbId,
                    contributorName: contributor.name,
                    role: r.toString(),
                    department: r.toString() == 'Director' ? 'Directing' : 'Writing',
                  );
                }).toList() ?? [],
                imdbId: show.imdbId,
                seasonNumber: ep['season_number'],
                episodeNumber: ep['episode_number'],
                showName: show.title,
              ));
            }
          } catch (e) {
            debugPrint('[ContributorLogic] Error fetching episodes for show ${show.title}: $e');
          }
          
          if (show.title.contains('Legion')) {
            final legionCount = allWorks.where((w) => w.title.contains('Legion')).length;
            debugPrint('[DEBUG Legion] After episode processing, allWorks has $legionCount Legion entries');
          }
        }

        // Re-sort everything after adding episodes and filter out duplicates
        final allWorksEnriched = List<Work>.from(allWorks);
        debugPrint('[ContributorLogic] Enrichment: allWorksEnriched count = ${allWorksEnriched.length}');
        
        final legionEnrichedCount = allWorksEnriched.where((w) => w.title.contains('Legion')).length;
        debugPrint('[DEBUG Legion] allWorksEnriched has $legionEnrichedCount Legion entries');
        final legionEpisodes = allWorksEnriched.where((w) => w.title.contains('Legion') && w.type == WorkType.tvEpisode).toList();
        debugPrint('[DEBUG Legion] Legion episodes: ${legionEpisodes.length}');
        for (var ep in legionEpisodes.take(3)) {
          debugPrint('[DEBUG Legion]   - ${ep.title}, roles: ${ep.contributorRoles.map((r) => r.role).toList()}');
        }
        
        // Logical de-duplication: If we have episodes for a show, remove the generic show entry from history/hits
        final Set<String> showsWithEpisodes = allWorksEnriched
            .where((w) => w.type == WorkType.tvEpisode)
            .map((w) => TvShowDisplayLogic.extractShowTitle(w.title))
            .toSet();
        debugPrint('[ContributorLogic] Enrichment: showsWithEpisodes = $showsWithEpisodes');
        
        final filteredWorks = allWorksEnriched.where((w) {
          if (w.type == WorkType.tvShow) {
            final isCreator = w.contributorRoles.any((role) => 
              role.role.toLowerCase() == 'creator' ||
              role.department?.toLowerCase() == 'creator'
            );
            if (isCreator) {
              debugPrint('[ContributorLogic] Keeping creator show: ${w.title}');
              return true;
            }

            final hasEps = showsWithEpisodes.contains(w.title);
            if (hasEps) {
              debugPrint('[ContributorLogic] Filtering out show with episodes: ${w.title}');
              return false;
            }
            return true;
          }
          return true;
        }).toList();
        debugPrint('[ContributorLogic] Enrichment: filteredWorks count = ${filteredWorks.length}');
        
        finalAllWorks = filteredWorks;

        // Requirements: Things in status of Planned or without release date go to Upcoming.
        // Also including In Production and Post Production for consistency with "Upcoming"
        final upcomingPoolStatuses = {'planned', 'in production', 'post production', 'rumored'};

        final upcomingEnriched = filteredWorks.where((w) {
          if (w.type == WorkType.tvShow && showsWithEpisodes.contains(w.title)) return false;
          
          final status = w.status?.toLowerCase() ?? '';
          if (upcomingPoolStatuses.contains(status)) {
            if (w.title.toLowerCase().contains('far cry')) debugPrint('[DEBUG] Far Cry flagged as upcoming via Status: $status');
            return true;
          }
          if (w.releaseDate == null && w.type != WorkType.tvEpisode) {
            if (w.title.toLowerCase().contains('far cry')) debugPrint('[DEBUG] Far Cry flagged as upcoming via Null Date');
            return true;
          }
          final isFuture = w.releaseDate != null && w.releaseDate!.isAfter(now);
          if (isFuture && w.title.toLowerCase().contains('far cry')) debugPrint('[DEBUG] Far Cry flagged as upcoming via Future Date');
          return isFuture;
        }).toList();

        final pastEnriched = filteredWorks.where((w) {
          if (w.type == WorkType.tvShow && showsWithEpisodes.contains(w.title)) return false;
          
          final status = w.status?.toLowerCase() ?? '';
          if (upcomingPoolStatuses.contains(status)) return false;
          if (w.releaseDate == null) return false;
          return !w.releaseDate!.isAfter(now);
        }).toList();
        
        sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(upcomingEnriched);
        sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(pastEnriched);
        
        debugPrint('[DEBUG] Enrichment Complete for ${contributor.name}: upcoming=${upcomingEnriched.length}, past=${pastEnriched.length}');
        for (var w in filteredWorks) {
          if (w.title.toLowerCase().contains('far cry')) {
             debugPrint('[DEBUG] AFTER Enrichment "Far Cry": Status=${w.status}, Date=${w.releaseDate}, Type=${w.type}');
             final isUp = upcomingEnriched.contains(w);
             final isPast = pastEnriched.contains(w);
             debugPrint('[DEBUG] "Far Cry" classification: IsUpcoming=$isUp, IsPast=$isPast');
          }
        }
        
        // For hits: Get top 100 hits. Sort by date for display.
        // For hits: Get top 100 hits. Sort by date for display.
        // Must exclude upcoming works from hits and creator shows fallback
        final nonUpcomingFilteredWorks = filteredWorks.where((w) {
          return !sortedUpcoming.any((u) => u.tmdbId == w.tmdbId && u.type == w.type);
        }).toList();

        final topHits = WorkSortingLogic.rankBiggestHits(nonUpcomingFilteredWorks);
        // Ensure ALL creator shows are in the pool if they weren't matched as hits (fallback)
        final creatorShows = nonUpcomingFilteredWorks.where((w) {
          final isCreator = w.type == WorkType.tvShow && w.contributorRoles.any((r) {
            final matches = r.role.toLowerCase() == 'creator' || r.department?.toLowerCase() == 'creator';
            if (matches) {
              debugPrint('[DEBUG] Creator check matched for "${w.title}". Role: "${r.role}", Dept: "${r.department}"');
            }
            return matches;
          });
          return isCreator;
        }).toList();

        // Merge hits and creator shows, uniquely
        final mergedHits = <Work>{...topHits, ...creatorShows}.toList();
        debugPrint('[ContributorLogic] Enrichment: Final mergedHits count = ${mergedHits.length}');

        sortedHits = List<Work>.from(mergedHits)..sort((a, b) {
          if (a.releaseDate == null && b.releaseDate == null) return 0;
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return b.releaseDate!.compareTo(a.releaseDate!);
        });

      }
    }

    debugPrint('[ContributorLogic] Final Detail Construction: allWorks=${finalAllWorks.length}, upcoming=${sortedUpcoming.length}, hits=${sortedHits.length}');
    if (finalAllWorks.isEmpty) {
      debugPrint('[DEBUG] WARNING: finalAllWorks is EMPTY for ${contributor.name}');
    }

    final detail = ContributorDetail(
      tmdbId: contributor.tmdbId,
      name: contributor.name,
      profilePath: contributor.profilePath,
      imdbId: contributor.imdbId,
      type: contributor.type,
      upcomingWorks: sortedUpcoming,
      latestReleases: sortedLatest,
      biggestHits: sortedHits,
      allWorks: finalAllWorks,
      lastUpdated: now,
    );

    await _contributorDetailRepository!.cacheContributorDetail(detail);
    debugPrint('[ContributorLogic] Successfully cached contributor detail for ${contributor.name}');
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr is! String || dateStr.isEmpty) return null;
    final datePart = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    return DateTime.tryParse(datePart);
  }
}
