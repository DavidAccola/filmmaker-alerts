import 'package:flutter/foundation.dart';
import '../data/models/movie_detail.dart';
import '../data/models/tv_detail.dart';
import '../data/models/contributor_detail.dart';
import '../data/services/tmdb_service.dart';
import '../data/services/justwatch_service.dart';
import '../data/repositories/movie_detail_repository.dart';
import '../data/repositories/tv_detail_repository.dart';

class WorkLogic {
  final TmdbService _tmdbService;
  final JustWatchService _justWatchService;
  final MovieDetailRepository _movieDetailRepository;
  final TvDetailRepository _tvDetailRepository;

  WorkLogic(
    this._tmdbService,
    this._justWatchService,
    this._movieDetailRepository,
    this._tvDetailRepository,
  );

  Future<MovieDetail?> fetchAndCacheMovieDetail(int tmdbId, {String countryCode = 'US'}) async {
    try {
      // Fetch movie details, credits, and streaming options in parallel
      final results = await Future.wait([
        _tmdbService.getMovieDetails(tmdbId),
        _tmdbService.getMovieCredits(tmdbId),
        _justWatchService.getMovieStreamingOptions(tmdbId: tmdbId, countryCode: countryCode),
      ]);

      final movieData = results[0] as Map<String, dynamic>;
      final creditsData = results[1] as Map<String, dynamic>;
      final streamingOptions = results[2] as List<StreamingOption>;

      // Parse cast
      final cast = (creditsData['cast'] as List? ?? []).take(20).map((c) => CastMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        character: c['character'] ?? '',
        order: c['order'] ?? 0,
      )).toList();

      // Parse crew
      final crew = (creditsData['crew'] as List? ?? []).map((c) => CrewMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        job: c['job'] ?? '',
        department: c['department'] ?? '',
      )).toList();

      final detail = MovieDetail(
        tmdbId: tmdbId,
        title: movieData['title'] ?? 'Unknown',
        posterPath: movieData['poster_path'],
        releaseDate: movieData['release_date'] != null && (movieData['release_date'] as String).isNotEmpty
            ? DateTime.tryParse(movieData['release_date'])
            : null,
        runtime: movieData['runtime'],
        synopsis: movieData['overview'] ?? 'No synopsis available',
        tmdbRating: (movieData['vote_average'] as num?)?.toDouble(),
        popularity: (movieData['popularity'] as num?)?.toDouble(),
        cast: cast,
        crew: crew,
        imdbId: movieData['external_ids']?['imdb_id'] ?? movieData['imdb_id'],
        streamingOptions: streamingOptions,
        voteCount: movieData['vote_count'],
        lastUpdated: DateTime.now(),
      );

      await _movieDetailRepository.cacheMovieDetail(detail);
      return detail;
    } catch (e) {
      debugPrint('[WorkLogic] Error fetching movie details for $tmdbId: $e');
      return null;
    }
  }

  Future<TvShowDetail?> fetchAndCacheTvShowDetail(int tmdbId, {String countryCode = 'US'}) async {
    try {
      final results = await Future.wait([
        _tmdbService.getTvDetails(tmdbId),
        _tmdbService.getTvCredits(tmdbId),
        _justWatchService.getTvStreamingOptions(tmdbId: tmdbId, countryCode: countryCode),
      ]);

      final showData = results[0] as Map<String, dynamic>;
      final creditsData = results[1] as Map<String, dynamic>;
      final streamingOptions = results[2] as List<StreamingOption>;

      final cast = (creditsData['cast'] as List? ?? []).take(20).map((c) => CastMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        character: c['character'] ?? '',
        order: c['order'] ?? 0,
      )).toList();

      final crew = (creditsData['crew'] as List? ?? []).map((c) => CrewMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        job: c['job'] ?? '',
        department: c['department'] ?? '',
      )).toList();

      final seasons = (showData['seasons'] as List? ?? []).map((s) => TvSeason(
        tmdbId: s['id'],
        name: s['name'] ?? '',
        seasonNumber: s['season_number'],
        posterPath: s['poster_path'],
        airDate: s['air_date'] != null ? DateTime.tryParse(s['air_date']) : null,
        episodeCount: s['episode_count'] ?? 0,
        overview: s['overview'],
      )).toList();

      final detail = TvShowDetail(
        tmdbId: tmdbId,
        name: showData['name'] ?? 'Unknown',
        posterPath: showData['poster_path'],
        firstAirDate: showData['first_air_date'] != null ? DateTime.tryParse(showData['first_air_date']) : null,
        lastAirDate: showData['last_air_date'] != null ? DateTime.tryParse(showData['last_air_date']) : null,
        synopsis: showData['overview'] ?? 'No synopsis available',
        tmdbRating: (showData['vote_average'] as num?)?.toDouble(),
        voteCount: showData['vote_count'],
        status: showData['status'],
        cast: cast,
        crew: crew,
        seasons: seasons,
        streamingOptions: streamingOptions,
        imdbId: showData['external_ids']?['imdb_id'],
        numberOfEpisodes: showData['number_of_episodes'],
        numberOfSeasons: showData['number_of_seasons'],
        popularity: (showData['popularity'] as num?)?.toDouble(),
        episodeRunTime: (showData['episode_run_time'] as List? ?? []).cast<int>(),
        lastUpdated: DateTime.now(),
      );

      await _tvDetailRepository.cacheTvShowDetail(detail);
      return detail;
    } catch (e) {
      debugPrint('[WorkLogic] Error fetching TV show details for $tmdbId: $e');
      return null;
    }
  }

  Future<TvEpisodeDetail?> fetchAndCacheTvEpisodeDetail({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    try {
      final results = await Future.wait([
        _tmdbService.getTvEpisodeDetails(showId, seasonNumber, episodeNumber),
        _tmdbService.getTvEpisodeCredits(showId, seasonNumber, episodeNumber),
        _tmdbService.getTvDetailsBasic(showId),
      ]);

      final epData = results[0] as Map<String, dynamic>;
      final creditsData = results[1] as Map<String, dynamic>;
      final showData = results[2] as Map<String, dynamic>;

      final guestStars = (creditsData['guest_stars'] as List? ?? []).map((c) => CastMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        character: c['character'] ?? '',
        order: c['order'] ?? 0,
      )).toList();

      final cast = (creditsData['cast'] as List? ?? []).map((c) => CastMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        character: c['character'] ?? '',
        order: c['order'] ?? 0,
      )).toList();

      final crew = (creditsData['crew'] as List? ?? []).map((c) => CrewMember(
        tmdbId: c['id'],
        name: c['name'],
        profilePath: c['profile_path'],
        job: c['job'] ?? '',
        department: c['department'] ?? '',
      )).toList();

      final detail = TvEpisodeDetail(
        tmdbId: epData['id'],
        showId: showId,
        showName: showData['name'] ?? 'Unknown Show',
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        name: epData['name'] ?? 'Unknown Episode',
        overview: epData['overview'],
        stillPath: epData['still_path'],
        airDate: epData['air_date'] != null ? DateTime.tryParse(epData['air_date']) : null,
        tmdbRating: (epData['vote_average'] as num?)?.toDouble(),
        voteCount: epData['vote_count'],
        guestStars: guestStars,
        mainCast: cast,
        crew: crew,
        runtime: epData['runtime'],
        lastUpdated: DateTime.now(),
      );

      await _tvDetailRepository.cacheTvEpisodeDetail(detail);
      return detail;
    } catch (e) {
      debugPrint('[WorkLogic] Error fetching TV episode details: $e');
      return null;
    }
  }

  Future<TvSeasonDetail?> fetchAndCacheTvSeasonDetail({
    required int showId,
    required int seasonNumber,
  }) async {
    try {
      final seasonData = await _tmdbService.getTvSeasonDetails(showId, seasonNumber);

      final episodes = (seasonData['episodes'] as List? ?? []).map((e) {
        final epCrew = (e['crew'] as List? ?? []).map((c) => CrewMember(
          tmdbId: c['id'],
          name: c['name'],
          profilePath: c['profile_path'],
          job: c['job'] ?? '',
          department: c['department'] ?? '',
        )).toList();

        return SeasonEpisode(
          tmdbId: e['id'],
          episodeNumber: e['episode_number'],
          name: e['name'] ?? '',
          overview: e['overview'],
          stillPath: e['still_path'],
          tmdbRating: (e['vote_average'] as num?)?.toDouble(),
          airDate: e['air_date'] != null ? DateTime.tryParse(e['air_date']) : null,
          crew: epCrew,
          runtime: e['runtime'],
        );
      }).toList();

      final detail = TvSeasonDetail(
        tmdbId: showId,
        name: seasonData['name'] ?? 'Unknown Season',
        seasonNumber: seasonNumber,
        posterPath: seasonData['poster_path'],
        overview: seasonData['overview'],
        episodes: episodes,
        airDate: seasonData['air_date'] != null ? DateTime.tryParse(seasonData['air_date']) : null,
        lastUpdated: DateTime.now(),
      );

      await _tvDetailRepository.cacheTvSeasonDetail(detail);
      return detail;
    } catch (e) {
      debugPrint('[WorkLogic] Error fetching TV season details: $e');
      return null;
    }
  }
}

