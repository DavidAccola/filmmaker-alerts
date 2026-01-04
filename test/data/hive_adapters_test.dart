import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/movie_cache_entry.dart';
import 'package:filmmaker_alerts/data/models/notification_history.dart';
import 'package:filmmaker_alerts/data/models/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ContributorAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LatestWorkAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PreferencesAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(NotificationHistoryEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(NotificationReasonAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(NotificationEventAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(MovieCacheEntryAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(ContributorTypeAdapter());
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('ContributorAdapter handles read/write', () async {
    final box = await Hive.openBox<Contributor>('contributors');
    final contributor = Contributor(
      tmdbId: 123,
      name: 'Test Person',
      type: ContributorType.person,
      profilePath: '/path.jpg',
      notifyForDepartments: ['Directing'],
      availableDepartments: ['Directing'],
      knownFor: 'Movies',
      latestWork: LatestWork(
        title: 'Movie',
        releaseDate: '2025-01-01',
        posterPath: '/poster.jpg',
        department: 'Directing',
        job: 'Director',
        releaseYear: '2025',
      ),
    );

    await box.put(1, contributor);
    final retrieved = box.get(1);

    expect(retrieved, isNotNull);
    expect(retrieved!.tmdbId, 123);
    expect(retrieved.name, 'Test Person');
    expect(retrieved.type, ContributorType.person);
    expect(retrieved.latestWork?.title, 'Movie');
  });

  test('PreferencesAdapter handles read/write', () async {
    final box = await Hive.openBox<Preferences>('preferences');
    final prefs = Preferences(
      scheduleTime: '10:00',
      notifyTheatre: false,
      defaultDepartments: ['Director'],
    );

    await box.put('settings', prefs);
    final retrieved = box.get('settings');

    expect(retrieved, isNotNull);
    expect(retrieved!.scheduleTime, '10:00');
    expect(retrieved.notifyTheatre, false);
    expect(retrieved.defaultDepartments, contains('Director'));
  });
}
