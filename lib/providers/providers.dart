import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/contributor.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/tv_cache_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/tmdb_service.dart';
import '../logic/contributor_logic.dart';
import '../logic/latest_work_logic.dart';
import '../logic/release_checker.dart';
import '../logic/search_logic.dart';
import '../data/services/notification_service.dart';
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

// --- Services ---

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
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
  );
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

// --- UI State ---
final selectedTabProvider = StateProvider<int>((ref) => 0);