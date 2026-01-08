import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';
import '../data/models/contributor.dart';
import '../data/models/movie_cache_entry.dart';
import '../data/models/notification_history.dart';
import '../data/models/preferences.dart';
import '../data/models/tv_cache.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/tv_cache_repository.dart';
import '../data/services/notification_service.dart';
import '../data/services/tmdb_service.dart';
import 'release_checker.dart';
import 'notification_logic.dart';
import '../utils/debug_logger.dart';

const String taskName = 'checkNewReleases';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('[BackgroundService] Starting background task: $task');

      // 1. Init Environment
      await dotenv.load(fileName: ".env");

      // 2. Init Hive (Separate Isolate)
      await Hive.initFlutter();
      Hive.registerAdapter(ContributorAdapter());
      Hive.registerAdapter(ContributorTypeAdapter());
      Hive.registerAdapter(LatestWorkAdapter());
      Hive.registerAdapter(PreferencesAdapter());
      Hive.registerAdapter(NotificationHistoryEntryAdapter());
      Hive.registerAdapter(NotificationReasonAdapter());
      Hive.registerAdapter(NotificationEventAdapter());
      Hive.registerAdapter(MovieCacheEntryAdapter());
      Hive.registerAdapter(TvShowCacheEntryAdapter());
      Hive.registerAdapter(TvEpisodeCacheEntryAdapter());

      await Hive.openBox<Contributor>(AppConstants.contributorsBox);
      await Hive.openBox<Preferences>(AppConstants.preferencesBox);
      await Hive.openBox<NotificationHistoryEntry>(AppConstants.historyBox);
      await Hive.openBox<MovieCacheEntry>(AppConstants.movieCacheBox);

      // 3. Setup Dependencies (Manual DI)
      final tmdbService = TmdbService();
      final contributorRepo = ContributorRepository();
      final prefsRepo = PreferencesRepository();
      final historyRepo = HistoryRepository();
      final movieCacheRepo = MovieCacheRepository();
      final tvCacheRepo = TvCacheRepository();
      await tvCacheRepo.init(); // Initialize TV cache boxes
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
      );

      return await processor.process();
    } catch (e) {
      debugPrint('[BackgroundService] Task failed: $e');
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

  BackgroundTaskProcessor({
    required this.tmdbService,
    required this.contributorRepo,
    required this.prefsRepo,
    required this.historyRepo,
    required this.movieCacheRepo,
    required this.notificationService,
    this.tvCacheRepo,
  });

  Future<bool> process() async {
    final tvCacheRepoInstance = tvCacheRepo ?? TvCacheRepository();
    if (tvCacheRepo == null) {
      await tvCacheRepoInstance.init();
    }
    
    final releaseChecker = ReleaseChecker(
      tmdbService,
      contributorRepo,
      prefsRepo,
      historyRepo,
      movieCacheRepo,
      tvCacheRepoInstance,
    );

    // 4. Run Check
    final newReleases = await releaseChecker.findNewReleases();

    // 5. Update last check time (regardless of whether we found releases)
    final currentPrefs = prefsRepo.getPreferences();
    final updatedPrefs = Preferences(
      notifyTheatre: currentPrefs.notifyTheatre,
      notifyStreaming: currentPrefs.notifyStreaming,
      scheduleTime: currentPrefs.scheduleTime,
      defaultDepartments: currentPrefs.defaultDepartments,
      notifyPhysical: currentPrefs.notifyPhysical,
      notifyTV: currentPrefs.notifyTV,
      pretendToday: currentPrefs.pretendToday,
      includeCollectionsInMovieSearch: currentPrefs.includeCollectionsInMovieSearch,
      useGridView: currentPrefs.useGridView,
      homeSortOrder: currentPrefs.homeSortOrder,
      groupByType: currentPrefs.groupByType,
      allRolesSelected: currentPrefs.allRolesSelected,
      allReleaseTypesSelected: currentPrefs.allReleaseTypesSelected,
      autoFollowNewRoles: currentPrefs.autoFollowNewRoles,
      lastCheckTime: DateTime.now().toIso8601String(),
      lastViewedHistoryTime: currentPrefs.lastViewedHistoryTime, // MISSING!
      movieDetailsPreference: currentPrefs.movieDetailsPreference, // MISSING!
      defaultTvNotificationPrefs: currentPrefs.defaultTvNotificationPrefs, // MISSING!
      notifyPersonTvEpisodes: currentPrefs.notifyPersonTvEpisodes, // MISSING!
    );
    await prefsRepo.savePreferences(updatedPrefs);

    if (newReleases.isEmpty) {
      debugPrint('[BackgroundService] No new releases found.');
      return true;
    }

    debugPrint('[BackgroundService] Found ${newReleases.length} new releases.');

    // 5. Process Notifications & Side Effects
    final movieTitles = <String>[];

    for (final release in newReleases) {
      // A. Update History
      DebugLogger.instance.logBackground('Adding notification to history: tmdbId=${release.tmdbId}, mediaType=${release.mediaType}');
      DebugLogger.instance.logBackground('  seasonNumber=${release.seasonNumber}, episodeNumber=${release.episodeNumber}');
      DebugLogger.instance.logBackground('  episodeTitle="${release.episodeTitle}", tvNotificationType=${release.tvNotificationType}');
      await historyRepo.addNotificationToHistory(release);
      DebugLogger.instance.logBackground('✅ Successfully added to history: tmdbId=${release.tmdbId}');

      // B. Get Movie/TV Show Details for Notification Text
      String? title;
      if (release.mediaType == 'tv') {
        // Get TV show title from TV cache
        final tvShow = tvCacheRepoInstance.getShow(release.tmdbId);
        title = tvShow?.name;
        DebugLogger.instance.logBackground('TV show lookup: tmdbId=${release.tmdbId}, found=${tvShow != null}, title="$title"');
      } else {
        // Get movie title from movie cache
        final movie = movieCacheRepo.getMovie(release.tmdbId);
        title = movie?.title;
        DebugLogger.instance.logBackground('Movie lookup: tmdbId=${release.tmdbId}, found=${movie != null}, title="$title"');
      }
      
      if (title != null) {
        movieTitles.add(title);
        DebugLogger.instance.logBackground('Added title to notification: "$title"');
      } else {
        DebugLogger.instance.logBackground('WARNING: No title found for ${release.mediaType} with tmdbId=${release.tmdbId}');
      }

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
            );
            await contributorRepo.updateContributor(updatedContributor);
          }
        }
      }
    }

    // 6. Send Notification
    if (movieTitles.isNotEmpty) {
      // Initialize logger
      await DebugLogger.instance.init();
      
      DebugLogger.instance.logBackground('=== NOTIFICATION DEBUG ===');
      DebugLogger.instance.logBackground('Movie titles: $movieTitles');
      DebugLogger.instance.logBackground('New releases count: ${newReleases.length}');
      
      for (int i = 0; i < newReleases.length; i++) {
        final release = newReleases[i];
        DebugLogger.instance.logBackground('Release $i:');
        DebugLogger.instance.logBackground('  tmdbId: ${release.tmdbId}');
        DebugLogger.instance.logBackground('  mediaType: ${release.mediaType}');
        DebugLogger.instance.logBackground('  tvNotificationType: ${release.tvNotificationType}');
        DebugLogger.instance.logBackground('  seasonNumber: ${release.seasonNumber}');
        DebugLogger.instance.logBackground('  episodeNumber: ${release.episodeNumber}');
        DebugLogger.instance.logBackground('  episodeTitle: "${release.episodeTitle}"');
        DebugLogger.instance.logBackground('  notificationEvents.length: ${release.notificationEvents.length}');
        for (int j = 0; j < release.notificationEvents.length; j++) {
          final event = release.notificationEvents[j];
          DebugLogger.instance.logBackground('  event[$j]: releaseType="${event.releaseType}", releaseDate="${event.releaseDate}"');
        }
      }
      
      final title = NotificationLogic.formatTitle(movieTitles, entries: newReleases);
      final body = NotificationLogic.formatBody(movieTitles, newReleases, 
        getMoviePosterPath: (tmdbId) {
          // Handle both movies and TV shows
          final release = newReleases.firstWhere((r) => r.tmdbId == tmdbId, orElse: () => newReleases.first);
          if (release.mediaType == 'tv') {
            final tvShow = tvCacheRepoInstance.getShow(tmdbId);
            return tvShow?.posterPath;
          } else {
            return movieCacheRepo.getMovie(tmdbId)?.posterPath;
          }
        });

      DebugLogger.instance.logBackground('Formatted title: "$title"');
      DebugLogger.instance.logBackground('Formatted body: "$body"');

      // Action Logic: Single Movie opens URL, Multiple opens History
      String? payload;
      if (newReleases.length == 1) {
        final entry = newReleases.first;
        final isTV = entry.mediaType == 'tv' || entry.notificationEvents.any((e) => e.releaseType.toLowerCase() == 'tv');
        final typePath = isTV ? 'tv' : 'movie';
        payload = 'https://www.themoviedb.org/$typePath/${entry.tmdbId}';
        DebugLogger.instance.logBackground('Single release payload: $payload (isTV: $isTV)');
      } else {
        payload = 'app://history';
        DebugLogger.instance.logBackground('Multiple releases payload: $payload');
      }

      // Image Logic: Collect up to 4 poster images from the releases
      List<String> imagePaths = [];
      for (int i = 0; i < newReleases.length && i < 4; i++) {
        final release = newReleases[i];
        String? posterPath;
        
        if (release.mediaType == 'tv') {
          // For TV shows, try to get season poster first, then series poster
          final tvShow = tvCacheRepoInstance.getShow(release.tmdbId);
          if (tvShow?.posterPath != null && tvShow!.posterPath!.isNotEmpty) {
            posterPath = tvShow.posterPath;
            DebugLogger.instance.logBackground('TV show poster found: ${tvShow.posterPath}');
          } else {
            DebugLogger.instance.logBackground('No TV show poster found for tmdbId=${release.tmdbId}');
          }
          // TODO: Add season-specific poster logic when available
        } else {
          // For movies, get movie poster
          final movie = movieCacheRepo.getMovie(release.tmdbId);
          posterPath = movie?.posterPath;
          DebugLogger.instance.logBackground('Movie poster: ${movie?.posterPath}');
        }
        
        if (posterPath != null && posterPath.isNotEmpty) {
          // Convert TMDB poster path to full URL
          imagePaths.add('https://image.tmdb.org/t/p/w200$posterPath');
        }
      }
      
      DebugLogger.instance.logBackground('Image paths: $imagePaths');

      // Get priority-based release dates for 2-3 movie notifications
      List<String>? releaseDates;
      if (newReleases.length >= 2 && newReleases.length <= 3) {
        releaseDates = NotificationLogic.getPriorityReleaseDates(movieTitles, newReleases);
        DebugLogger.instance.logBackground('Release dates: $releaseDates');
      }

      DebugLogger.instance.logBackground('About to call showNotification...');
      DebugLogger.instance.logBackground('  id: ${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
      DebugLogger.instance.logBackground('  title: "$title"');
      DebugLogger.instance.logBackground('  body: "$body"');
      DebugLogger.instance.logBackground('  payload: $payload');
      DebugLogger.instance.logBackground('  imagePaths: $imagePaths');
      DebugLogger.instance.logBackground('  releaseDates: $releaseDates');
      DebugLogger.instance.logBackground('  totalMovieCount: ${newReleases.length}');
      
      try {
        await notificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: payload,
          imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
          releaseDates: releaseDates,
          totalMovieCount: newReleases.length,
        );
        DebugLogger.instance.logBackground('✅ showNotification completed successfully');
      } catch (e, stackTrace) {
        DebugLogger.instance.logBackground('❌ showNotification failed: $e');
        DebugLogger.instance.logBackground('Stack trace: ${stackTrace.toString().substring(0, 500)}...');
        rethrow;
      }
    } else {
      DebugLogger.instance.logBackground('❌ No movie titles found - notification not sent');
      DebugLogger.instance.logBackground('New releases count: ${newReleases.length}');
      for (int i = 0; i < newReleases.length; i++) {
        final release = newReleases[i];
        DebugLogger.instance.logBackground('Release $i: tmdbId=${release.tmdbId}, mediaType=${release.mediaType}');
      }
    }

    return true;
  }
}