import 'package:flutter/foundation.dart';
import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/contributor_detail_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/tmdb_service.dart';
import 'latest_work_logic.dart';
import 'work_sorting_logic.dart';
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

  /// Enriches a sparse contributor and adds it to the repository.
  Future<bool> addEnrichedContributor(
    Contributor sparseContributor, {
    List<String>? overrideNotifyDepts,
    List<String>? overrideAvailableDepts,
    bool allRolesSelected = false,
  }) async {
    final prefs = _preferencesRepository.getPreferences();

    // 1. Fetch Credits & Determine Available Departments (unless provided)
    final availableDepts = overrideAvailableDepts ?? await getAvailableDepartments(sparseContributor);

    // 2. Initial Department Selection
    List<String> notifyDepts = [];
    if (overrideNotifyDepts != null) {
      notifyDepts = overrideNotifyDepts;
    } else if (sparseContributor.type == ContributorType.person) {
      notifyDepts = availableDepts.where((d) => prefs.effectiveDefaultDepartments.contains(d)).toList();
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
            final topWorksResponse = await _tmdbService.getCompanyTopWorks(contributor.tmdbId);
            final topWorks = topWorksResponse['results'] as List? ?? [];
            await updateContributorDetail(updated, topWorks);
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
      final title = credit['title'] ?? credit['name'] ?? 'Unknown';
      final status = credit['status'] as String?;
      final releaseDate = credit['release_date'] ?? credit['first_air_date'] ?? credit['air_date'];
      
      if (title.toString().toLowerCase().contains('far cry')) {
        debugPrint('[DEBUG] Far Cry credit found: id=$id, status=$status, releaseDate=$releaseDate');
      }

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
      
      // Determine work type
      WorkType workType;
      if (mediaType == 'tv') {
        if (first['episode_number'] != null) {
          workType = WorkType.tvEpisode;
        } else {
          workType = WorkType.tvShow;
        }
      } else {
        workType = WorkType.movie;
      }
      
      // Release dates can be under various keys depending on API endpoint
      final releaseDateStr = (first['release_date'] ?? first['first_air_date'] ?? first['air_date']) as String?;
      DateTime? releaseDate;
      if (releaseDateStr != null && releaseDateStr.isNotEmpty) {
        // Only take the YYYY-MM-DD part
        final datePart = releaseDateStr.length >= 10 ? releaseDateStr.substring(0, 10) : releaseDateStr;
        releaseDate = DateTime.tryParse(datePart);
      }

      final roles = credits.map((c) => ContributorRole(
        contributorId: contributor.tmdbId,
        contributorName: contributor.name,
        role: (c['job'] ?? c['character'] ?? (contributor.type == ContributorType.movie ? 'Movie' : (c['media_type'] == 'tv' ? 'TV Show' : 'Cast/Crew'))) as String,
        department: c['department'] as String?,
        character: c['character'] as String?,
      )).toList();

      allWorksSet.add(Work(
        tmdbId: id,
        title: (first['title'] ?? first['name'] ?? 'Unknown') as String,
        posterPath: first['poster_path'] ?? first['still_path'] as String?,
        releaseDate: releaseDate,
        type: workType,
        tmdbRating: (first['vote_average'] as num?)?.toDouble(),
        popularity: (first['popularity'] as num?)?.toDouble(),
        contributorRoles: roles,
        imdbId: first['external_ids']?['imdb_id'] ?? first['imdb_id'] as String?,
        seasonNumber: first['season_number'] as int?,
        episodeNumber: first['episode_number'] as int?,
        status: first['status'] as String?,
      ));
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
      final List<Work> relevantTvShows = [
        ...sortedUpcoming.where((w) => w.type == WorkType.tvShow),
        ...sortedLatest.where((w) => w.type == WorkType.tvShow),
        ...sortedHits.where((w) => w.type == WorkType.tvShow),
      ].toSet().take(10).toList(); // Include hits and increase limit

      if (relevantTvShows.isNotEmpty) {
        debugPrint('[ContributorLogic] Enrichment: Fetching episodes for ${relevantTvShows.length} shows');
        for (final show in relevantTvShows) {
          try {
            if (show.title.toLowerCase().contains('flag means death')) {
              debugPrint('[DEBUG] Processing "Our Flag Means Death" for episodes');
            }
            // First get show details to find seasons
            final details = await _tmdbService.getTvDetailsWithEpisodes(show.tmdbId);
            final List<Map<String, dynamic>> episodesToProcess = [];
            
            // 1. Add next/last episodes as priority
            if (details['next_episode_to_air'] != null) episodesToProcess.add(Map<String, dynamic>.from(details['next_episode_to_air']));
            if (details['last_episode_to_air'] != null) episodesToProcess.add(Map<String, dynamic>.from(details['last_episode_to_air']));

            // 2. ENHANCEMENT: If the person is a director on this show, fetch the most recent full season
            // to find more directed episodes.
            final isDirectorOnShow = show.contributorRoles.any((r) => 
               r.role.toLowerCase() == 'director' || r.department?.toLowerCase() == 'directing'
            );

            if (isDirectorOnShow && details['seasons'] != null) {
              final seasons = details['seasons'] as List;
              for (final season in seasons) {
                final seasonNum = season['season_number'] as int? ?? 0;
                if (seasonNum == 0) continue; // Skip specials usually
                
                debugPrint('[ContributorLogic] Fetching season $seasonNum for show ${show.title}');
                try {
                  final seasonDetails = await _tmdbService.getTvSeasonDetails(show.tmdbId, seasonNum);
                  final seasonEpisodes = seasonDetails['episodes'] as List? ?? [];
                  
                  for (final epData in seasonEpisodes) {
                    if (!episodesToProcess.any((e) => e['id'] == epData['id'])) {
                      final epCrew = epData['crew'] as List? ?? [];
                      final didDirectThisEpisode = epCrew.any((c) => 
                        (c['id'] == contributor.tmdbId || c['name'] == contributor.name) &&
                        (c['job']?.toString().toLowerCase() == 'director')
                      );
                      
                      if (didDirectThisEpisode) {
                        episodesToProcess.add(Map<String, dynamic>.from(epData));
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('[ContributorLogic] Error fetching season $seasonNum: $e');
                }
              }
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
            allWorks.add(Work(
                tmdbId: epId,
                title: '${show.title} - S${ep['season_number'].toString().padLeft(2, '0')}E${ep['episode_number'].toString().padLeft(2, '0')} - ${ep['name']}',
                posterPath: ep['still_path'] ?? show.posterPath,
                releaseDate: airDate, // This line was intended to be 'releaseDate: airDate,'
                type: WorkType.tvEpisode,
                tmdbRating: (ep['vote_average'] as num?)?.toDouble(),
                popularity: show.popularity,
                contributorRoles: isDirectorOnShow ? [ContributorRole(
                  contributorId: contributor.tmdbId,
                  contributorName: contributor.name,
                  role: 'Director',
                  department: 'Directing',
                )] : show.contributorRoles,
                imdbId: show.imdbId,
                seasonNumber: ep['season_number'],
                episodeNumber: ep['episode_number'],
              ));
            }
          } catch (e) {
            debugPrint('[ContributorLogic] Error fetching episodes for show ${show.title}: $e');
          }
        }

        // Re-sort everything after adding episodes and filter out duplicates
        final allWorksEnriched = List<Work>.from(allWorks);
        debugPrint('[ContributorLogic] Enrichment: allWorksEnriched count = ${allWorksEnriched.length}');
        
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

        final upcomingEnriched = filteredWorks.where((w) {
          if (w.type == WorkType.tvShow && showsWithEpisodes.contains(w.title)) return false;
          return w.releaseDate != null && w.releaseDate!.isAfter(now);
        }).toList();

        final pastEnriched = filteredWorks.where((w) {
          if (w.type == WorkType.tvShow && showsWithEpisodes.contains(w.title)) return false;
          return w.releaseDate != null && !w.releaseDate!.isAfter(now);
        }).toList();
        
        sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(upcomingEnriched);
        sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(pastEnriched);
        
        // For hits: Get top 100 hits. Sort by date for display.
        // For hits: Get top 100 hits. Sort by date for display.
        // Must exclude upcoming works from hits and creator shows fallback
        final nonUpcomingFilteredWorks = filteredWorks.where((w) {
          return !sortedUpcoming.any((u) => u.tmdbId == w.tmdbId && u.type == w.type);
        }).toList();

        final topHits = WorkSortingLogic.rankBiggestHits(nonUpcomingFilteredWorks);
        // Ensure ALL creator shows are in the pool if they weren't matched as hits (fallback)
        final creatorShows = nonUpcomingFilteredWorks.where((w) {
          return w.type == WorkType.tvShow && w.contributorRoles.any((r) => 
            r.role.toLowerCase() == 'creator' || r.department?.toLowerCase() == 'creator'
          );
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

        // Update upcomingEnriched and pastEnriched logic to be as robust as the initial one
        final upcomingPoolStatuses = {'planned', 'in production', 'post production', 'rumored'};
        final finalUpcoming = filteredWorks.where((w) {
          final status = w.status?.toLowerCase() ?? '';
          if (upcomingPoolStatuses.contains(status)) return true;
          if (w.releaseDate == null && w.type != WorkType.tvEpisode) return true;
          return w.releaseDate != null && w.releaseDate!.isAfter(now);
        }).toList();
        
        final finalPast = filteredWorks.where((w) {
          final status = w.status?.toLowerCase() ?? '';
          if (upcomingPoolStatuses.contains(status)) return false;
          if (w.releaseDate == null) return false;
          return !w.releaseDate!.isAfter(now);
        }).toList();

        sortedUpcoming = WorkSortingLogic.sortUpcomingWorksChronologically(finalUpcoming);
        sortedLatest = WorkSortingLogic.sortLatestReleasesReverseChronologically(finalPast);
        
        debugPrint('[DEBUG] Enrichment Complete for ${contributor.name}: upcoming=${finalUpcoming.length}, past=${finalPast.length}');
        for (var w in finalUpcoming) {
          if (w.title.toLowerCase().contains('far cry')) {
            debugPrint('[DEBUG] Enrichment: "Far Cry" correctly placed in UPCOMING. Status: ${w.status}, Date: ${w.releaseDate}');
          }
        }
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
}
