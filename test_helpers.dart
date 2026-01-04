import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:filmmaker_alerts/data/repositories/contributor_repository.dart';
import 'package:filmmaker_alerts/data/repositories/preferences_repository.dart';

@GenerateMocks([
  TmdbService,
  ContributorRepository,
  PreferencesRepository,
  Dio,
])
void main() {}