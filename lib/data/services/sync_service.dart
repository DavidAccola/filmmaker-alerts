import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import '../models/contributor.dart';
import '../models/contributor_detail.dart'; // for WorkType, ReleaseType
import '../models/episode_status_entry.dart';
import '../models/movie_status_entry.dart';
import '../models/preferences.dart';
import '../models/season_status_entry.dart';
import '../models/status_record.dart';
import '../models/watchlist_entry.dart';
import '../../core/constants.dart';
import 'google_auth_service.dart';

/// Key used in secure storage to track the last local sync timestamp.
const _kLastSyncKey = 'last_sync_timestamp';

/// Filename of the sync file in Drive appDataFolder.
const _kDriveFileName = 'filmmaker_alerts_sync.json';

/// Syncs app data between devices via Google Drive appDataFolder.
///
/// Serializes six Hive boxes to JSON, uploads on write triggers,
/// and downloads + replaces local data on app launch / resume.
/// Conflict resolution: last-write-wins by [lastModified] timestamp.
class SyncService {
  final GoogleAuthService _auth;
  final FlutterSecureStorage _storage;

  /// Guard against concurrent uploads (e.g. rapid watchlist changes).
  bool _isUploading = false;

  /// Set to true while _applyPayload runs to prevent the watchlist listener
  /// from immediately re-uploading data that was just downloaded.
  bool _isApplyingDownload = false;

  SyncService({
    required GoogleAuthService auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth,
        _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Upload local data to Drive. Called on app close and after mutations.
  /// Silent fail if not signed in, no network, already uploading, or
  /// currently applying a downloaded payload (prevents echo uploads).
  Future<void> uploadIfSignedIn() async {
    if (!_auth.isSignedIn || _isUploading || _isApplyingDownload) return;
    _isUploading = true;
    try {
      await _upload();
    } catch (_) {
      // Silent fail — local data is authoritative, sync is best-effort
    } finally {
      _isUploading = false;
    }
  }

  /// Download from Drive if remote is newer. Called on app launch and resume.
  /// Returns true if local data was replaced.
  Future<bool> downloadIfNewerAndSignedIn() async {
    if (!_auth.isSignedIn) return false;
    try {
      return await _downloadIfNewer();
    } catch (_) {
      return false;
    }
  }

  /// The timestamp of the last successful sync, for display in settings.
  Future<DateTime?> lastSyncTime() async {
    final stored = await _storage.read(key: _kLastSyncKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  Future<void> _upload() async {
    final payload = _buildPayload();
    final bytes = utf8.encode(jsonEncode(payload));
    final driveApi = drive.DriveApi(_auth.client!);

    // Check if file already exists
    final existingId = await _findExistingFileId(driveApi);

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (existingId != null) {
      await driveApi.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
      );
    } else {
      final file = drive.File()
        ..name = _kDriveFileName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(
        file,
        uploadMedia: media,
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await _storage.write(key: _kLastSyncKey, value: now);
  }

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

  Future<bool> _downloadIfNewer() async {
    final driveApi = drive.DriveApi(_auth.client!);
    final fileId = await _findExistingFileId(driveApi);
    if (fileId == null) return false; // nothing on Drive yet

    // Get the file metadata to check modifiedTime
    final meta = await driveApi.files.get(
      fileId,
      $fields: 'modifiedTime',
    ) as drive.File;

    final remoteModified = meta.modifiedTime;
    if (remoteModified == null) return false;

    // Check against local last-sync time
    final localStr = await _storage.read(key: _kLastSyncKey);
    if (localStr != null) {
      final localTime = DateTime.tryParse(localStr);
      if (localTime != null && !remoteModified.isAfter(localTime)) {
        return false; // local is same or newer
      }
    }

    // Download and apply
    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    _isApplyingDownload = true;
    try {
      await _applyPayload(payload);
    } finally {
      _isApplyingDownload = false;
    }

    await _storage.write(
      key: _kLastSyncKey,
      value: remoteModified.toUtc().toIso8601String(),
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // Payload — build and apply
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildPayload() {
    return {
      'lastModified': DateTime.now().toUtc().toIso8601String(),
      'version': 1,
      'watchlistEntries': _serializeBox<WatchlistEntry>(
          AppConstants.watchlistEntriesBox, _serializeWatchlistEntry),
      'contributors': _serializeBox<Contributor>(
          AppConstants.contributorsBox, _serializeContributor),
      'preferences': _serializePreferences(),
      'episodeStatuses': _serializeBox<EpisodeStatusEntry>(
          AppConstants.episodeStatusesBox, _serializeEpisodeStatus),
      'seasonStatuses': _serializeBox<SeasonStatusEntry>(
          AppConstants.seasonStatusesBox, _serializeSeasonStatus),
      'movieStatuses': _serializeBox<MovieStatusEntry>(
          AppConstants.movieStatusesBox, _serializeMovieStatus),
    };
  }

  Future<void> _applyPayload(Map<String, dynamic> payload) async {
    if (payload['watchlistEntries'] != null) {
      await _replaceBox<WatchlistEntry>(
        AppConstants.watchlistEntriesBox,
        payload['watchlistEntries'] as List,
        _deserializeWatchlistEntry,
        (e) => e.uniqueKey,
      );
    }
    if (payload['contributors'] != null) {
      await _replaceBox<Contributor>(
        AppConstants.contributorsBox,
        payload['contributors'] as List,
        _deserializeContributor,
        (c) => c.tmdbId.toString(),
      );
    }
    if (payload['preferences'] != null) {
      await _applyPreferences(
          payload['preferences'] as Map<String, dynamic>);
    }
    if (payload['episodeStatuses'] != null) {
      await _replaceBox<EpisodeStatusEntry>(
        AppConstants.episodeStatusesBox,
        payload['episodeStatuses'] as List,
        _deserializeEpisodeStatus,
        (e) => e.uniqueKey,
      );
    }
    if (payload['seasonStatuses'] != null) {
      await _replaceBox<SeasonStatusEntry>(
        AppConstants.seasonStatusesBox,
        payload['seasonStatuses'] as List,
        _deserializeSeasonStatus,
        (e) => e.uniqueKey,
      );
    }
    if (payload['movieStatuses'] != null) {
      await _replaceBox<MovieStatusEntry>(
        AppConstants.movieStatusesBox,
        payload['movieStatuses'] as List,
        _deserializeMovieStatus,
        (e) => e.uniqueKey,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Box helpers
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _serializeBox<T>(
    String boxName,
    Map<String, dynamic> Function(T) serializer,
  ) {
    final box = Hive.box<T>(boxName);
    return box.values.map(serializer).toList();
  }

  Future<void> _replaceBox<T extends HiveObject>(
    String boxName,
    List items,
    T Function(Map<String, dynamic>) deserializer,
    String Function(T) keyOf,
  ) async {
    final box = Hive.box<T>(boxName);

    // Build new items map first — no data is deleted until we're ready.
    final newItems = <String, T>{};
    for (final item in items) {
      final obj = deserializer(item as Map<String, dynamic>);
      newItems[keyOf(obj)] = obj;
    }

    // Delete keys no longer present in the remote data.
    final keysToDelete = box.keys.cast<String>().toSet()
        .difference(newItems.keys.toSet());
    for (final k in keysToDelete) {
      await box.delete(k);
    }

    // Upsert new and changed entries.
    for (final entry in newItems.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<String?> _findExistingFileId(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_kDriveFileName'",
      $fields: 'files(id)',
    );
    return list.files?.firstOrNull?.id;
  }

  // ---------------------------------------------------------------------------
  // WatchlistEntry serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeWatchlistEntry(WatchlistEntry e) => {
        'tmdbId': e.tmdbId,
        'type': e.type.name,
        'title': e.title,
        'posterPath': e.posterPath,
        'releaseDate': e.releaseDate?.toIso8601String(),
        'releaseType': e.releaseType?.name,
        'addedAt': e.addedAt.toIso8601String(),
        'addRank': e.addRank,
        'userRank': e.userRank,
        'userRating': e.userRating,
        'isSnoozed': e.isSnoozed,
        'notificationsSnoozed': e.notificationsSnoozed,
        'overriddenGenre': e.overriddenGenre,
        'genreListId': e.genreListId,
        'lastViewedAt': e.lastViewedAt?.toIso8601String(),
        'followedContributors': e.followedContributors
            .map((c) => {
                  'contributorId': c.contributorId,
                  'name': c.name,
                  'role': c.role,
                })
            .toList(),
        'statusRecords': e.statusRecords.map(_serializeStatusRecord).toList(),
        'releaseNotificationPrefs': e.releaseNotificationPrefs == null
            ? null
            : {
                'theatrical': e.releaseNotificationPrefs!.theatrical,
                'streaming': e.releaseNotificationPrefs!.streaming,
                'physical': e.releaseNotificationPrefs!.physical,
                'tv': e.releaseNotificationPrefs!.tv,
              },
      };

  WatchlistEntry _deserializeWatchlistEntry(Map<String, dynamic> m) {
    final entry = WatchlistEntry(
      tmdbId: m['tmdbId'] as int,
      type: WorkType.values.byName(m['type'] as String),
      title: m['title'] as String,
      posterPath: m['posterPath'] as String?,
      releaseDate: m['releaseDate'] != null
          ? DateTime.parse(m['releaseDate'] as String)
          : null,
      releaseType: m['releaseType'] != null
          ? ReleaseType.values.byName(m['releaseType'] as String)
          : null,
      addedAt: DateTime.parse(m['addedAt'] as String),
      addRank: m['addRank'] as int,
      userRank: m['userRank'] as int?,
      isSnoozed: m['isSnoozed'] as bool? ?? false,
      notificationsSnoozed: m['notificationsSnoozed'] as bool? ?? false,
      overriddenGenre: m['overriddenGenre'] as String?,
      genreListId: m['genreListId'] as String?,
      lastViewedAt: m['lastViewedAt'] != null
          ? DateTime.parse(m['lastViewedAt'] as String)
          : null,
      followedContributors: (m['followedContributors'] as List?)
              ?.map((c) => ContributorSnapshot(
                    contributorId: c['contributorId'] as int,
                    name: c['name'] as String,
                    role: c['role'] as String,
                  ))
              .toList() ??
          [],
      statusRecords: (m['statusRecords'] as List?)
              ?.map((s) => _deserializeStatusRecord(s as Map<String, dynamic>))
              .toList() ??
          [],
      releaseNotificationPrefs: m['releaseNotificationPrefs'] != null
          ? ReleaseNotificationPreferences(
              theatrical:
                  m['releaseNotificationPrefs']['theatrical'] as bool? ?? true,
              streaming:
                  m['releaseNotificationPrefs']['streaming'] as bool? ?? true,
              physical:
                  m['releaseNotificationPrefs']['physical'] as bool? ?? false,
              tv: m['releaseNotificationPrefs']['tv'] as bool? ?? false,
            )
          : null,
    );
    entry.userRating = m['userRating'] as int?;
    return entry;
  }

  // ---------------------------------------------------------------------------
  // StatusRecord serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeStatusRecord(StatusRecord r) => {
        'status': r.status.name,
        'setAt': r.setAt.toIso8601String(),
        'watchDates': r.watchDates?.map((d) => d.toIso8601String()).toList(),
      };

  StatusRecord _deserializeStatusRecord(Map<String, dynamic> m) =>
      StatusRecord(
        status: WatchStatus.values.byName(m['status'] as String),
        setAt: DateTime.parse(m['setAt'] as String),
        watchDates: (m['watchDates'] as List?)
            ?.map((d) => DateTime.parse(d as String))
            .toList(),
      );

  // ---------------------------------------------------------------------------
  // Contributor serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeContributor(Contributor c) => {
        'tmdbId': c.tmdbId,
        'name': c.name,
        'type': c.type.name,
        'profilePath': c.profilePath,
        'knownFor': c.knownFor,
        'isHidden': c.isHidden,
        'notificationsSnoozed': c.notificationsSnoozed,
        'notifyForDepartments': c.notifyForDepartments,
        'availableDepartments': c.availableDepartments,
        'allRolesSelected': c.allRolesSelected,
        'notifyTvEpisodeWork': c.notifyTvEpisodeWork,
        'showStatus': c.showStatus,
        'totalSeasons': c.totalSeasons,
        'nextEpisodeDate': c.nextEpisodeDate,
        'imdbId': c.imdbId,
        'followedAt': c.followedAt?.toIso8601String(),
        'tvNotificationPrefs': c.tvNotificationPrefs == null
            ? null
            : {
                'seriesPremiere': c.tvNotificationPrefs!.seriesPremiere,
                'seasonPremieres': c.tvNotificationPrefs!.seasonPremieres,
                'seasonFinales': c.tvNotificationPrefs!.seasonFinales,
                'newEpisodes': c.tvNotificationPrefs!.newEpisodes,
                'specials': c.tvNotificationPrefs!.specials,
              },
        'latestWork': c.latestWork == null
            ? null
            : {
                'title': c.latestWork!.title,
                'releaseYear': c.latestWork!.releaseYear,
                'releaseDate': c.latestWork!.releaseDate,
                'department': c.latestWork!.department,
                'job': c.latestWork!.job,
                'posterPath': c.latestWork!.posterPath,
                'originalReleaseDate': c.latestWork!.originalReleaseDate,
                'originalReleaseType': c.latestWork!.originalReleaseType,
                'latestReleaseDate': c.latestWork!.latestReleaseDate,
                'latestReleaseType': c.latestWork!.latestReleaseType,
              },
      };

  Contributor _deserializeContributor(Map<String, dynamic> m) {
    final tvPrefsMap = m['tvNotificationPrefs'] as Map<String, dynamic>?;
    final latestWorkMap = m['latestWork'] as Map<String, dynamic>?;
    return Contributor(
        tmdbId: m['tmdbId'] as int,
        name: m['name'] as String,
        type: ContributorType.values.byName(m['type'] as String),
        profilePath: m['profilePath'] as String?,
        knownFor: m['knownFor'] as String? ?? '',
        isHidden: m['isHidden'] as bool? ?? false,
        notificationsSnoozed: m['notificationsSnoozed'] as bool? ?? false,
        notifyForDepartments:
            List<String>.from(m['notifyForDepartments'] as List? ?? []),
        availableDepartments:
            List<String>.from(m['availableDepartments'] as List? ?? []),
        allRolesSelected: m['allRolesSelected'] as bool?,
        notifyTvEpisodeWork: m['notifyTvEpisodeWork'] as bool?,
        showStatus: m['showStatus'] as String?,
        totalSeasons: m['totalSeasons'] as int?,
        nextEpisodeDate: m['nextEpisodeDate'] as String?,
        imdbId: m['imdbId'] as String?,
        followedAt: m['followedAt'] != null
            ? DateTime.parse(m['followedAt'] as String)
            : null,
        tvNotificationPrefs: tvPrefsMap == null
            ? null
            : TvNotificationPreferences(
                seriesPremiere: tvPrefsMap['seriesPremiere'] as bool? ?? true,
                seasonPremieres: tvPrefsMap['seasonPremieres'] as bool? ?? true,
                seasonFinales: tvPrefsMap['seasonFinales'] as bool? ?? false,
                newEpisodes: tvPrefsMap['newEpisodes'] as bool? ?? false,
                specials: tvPrefsMap['specials'] as bool? ?? false,
              ),
        latestWork: latestWorkMap == null
            ? null
            : LatestWork(
                title: latestWorkMap['title'] as String,
                releaseYear: latestWorkMap['releaseYear'] as String,
                releaseDate: latestWorkMap['releaseDate'] as String,
                department: latestWorkMap['department'] as String,
                job: latestWorkMap['job'] as String?,
                posterPath: latestWorkMap['posterPath'] as String?,
                originalReleaseDate:
                    latestWorkMap['originalReleaseDate'] as String?,
                originalReleaseType:
                    latestWorkMap['originalReleaseType'] as String?,
                latestReleaseDate:
                    latestWorkMap['latestReleaseDate'] as String?,
                latestReleaseType:
                    latestWorkMap['latestReleaseType'] as String?,
              ),
    );
  }

  // ---------------------------------------------------------------------------
  // Preferences serialization (single object, not a list)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializePreferences() {
    final box = Hive.box<Preferences>(AppConstants.preferencesBox);
    if (box.isEmpty) return {};
    final p = box.getAt(0)!;
    return {
      'notifyTheatre': p.notifyTheatre,
      'notifyStreaming': p.notifyStreaming,
      'notifyPhysical': p.notifyPhysical,
      'notifyTV': p.notifyTV,
      'scheduleTime': p.scheduleTime,
      'useDarkMode': p.useDarkMode,
      'watchlistSortOrder': p.watchlistSortOrder,
      'watchlistUseListView': p.watchlistUseListView,
      'connectionsSortOrder': p.connectionsSortOrder,
      'connectionsGroupByRelease': p.connectionsGroupByRelease,
      'connectionsShowHiddenContributors': p.connectionsShowHiddenContributors,
      'connectionsShowHiddenWatchlist': p.connectionsShowHiddenWatchlist,
      'dismissedConnectionIds': p.dismissedConnectionIds,
      'streamingCountry': p.streamingCountry,
      'defaultDepartments': p.defaultDepartments,
      'hideRatingsInDetails': p.hideRatingsInDetails,
    };
  }

  Future<void> _applyPreferences(Map<String, dynamic> m) async {
    final box = Hive.box<Preferences>(AppConstants.preferencesBox);
    final p = box.isEmpty ? Preferences() : box.getAt(0)!;
    p.notifyTheatre = m['notifyTheatre'] as bool? ?? p.notifyTheatre;
    p.notifyStreaming = m['notifyStreaming'] as bool? ?? p.notifyStreaming;
    p.notifyPhysical = m['notifyPhysical'] as bool? ?? p.notifyPhysical;
    p.notifyTV = m['notifyTV'] as bool? ?? p.notifyTV;
    p.scheduleTime = m['scheduleTime'] as String? ?? p.scheduleTime;
    p.useDarkMode = m['useDarkMode'] as bool? ?? p.useDarkMode;
    p.watchlistSortOrder = m['watchlistSortOrder'] as String?;
    p.watchlistUseListView =
        m['watchlistUseListView'] as bool? ?? p.watchlistUseListView;
    p.connectionsSortOrder = m['connectionsSortOrder'] as String?;
    p.connectionsGroupByRelease = m['connectionsGroupByRelease'] as bool?;
    p.connectionsShowHiddenContributors =
        m['connectionsShowHiddenContributors'] as bool?;
    p.connectionsShowHiddenWatchlist =
        m['connectionsShowHiddenWatchlist'] as bool?;
    p.dismissedConnectionIds =
        List<String>.from(m['dismissedConnectionIds'] as List? ?? []);
    p.streamingCountry = m['streamingCountry'] as String? ?? p.streamingCountry;
    if (m['defaultDepartments'] != null) {
      p.defaultDepartments = List<String>.from(m['defaultDepartments'] as List);
    }
    p.hideRatingsInDetails = m['hideRatingsInDetails'] as bool?;
    if (box.isEmpty) {
      await box.add(p);
    } else {
      await box.putAt(0, p);
    }
  }

  // ---------------------------------------------------------------------------
  // EpisodeStatusEntry serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeEpisodeStatus(EpisodeStatusEntry e) => {
        'showId': e.showId,
        'seasonNumber': e.seasonNumber,
        'episodeNumber': e.episodeNumber,
        'episodeTitle': e.episodeTitle,
        'airDate': e.airDate?.toIso8601String(),
        'userRating': e.userRating,
        'statusRecords': e.statusRecords.map(_serializeStatusRecord).toList(),
      };

  EpisodeStatusEntry _deserializeEpisodeStatus(Map<String, dynamic> m) {
    final entry = EpisodeStatusEntry(
      showId: m['showId'] as int,
      seasonNumber: m['seasonNumber'] as int,
      episodeNumber: m['episodeNumber'] as int,
      episodeTitle: m['episodeTitle'] as String,
      airDate: m['airDate'] != null
          ? DateTime.parse(m['airDate'] as String)
          : null,
      statusRecords: (m['statusRecords'] as List?)
              ?.map((s) => _deserializeStatusRecord(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
    entry.userRating = m['userRating'] as int?;
    return entry;
  }

  // ---------------------------------------------------------------------------
  // SeasonStatusEntry serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeSeasonStatus(SeasonStatusEntry s) => {
        'showId': s.showId,
        'seasonNumber': s.seasonNumber,
        'airDate': s.airDate?.toIso8601String(),
        'userRating': s.userRating,
        'statusRecords': s.statusRecords.map(_serializeStatusRecord).toList(),
      };

  SeasonStatusEntry _deserializeSeasonStatus(Map<String, dynamic> m) {
    final entry = SeasonStatusEntry(
      showId: m['showId'] as int,
      seasonNumber: m['seasonNumber'] as int,
      airDate: m['airDate'] != null
          ? DateTime.parse(m['airDate'] as String)
          : null,
      statusRecords: (m['statusRecords'] as List?)
              ?.map((s) => _deserializeStatusRecord(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
    entry.userRating = m['userRating'] as int?;
    return entry;
  }

  // ---------------------------------------------------------------------------
  // MovieStatusEntry serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeMovieStatus(MovieStatusEntry m) => {
        'collectionId': m.collectionId,
        'movieId': m.movieId,
        'movieTitle': m.movieTitle,
        'releaseDate': m.releaseDate?.toIso8601String(),
        'statusRecords': m.statusRecords.map(_serializeStatusRecord).toList(),
      };

  MovieStatusEntry _deserializeMovieStatus(Map<String, dynamic> m) =>
      MovieStatusEntry(
        collectionId: m['collectionId'] as int,
        movieId: m['movieId'] as int,
        movieTitle: m['movieTitle'] as String,
        releaseDate: m['releaseDate'] != null
            ? DateTime.parse(m['releaseDate'] as String)
            : null,
        statusRecords: (m['statusRecords'] as List?)
                ?.map((s) => _deserializeStatusRecord(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
