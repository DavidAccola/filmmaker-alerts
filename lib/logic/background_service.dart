import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';
import '../data/models/contributor.dart';
import '../data/models/movie_cache_entry.dart';
import '../data/models/notification_history.dart';
import '../data/models/preferences.dart';
import '../data/repositories/contributor_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/movie_cache_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/services/notification_service.dart';
import '../data/services/tmdb_service.dart';
import 'release_checker.dart';
import 'notification_logic.dart';

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
      final notificationService = NotificationService();
      await notificationService.init();

      final processor = BackgroundTaskProcessor(
        tmdbService: tmdbService,
        contributorRepo: contributorRepo,
        prefsRepo: prefsRepo,
        historyRepo: historyRepo,
        movieCacheRepo: movieCacheRepo,
        notificationService: notificationService,
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

  BackgroundTaskProcessor({
    required this.tmdbService,
    required this.contributorRepo,
    required this.prefsRepo,
    required this.historyRepo,
    required this.movieCacheRepo,
    required this.notificationService,
  });

  Future<bool> process() async {
    final releaseChecker = ReleaseChecker(
      tmdbService,
      contributorRepo,
      prefsRepo,
      historyRepo,
      movieCacheRepo,
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
      await historyRepo.addNotificationToHistory(release);

      // B. Get Movie Details for Notification Text
      final movie = movieCacheRepo.getMovie(release.tmdbId);
      if (movie != null) {
        movieTitles.add(movie.title);
      }

      // C. Update Latest Work for Contributors
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

    // 6. Send Notification
    if (movieTitles.isNotEmpty) {
      final title = NotificationLogic.formatTitle(movieTitles);
      final body = NotificationLogic.formatBody(movieTitles, newReleases, 
        getMoviePosterPath: (tmdbId) => movieCacheRepo.getMovie(tmdbId)?.posterPath);

      // Action Logic: Single Movie opens URL, Multiple opens History
      String? payload;
      if (newReleases.length == 1) {
        final entry = newReleases.first;
        final isTV = entry.notificationEvents.any((e) => e.releaseType == 'TV');
        final typePath = isTV ? 'tv' : 'movie';
        payload = 'https://www.themoviedb.org/$typePath/${entry.tmdbId}';
      } else {
        payload = 'app://history';
      }

      // Image Logic: Collect up to 4 poster images from the releases
      List<String> imagePaths = [];
      for (int i = 0; i < newReleases.length && i < 4; i++) {
        final movie = movieCacheRepo.getMovie(newReleases[i].tmdbId);
        if (movie?.posterPath != null && movie!.posterPath!.isNotEmpty) {
          // Convert TMDB poster path to full URL
          imagePaths.add('https://image.tmdb.org/t/p/w200${movie.posterPath}');
        }
      }

      // Get priority-based release dates for 2-3 movie notifications
      List<String>? releaseDates;
      if (newReleases.length >= 2 && newReleases.length <= 3) {
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
  }
}