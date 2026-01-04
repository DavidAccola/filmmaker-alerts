import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/logic/latest_work_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.mocks.dart';

void main() {
  late LatestWorkLogic latestWorkLogic;
  late MockTmdbService mockTmdbService;

  setUp(() {
    mockTmdbService = MockTmdbService();
    latestWorkLogic = LatestWorkLogic(mockTmdbService);
  });

  test('Should ignore future releases for Person', () async {
    // Arrange
    final contributor = Contributor(
      tmdbId: 1,
      name: 'Test Director',
      type: ContributorType.person,
      notifyForDepartments: ['Director'],
      availableDepartments: ['Director'],
      knownFor: '',
    );

    final credits = {
      'crew': [
        {
          'id': 101,
          'title': 'Future Movie',
          'department': 'Directing',
          'job': 'Director',
          'release_date': '2099-01-01' // Future
        },
        {
          'id': 102,
          'title': 'Past Movie',
          'department': 'Directing',
          'job': 'Director',
          'release_date': '2020-01-01' // Past
        }
      ],
      'cast': []
    };

    when(mockTmdbService.getPersonCombinedCredits(1))
        .thenAnswer((_) async => credits);

    // Act
    // We pass a pretendToday to ensure the test is deterministic
    final result = await latestWorkLogic.calculateLatestWork(
      contributor, 
      pretendToday: '2024-01-01'
    );

    // Assert
    expect(result, isNotNull);
    expect(result!.title, 'Past Movie'); // Should skip Future Movie
    expect(result.releaseDate, '2020-01-01');
  });
}