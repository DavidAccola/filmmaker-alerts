import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/movie_detail.dart';
import '../data/models/tv_detail.dart';
import '../data/models/watchlist_entry.dart';
import '../data/models/episode_status_entry.dart';
import '../data/models/season_status_entry.dart';
import '../data/models/movie_status_entry.dart';
import '../data/models/collection_order.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/contributor_detail_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/movie_detail_repository.dart';
import '../data/repositories/tv_cache_repository.dart';
import '../data/repositories/tv_detail_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/streaming_repository.dart';
import '../data/repositories/watchlist_repository.dart';
import '../data/repositories/episode_status_repository.dart';
import '../data/repositories/season_status_repository.dart';
import '../data/repositories/movie_status_repository.dart';
import '../data/repositories/collection_order_repository.dart';
import '../data/services/tmdb_service.dart';
import '../data/services/justwatch_service.dart';
import '../data/services/streaming_service.dart';
import '../logic/contributor_logic.dart';
import '../logic/latest_work_logic.dart';
import '../logic/release_checker.dart';
import '../logic/search_logic.dart';
import '../logic/work_sorting_logic.dart';
import '../logic/tv_show_display_logic.dart';
import '../logic/multiple_role_display_logic.dart';
import '../logic/work_logic.dart';
import '../logic/watchlist_logic.dart';
import '../logic/watchlist_migration_logic.dart';
import '../data/services/notification_service.dart';
import '../data/services/system_tray_service.dart';
import '../data/models/preferences.dart';
import 'package:hive/hive.dart';
import '../core/constants.dart';

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

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  final box = Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox);
  return WatchlistRepository(box);
});

final episodeStatusRepositoryProvider = Provider<EpisodeStatusRepository>((ref) {
  final box = Hive.box<EpisodeStatusEntry>(AppConstants.episodeStatusesBox);
  return EpisodeStatusRepository(box);
});

final seasonStatusRepositoryProvider = Provider<SeasonStatusRepository>((ref) {
  final box = Hive.box<SeasonStatusEntry>(AppConstants.seasonStatusesBox);
  return SeasonStatusRepository(box);
});

final movieStatusRepositoryProvider = Provider<MovieStatusRepository>((ref) {
  final box = Hive.box<MovieStatusEntry>(AppConstants.movieStatusesBox);
  return MovieStatusRepository(box);
});

final collectionOrderRepositoryProvider = Provider<CollectionOrderRepository>((ref) {
  final box = Hive.box<CollectionOrder>(AppConstants.collectionOrdersBox);
  return CollectionOrderRepository(box);
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

final streamingServiceProvider = Provider.autoDispose<StreamingService>((ref) {
  return StreamingService(ref.watch(tmdbServiceProvider));
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
    ref.watch(streamingServiceProvider),
    ref.watch(movieDetailRepositoryProvider),
    ref.watch(tvDetailRepositoryProvider),
    ref.watch(contributorRepositoryProvider),
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
    ref.watch(watchlistRepositoryProvider),
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

final watchlistLogicProvider = Provider<WatchlistLogic>((ref) {
  return WatchlistLogic(
    ref.watch(watchlistRepositoryProvider),
    ref.watch(episodeStatusRepositoryProvider),
    ref.watch(seasonStatusRepositoryProvider),
    ref.watch(preferencesRepositoryProvider),
  );
});

final watchlistMigrationLogicProvider = Provider<WatchlistMigrationLogic>((ref) {
  return WatchlistMigrationLogic(
    ref.watch(contributorRepositoryProvider),
    ref.watch(watchlistLogicProvider),
  );
});

// --- Data Streams (For UI) ---

/// Contributors provider - fetches followed contributors list
/// UI invalidates this provider when contributors are added/removed
final contributorsProvider = FutureProvider<List<Contributor>>((ref) async {
  final repo = ref.watch(contributorRepositoryProvider);
  return repo.getContributors();
});

/// Provider that listens for contributor changes and updates watchlist snapshots
final contributorSnapshotUpdaterProvider = Provider<void>((ref) {
  // Listen to contributor changes
  ref.listen<AsyncValue<List<Contributor>>>(contributorsProvider, (previous, next) {
    next.whenData((contributors) async {
      // Update all watchlist entry snapshots when contributors change
      final watchlistLogic = ref.read(watchlistLogicProvider);
      await watchlistLogic.updateAllContributorSnapshots(contributors);
    });
  });
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
  final prefs = ref.watch(preferencesRepositoryProvider).getPreferences();
  final regionCode = prefs.streamingCountry ?? 'US';
  
  // Check if cached and fresh
  if (repo.isCached(movieId)) {
    final cached = repo.getMovieDetail(movieId);
    // If cached but missing streaming options, re-fetch to get them
    if (cached != null && cached.streamingOptions.isNotEmpty) {
      return cached;
    }
  }
  
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheMovieDetail(movieId, regionCode: regionCode);
});

/// TV show detail provider
final tvShowDetailProvider = FutureProvider.autoDispose.family<TvShowDetail?, int>((ref, showId) async {
  final repo = ref.watch(tvDetailRepositoryProvider);
  final prefs = ref.watch(preferencesRepositoryProvider).getPreferences();
  final regionCode = prefs.streamingCountry ?? 'US';
  
  if (repo.isShowCached(showId)) {
    final cached = repo.getTvShowDetail(showId);
    // If cached but missing streaming options, re-fetch to get them
    if (cached != null && cached.streamingOptions.isNotEmpty) {
      return cached;
    }
  }
  final logic = ref.read(workLogicProvider);
  return await logic.fetchAndCacheTvShowDetail(showId, regionCode: regionCode);
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

/// Notifier for main navigation tab state (0 = Home, 1 = History, 2 = Settings)
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// Notifier for home screen tab state (0 = People, 1 = Watchlist)
class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// Notifier for watchlist scroll target - TMDB ID of item to scroll to, or null
class WatchlistScrollTargetNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setTarget(int? tmdbId) {
    state = tmdbId;
  }

  void clear() {
    state = null;
  }
}

/// Notifier for FAB raised state - controls whether FAB should be raised for snackbars
class FabRaisedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRaised(bool raised) {
    state = raised;
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);

/// Home screen tab state (0 = People, 1 = Watchlist)
/// This is managed at the provider level to persist across screen resizes
final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

/// Scroll target for watchlist - set this to scroll to a specific item
final watchlistScrollTargetProvider = NotifierProvider<WatchlistScrollTargetNotifier, int?>(WatchlistScrollTargetNotifier.new);

/// FAB visibility state - controls whether the FAB should be raised for snackbars
final fabRaisedProvider = NotifierProvider<FabRaisedNotifier, bool>(FabRaisedNotifier.new);

/// Rank edit mode state - when true, watchlist shows drag-to-reorder interface
final rankEditModeProvider = NotifierProvider<RankEditModeNotifier, bool>(RankEditModeNotifier.new);

class RankEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  
  void setEditMode(bool editing) => state = editing;
  void toggle() => state = !state;
}

// --- Watchlist Providers ---

/// Watchlist entries provider - fetches all watchlist entries
final watchlistEntriesProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.getWatchlistWorks();
});

/// Watchlist movies provider - fetches only movies
final watchlistMoviesProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.getWorksByType(WorkType.movie);
});

/// Watchlist shows provider - fetches only TV shows
final watchlistShowsProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.getWorksByType(WorkType.tvShow);
});

/// Check if a work is in the watchlist
typedef WorkParams = ({int tmdbId, WorkType type});

final isWorkInWatchlistProvider = FutureProvider.family<bool, WorkParams>((ref, params) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.isWorkInWatchlist(params.tmdbId, params.type);
});