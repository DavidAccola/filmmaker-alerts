import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/movie_detail.dart';
import '../data/models/tv_detail.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/contributor_detail_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/movie_detail_repository.dart';
import '../data/repositories/tv_cache_repository.dart';
import '../data/repositories/tv_detail_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/streaming_repository.dart';
import '../data/services/tmdb_service.dart';
import '../data/services/justwatch_service.dart';
import '../logic/contributor_logic.dart';
import '../logic/latest_work_logic.dart';
import '../logic/release_checker.dart';
import '../logic/search_logic.dart';
import '../logic/work_sorting_logic.dart';
import '../logic/tv_show_display_logic.dart';
import '../logic/multiple_role_display_logic.dart';
import '../logic/work_logic.dart';
import '../data/services/notification_service.dart';
import '../data/services/system_tray_service.dart';
import '../data/models/preferences.dart';

// --- Repositories ---

final contributorRepositoryProvider = Provider<ContributorRepository>((ref) {
  return ContributorRepository();
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

final movieCacheRepositoryProvider = Provider<MovieCacheRepository>((ref) {
  return MovieCacheRepository();
});

final tvCacheRepositoryProvider = Provider<TvCacheRepository>((ref) {
  return TvCacheRepository();
});

final streamingRepositoryProvider = Provider<StreamingRepository>((ref) {
  return StreamingRepository();
});

final contributorDetailRepositoryProvider = Provider<ContributorDetailRepository>((ref) {
  return ContributorDetailRepository();
});

final movieDetailRepositoryProvider = Provider<MovieDetailRepository>((ref) {
  return MovieDetailRepository();
});

final tvDetailRepositoryProvider = Provider<TvDetailRepository>((ref) {
  return TvDetailRepository();
});

// --- Services ---

final tmdbServiceProvider = Provider.autoDispose<TmdbService>((ref) {
  final service = TmdbService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final notificationServiceProvider = Provider.autoDispose<NotificationService>((ref) {
  return NotificationService();
});

final systemTrayServiceProvider = Provider.autoDispose<SystemTrayService>((ref) {
  return SystemTrayService();
});

final justWatchServiceProvider = Provider.autoDispose<JustWatchService>((ref) {
  return JustWatchService();
});

// --- Logic ---

final searchLogicProvider = Provider<SearchLogic>((ref) {
  final tmdb = ref.watch(tmdbServiceProvider);
  return SearchLogic(tmdb);
});

final latestWorkLogicProvider = Provider<LatestWorkLogic>((ref) {
  final tmdb = ref.watch(tmdbServiceProvider);
  return LatestWorkLogic(tmdb);
});

final contributorLogicProvider = Provider<ContributorLogic>((ref) {
  return ContributorLogic(
    ref.watch(contributorRepositoryProvider),
    ref.watch(tmdbServiceProvider),
    ref.watch(latestWorkLogicProvider),
    ref.watch(preferencesRepositoryProvider),
    contributorDetailRepository: ref.watch(contributorDetailRepositoryProvider),
  );
});

final workLogicProvider = Provider<WorkLogic>((ref) {
  return WorkLogic(
    ref.watch(tmdbServiceProvider),
    ref.watch(justWatchServiceProvider),
    ref.watch(movieDetailRepositoryProvider),
    ref.watch(tvDetailRepositoryProvider),
  );
});

final releaseCheckerProvider = Provider<ReleaseChecker>((ref) {
  return ReleaseChecker(
    ref.watch(tmdbServiceProvider),
    ref.watch(contributorRepositoryProvider),
    ref.watch(preferencesRepositoryProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(movieCacheRepositoryProvider),
    ref.watch(tvCacheRepositoryProvider),
    contributorDetailRepository: ref.watch(contributorDetailRepositoryProvider),
  );
});

final workSortingLogicProvider = Provider<WorkSortingLogic>((ref) {
  return WorkSortingLogic();
});

final tvShowDisplayLogicProvider = Provider<TvShowDisplayLogic>((ref) {
  return TvShowDisplayLogic();
});

final multipleRoleDisplayLogicProvider = Provider<MultipleRoleDisplayLogic>((ref) {
  return MultipleRoleDisplayLogic();
});

// --- Data Streams (For UI) ---

/// Contributors provider - fetches followed contributors list
/// UI invalidates this provider when contributors are added/removed
final contributorsProvider = FutureProvider<List<Contributor>>((ref) async {
  final repo = ref.watch(contributorRepositoryProvider);
  return repo.getContributors();
});

final preferencesProvider = FutureProvider<Preferences>((ref) async {
  final repo = ref.watch(preferencesRepositoryProvider);
  final prefs = repo.getPreferences();
  debugPrint('[PreferencesProvider] Loaded preferences with notifyTV: ${prefs.notifyTV}');
  return prefs;
});

final historyProvider = FutureProvider<List<EnrichedHistoryEntry>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  return repo.getHistory();
});

/// Contributor detail provider - fetches detailed info for a specific contributor
final contributorDetailProvider = FutureProvider.autoDispose.family<ContributorDetail?, int>((ref, tmdbId) async {
  final repo = ref.watch(contributorDetailRepositoryProvider);
  
  // Check if cached and fresh
  if (repo.isCached(tmdbId)) {
    return repo.getContributorDetail(tmdbId);
  }
  
  // Fetch from TMDB and cache on demand
  final contributorRepo = ref.read(contributorRepositoryProvider);
  final contributor = contributorRepo.getContributor(tmdbId);
  if (contributor == null) return null;

  final tmdb = ref.read(tmdbServiceProvider);
  final logic = ref.read(contributorLogicProvider);

  try {
    List<dynamic> credits = [];
    if (contributor.type == ContributorType.person) {
      final data = await tmdb.getPersonCombinedCredits(tmdbId);
      credits = [...(data['cast'] ?? []), ...(data['crew'] ?? [])];
    } else if (contributor.type == ContributorType.company) {
      final data = await tmdb.getCompanyTopWorks(tmdbId);
      credits = data['results'] ?? [];
    } else if (contributor.type == ContributorType.movie) {
      credits = [await tmdb.getMovieDetails(tmdbId)];
    } else if (contributor.type == ContributorType.tvShow) {
      final data = await tmdb.getTvDetails(tmdbId);
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
    
    await logic.updateContributorDetail(contributor, credits);
    return repo.getContributorDetail(tmdbId);
  } catch (e) {
    debugPrint('[ContributorDetailProvider] Error fetching details on demand: $e');
    return null;
  }
});

final movieDetailProvider = FutureProvider.autoDispose.family<MovieDetail?, int>((ref, movieId) async {
  final repo = ref.watch(movieDetailRepositoryProvider);
  
  // Check if cached and fresh
  if (repo.isCached(movieId)) {
    return repo.getMovieDetail(movieId);
  }
  
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheMovieDetail(movieId);
});

/// TV show detail provider
final tvShowDetailProvider = FutureProvider.autoDispose.family<TvShowDetail?, int>((ref, showId) async {
  final repo = ref.watch(tvDetailRepositoryProvider);
  if (repo.isShowCached(showId)) {
    return repo.getTvShowDetail(showId);
  }
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheTvShowDetail(showId);
});

typedef EpisodeParams = ({int showId, int seasonNumber, int episodeNumber});
typedef SeasonParams = ({int showId, int seasonNumber});

/// TV season detail provider
final tvSeasonDetailProvider = FutureProvider.autoDispose.family<TvSeasonDetail?, SeasonParams>((ref, params) async {
  final repo = ref.watch(tvDetailRepositoryProvider);
  if (repo.isSeasonCached(params.showId, params.seasonNumber)) {
    return repo.getTvSeasonDetail(params.showId, params.seasonNumber);
  }
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheTvSeasonDetail(
    showId: params.showId,
    seasonNumber: params.seasonNumber,
  );
});

/// TV episode detail provider
final tvEpisodeDetailProvider = FutureProvider.autoDispose.family<TvEpisodeDetail?, EpisodeParams>((ref, params) async {
  final repo = ref.watch(tvDetailRepositoryProvider);
  
  // We don't have a direct "isCached" for episodes by show/season/ep in the repo yet, 
  // but we can check if the episode's TMDB ID (if we had it) is cached.
  // For now, let's just fetch if we don't have the show's episode cached.
  // Actually, let's just use the fetcher which handles caching.
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheTvEpisodeDetail(
    showId: params.showId,
    seasonNumber: params.seasonNumber,
    episodeNumber: params.episodeNumber,
  );
});

// --- UI State ---
final selectedTabProvider = StateProvider<int>((ref) => 0);