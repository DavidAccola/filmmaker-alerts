import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:filmmaker_alerts/data/repositories/contributor_repository.dart';
import 'package:filmmaker_alerts/data/repositories/preferences_repository.dart';
import 'package:filmmaker_alerts/data/services/tmdb_service.dart';
import 'package:filmmaker_alerts/logic/contributor_logic.dart';
import 'package:filmmaker_alerts/logic/latest_work_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockTmdbService extends Mock implements TmdbService {
  @override
  Future<Map<String, dynamic>> getPersonCombinedCredits(int? id) => super.noSuchMethod(
        Invocation.method(#getPersonCombinedCredits, [id]),
        returnValue: Future.value({'cast': [], 'crew': []}),
      );
}

class MockContributorRepository extends Mock implements ContributorRepository {
  @override
  Future<bool> addContributor(Contributor? contributor) async => super.noSuchMethod(
        Invocation.method(#addContributor, [contributor]),
        returnValue: Future.value(true),
      );
}

class MockPreferencesRepository extends Mock implements PreferencesRepository {
  @override
  Preferences getPreferences() => super.noSuchMethod(
    Invocation.method(#getPreferences, []),
    returnValue: Preferences(),
  );
}

class MockLatestWorkLogic extends Mock implements LatestWorkLogic {
  @override
  Future<LatestWork?> calculateLatestWork(Contributor? contributor, {String? pretendToday}) =>
      super.noSuchMethod(
        Invocation.method(#calculateLatestWork, [contributor], {#pretendToday: pretendToday}),
        returnValue: Future.value(null),
      );
}

void main() {
  late ContributorLogic contributorLogic;
  late MockTmdbService mockTmdb;
  late MockContributorRepository mockRepo;
  late MockLatestWorkLogic mockLatestWorkLogic;
  late MockPreferencesRepository mockPrefsRepo;

  setUp(() {
    mockTmdb = MockTmdbService();
    mockRepo = MockContributorRepository();
    mockLatestWorkLogic = MockLatestWorkLogic();
    mockPrefsRepo = MockPreferencesRepository();

    contributorLogic = ContributorLogic(
      mockRepo,
      mockTmdb,
      mockLatestWorkLogic,
      mockPrefsRepo,
    );
  });

  test('addEnrichedContributor should fetch credits and calculate latest work', () async {
    // 1. Setup
    final sparse = Contributor(
      tmdbId: 1,
      name: 'Nolan',
      type: ContributorType.person,
      profilePath: '/path.jpg',
      notifyForDepartments: [],
      availableDepartments: [],
      knownFor: 'Batman',
    );

    when(mockPrefsRepo.getPreferences()).thenReturn(Preferences(
      defaultDepartments: ['Director'],
    ));

    when(mockTmdb.getPersonCombinedCredits(1)).thenAnswer((_) async => {
      'crew': [
        {'id': 100, 'department': 'Directing', 'job': 'Director'},
      ]
    });

    when(mockRepo.addContributor(any)).thenAnswer((_) async => true);

    final expectedLatestWork = LatestWork(
      title: 'Oppenheimer',
      releaseYear: '2023',
      releaseDate: '2023-07-21',
      department: 'Directing',
      job: 'Director',
    );
    
    when(mockLatestWorkLogic.calculateLatestWork(any, pretendToday: anyNamed('pretendToday')))
        .thenAnswer((_) async => expectedLatestWork);

    // 2. Execute
    final result = await contributorLogic.addEnrichedContributor(sparse);

    // 3. Verify
    expect(result, isTrue);

    // Check that we fetched credits
    verify(mockTmdb.getPersonCombinedCredits(1)).called(1);
    
    // Check that we called repository with enriched data
    final captured = verify(mockRepo.addContributor(captureAny)).captured.first as Contributor;
    
    expect(captured.availableDepartments, contains('Director'));
    expect(captured.notifyForDepartments, contains('Director'));
    expect(captured.latestWork, isNotNull);
    expect(captured.latestWork!.title, 'Oppenheimer');
  });
}
