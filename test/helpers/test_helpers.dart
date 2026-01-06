import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:filmmaker_alerts/data/repositories/contributor_repository.dart';
import 'package:filmmaker_alerts/data/repositories/preferences_repository.dart';
import 'package:filmmaker_alerts/data/repositories/history_repository.dart';
import 'package:filmmaker_alerts/data/repositories/movie_cache_repository.dart';
import 'package:filmmaker_alerts/data/repositories/tv_cache_repository.dart';
import 'package:filmmaker_alerts/data/services/notification_service.dart';

@GenerateMocks([
  TmdbService,
  ContributorRepository,
  PreferencesRepository,
  Dio,
  HistoryRepository,
  MovieCacheRepository,
  TvCacheRepository,
  NotificationService,
])
void main() {}