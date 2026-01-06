import 'package:flutter/foundation.dart';
import '../data/models/contributor.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/tmdb_service.dart';
import 'latest_work_logic.dart';
import '../core/tmdb_mapping.dart';

class ContributorLogic {
  final ContributorRepository _contributorRepository;
  final TmdbService _tmdbService;
  final LatestWorkLogic _latestWorkLogic;
  final PreferencesRepository _preferencesRepository;

  ContributorLogic(
    this._contributorRepository,
    this._tmdbService,
    this._latestWorkLogic,
    this._preferencesRepository,
  );

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
}
