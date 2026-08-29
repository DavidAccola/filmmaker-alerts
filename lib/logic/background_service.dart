import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';
import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/episode_status_entry.dart';
import '../data/models/movie_cache_entry.dart';
import '../data/models/movie_status_entry.dart';
import '../data/models/notification_history.dart';
import '../data/models/preferences.dart';
import '../data/models/season_status_entry.dart';
import '../data/models/status_record.dart';
import '../data/models/tv_cache.dart';
import '../data/models/watchlist_entry.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/tv_cache_repository.dart';
import '../data/repositories/watchlist_repository.dart';
import '../data/services/notification_service.dart';
import '../data/services/tmdb_service.dart';
import 'release_checker.dart';
import 'notification_logic.dart';

const String taskName = 'checkNewReleases';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Init Environment
      await dotenv.load(fileName: ".env");
      // 2. Init Hive (Separate Isolate)
      await Hive.initFlutter();
      Hive.registerAdapter(ContributorAdapter());
      Hive.registerAdapter(ContributorTypeAdapter());
      Hive.registerAdapter(TvNotificationPreferencesAdapter());
      Hive.registerAdapter(LatestWorkAdapter());
      Hive.registerAdapter(PreferencesAdapter());
      Hive.registerAdapter(NotificationHistoryEntryAdapter());
      Hive.registerAdapter(NotificationReasonAdapter());
      Hive.registerAdapter(NotificationEventAdapter());
      Hive.registerAdapter(MovieCacheEntryAdapter());
      Hive.registerAdapter(TvShowCacheEntryAdapter());
      Hive.registerAdapter(TvEpisodeCacheEntryAdapter());
      // Watchlist and status adapters
      Hive.registerAdapter(WatchlistEntryAdapter());
      Hive.registerAdapter(ContributorSnapshotAdapter());
      Hive.registerAdapter(ReleaseNotificationPreferencesAdapter());
      Hive.registerAdapter(StatusRecordAdapter());
      Hive.registerAdapter(WatchStatusAdapter());
      Hive.registerAdapter(WorkTypeAdapter());
      Hive.registerAdapter(ReleaseTypeAdapter());
      Hive.registerAdapter(EpisodeStatusEntryAdapter());
      Hive.registerAdapter(SeasonStatusEntryAdapter());
      Hive.registerAdapter(MovieStatusEntryAdapter());

      await Hive.openBox<Contributor>(AppConstants.contributorsBox);
      await Hive.openBox<Preferences>(AppConstants.preferencesBox);
      await Hive.openBox<NotificationHistoryEntry>(AppConstants.historyBox);
      await Hive.openBox<MovieCacheEntry>(AppConstants.movieCacheBox);
      await Hive.openBox<WatchlistEntry>(AppConstants.watchlistEntriesBox);
      await Hive.openBox<EpisodeStatusEntry>(AppConstants.episodeStatusesBox);
      await Hive.openBox<SeasonStatusEntry>(AppConstants.seasonStatusesBox);
      await Hive.openBox<MovieStatusEntry>(AppConstants.movieStatusesBox);

      // 3. Setup Dependencies (Manual DI)
      final tmdbService = TmdbService();
      final contributorRepo = ContributorRepository();
      final prefsRepo = PreferencesRepository();
      final historyRepo = HistoryRepository();
      final movieCacheRepo = MovieCacheRepository();
      final tvCacheRepo = TvCacheRepository();
      await tvCacheRepo.init(); // Initialize TV cache boxes
      final watchlistRepo = WatchlistRepository(Hive.box<WatchlistEntry>(AppConstants.watchlistEntriesBox));
      final notificationService = NotificationService();
      await notificationService.init();

      final processor = BackgroundTaskProcessor(
        tmdbService: tmdbService,
        contributorRepo: contributorRepo,
        prefsRepo: prefsRepo,
        historyRepo: historyRepo,
        movieCacheRepo: movieCacheRepo,
        notificationService: notificationService,
        tvCacheRepo: tvCacheRepo,
        watchlistRepo: watchlistRepo,
      );

      return await processor.process();
    } catch (e, stack) {
      // Log in debug so crashes are visible during development.
      // In production this is silent — add a crash reporter (e.g. Sentry)
      // here when one is available.
      assert(() {
        debugPrint('[Background] Task failed: $e\n$stack');
        return true;
      }());
      return Future.value(false);
    }
  });
}

class BackgroundTaskProcessor {
  final TmdbService tmdbService;
  final ContributorRepository contributorRepo;
  final PreferencesRepository prefsRepo;
  final HistoryRepository historyRepo;
  final MovieCacheRepository movieCacheRepo;
  final NotificationService notificationService;
  final TvCacheRepository? tvCacheRepo;
  final WatchlistRepository watchlistRepo;

  BackgroundTaskProcessor({
    required this.tmdbService,
    required this.contributorRepo,
    required this.prefsRepo,
    required this.historyRepo,
    required this.movieCacheRepo,
    required this.notificationService,
    this.tvCacheRepo,
    required this.watchlistRepo,
  });

  Future<bool> process() async {
    final tvCacheRepoInstance = tvCacheRepo ?? TvCacheRepository();
    if (tvCacheRepo == null) {
      await tvCacheRepoInstance.init();
    }
    
    try {
      final currentPrefs = prefsRepo.getPreferences();
      
      // Check if we should run based on scheduled time
      if (!_shouldRunCheck(currentPrefs)) {
        return true;
      }
      
      final releaseChecker = ReleaseChecker(
        tmdbService,
        contributorRepo,
        prefsRepo,
        historyRepo,
        movieCacheRepo,
        tvCacheRepoInstance,
        watchlistRepo,
      );

      // 4. Run Check (ignore debug date for scheduled checks)
      final newReleases = await releaseChecker.findNewReleases(ignoreDebugDate: true);

      // 5. Update last check time (regardless of whether we found releases)
      final updatedPrefs = currentPrefs.copyWithLastCheckTime(
        DateTime.now().toIso8601String(),
      );
      await prefsRepo.savePreferences(updatedPrefs);

      if (newReleases.isEmpty) {
        return true;
      }

      // 5. Process Notifications & Side Effects
      final movieTitles = <String>[];

      for (final release in newReleases) {
        // A. Update History
        await historyRepo.addNotificationToHistory(release);

        // B. Get title from cache for notification text
        String? title;
        if (release.mediaType == 'tv') {
          title = tvCacheRepoInstance.getShow(release.tmdbId)?.name;
        } else {
          title = movieCacheRepo.getMovie(release.tmdbId)?.title;
        }
        if (title != null) movieTitles.add(title);

        // C. Update Latest Work for Contributors (only for movies, not TV shows)
        if (release.mediaType != 'tv') {
          final movie = movieCacheRepo.getMovie(release.tmdbId);
          for (final reason in release.reasons) {
            final contributor = contributorRepo.getContributor(reason.contributorId);
            if (contributor != null && movie != null) {
              final releaseDate = movie.releaseDate;
              final releaseYear = releaseDate != null && releaseDate.contains('-') 
                  ? releaseDate.split('-').first 
                  : 'Unknown';

              final newLatestWork = LatestWork(
                title: movie.title,
                releaseYear: releaseYear,
                releaseDate: releaseDate ?? 'Unknown',
                department: reason.department,
                job: reason.job,
                posterPath: movie.posterPath,
              );
              
              final updatedContributor = Contributor(
                tmdbId: contributor.tmdbId,
                name: contributor.name,
                type: contributor.type,
                profilePath: contributor.profilePath,
                notifyForDepartments: contributor.notifyForDepartments,
                availableDepartments: contributor.availableDepartments,
                knownFor: contributor.knownFor,
                latestWork: newLatestWork,
                followedAt: contributor.followedAt,
                allRolesSelected: contributor.allRolesSelected,
                isHidden: contributor.isHidden,
              );
              await contributorRepo.updateContributor(updatedContributor);
            }
          }
        }
      }

      // 6. Send Notification
      if (movieTitles.isNotEmpty) {
        final title = NotificationLogic.formatTitle(movieTitles, entries: newReleases);
        final body = NotificationLogic.formatBody(movieTitles, newReleases,
          getMoviePosterPath: (tmdbId) {
            final release = newReleases.firstWhere((r) => r.tmdbId == tmdbId, orElse: () => newReleases.first);
            if (release.mediaType == 'tv') {
              final tvShow = tvCacheRepoInstance.getShow(tmdbId);
              return tvShow?.posterPath;
            } else {
              return movieCacheRepo.getMovie(tmdbId)?.posterPath;
            }
          });

        // Single release: open TMDB page. Multiple: open History tab.
        String? payload;
        if (newReleases.length == 1) {
          final entry = newReleases.first;
          final isTV = entry.mediaType == 'tv' || entry.notificationEvents.any((e) => e.releaseType.toLowerCase() == 'tv');
          final typePath = isTV ? 'tv' : 'movie';
          payload = 'https://www.themoviedb.org/$typePath/${entry.tmdbId}';
        } else {
          payload = 'app://history';
        }

        // Collect up to 4 poster URLs for the notification image grid.
        final List<String> imagePaths = [];
        for (int i = 0; i < newReleases.length && i < 4; i++) {
          final release = newReleases[i];
          String? posterPath;
          if (release.mediaType == 'tv') {
            final tvShow = tvCacheRepoInstance.getShow(release.tmdbId);
            if (tvShow?.posterPath != null && tvShow!.posterPath!.isNotEmpty) {
              posterPath = tvShow.posterPath;
            }
            // TODO: Use season-specific poster when available
          } else {
            posterPath = movieCacheRepo.getMovie(release.tmdbId)?.posterPath;
          }
          if (posterPath != null && posterPath.isNotEmpty) {
            imagePaths.add('https://image.tmdb.org/t/p/w200$posterPath');
          }
        }

        // Release dates for multi-release notifications.
        // Windows uses the first 4 entries (poster grid); Android InboxStyle uses all.
        List<String>? releaseDates;
        if (newReleases.length >= 2) {
          releaseDates = NotificationLogic.getPriorityReleaseDates(movieTitles, newReleases);
        }

        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: payload,
          imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
          releaseDates: releaseDates,
          totalMovieCount: newReleases.length,
        );
      }

      return true;
    } finally {
      // Cleanup resources
      tmdbService.dispose();
      notificationService.dispose();
    }
  }

  /// Check if the scheduled time has passed since the last check
  /// This enables "catch-up" behavior when the app starts after the scheduled time
  bool _shouldRunCheck(Preferences prefs) {
    final now = DateTime.now();
    
    // Parse scheduled time (format: "HH:MM")
    int scheduleHour = 9;
    int scheduleMinute = 0;
    try {
      final parts = prefs.scheduleTime.split(':');
      if (parts.length == 2) {
        scheduleHour = int.parse(parts[0]);
        scheduleMinute = int.parse(parts[1]);
      }
    } catch (e) {
      return true; // Default to running if we can't parse
    }

    // Get today's scheduled time
    final todayScheduled = DateTime(now.year, now.month, now.day, scheduleHour, scheduleMinute);
    
    // If we haven't reached today's scheduled time yet, don't run
    if (now.isBefore(todayScheduled)) {
      return false;
    }

    // If we have a last check time, verify it was before today's scheduled time
    if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty) {
      try {
        final lastCheck = DateTime.parse(prefs.lastCheckTime!);
        
        // If last check was after today's scheduled time, we already ran today
        if (lastCheck.isAfter(todayScheduled)) {
          return false;
        }
        
        return true;
      } catch (e) {
        return true; // Default to running if we can't parse
      }
    }

    // No last check time, so we should run
    return true;
  }
}