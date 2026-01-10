import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/logic/tv_show_display_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TvShowDisplayLogic', () {
    // Helper function to create test works
    Work createWork({
      required int tmdbId,
      required String title,
      required WorkType type,
      DateTime? releaseDate,
      int? seasonNumber,
      int? episodeNumber,
      List<ContributorRole>? roles,
    }) {
      return Work(
        tmdbId: tmdbId,
        title: title,
        type: type,
        releaseDate: releaseDate,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        contributorRoles: roles ?? [],
      );
    }

    ContributorRole createRole({
      required String role,
      String? department,
    }) {
      return ContributorRole(
        contributorId: 1,
        contributorName: 'Test Person',
        role: role,
        department: department,
      );
    }

    group('separateTvShowCredits', () {
      test('Property 11: TV Show Role Handling - Separates creator shows from directed episodes', () {
        // **Property 11: TV Show Role Handling**
        // **Validates: Requirements 8.1, 8.2, 8.4**
        
        // Property test with 100 iterations covering different combinations
        for (int i = 0; i < 100; i++) {
          final works = <Work>[
            // Creator shows
            createWork(
              tmdbId: 1000 + i,
              title: 'Created Show $i',
              type: WorkType.tvShow,
              releaseDate: DateTime(2020 + (i % 5)),
              roles: [createRole(role: 'Creator')],
            ),
            createWork(
              tmdbId: 2000 + i,
              title: 'Another Created Show $i',
              type: WorkType.tvShow,
              releaseDate: DateTime(2021 + (i % 4)),
              roles: [createRole(role: 'Creator', department: 'Creator')],
            ),
            // Directed episodes
            createWork(
              tmdbId: 3000 + i,
              title: 'Show Name - S01E01 - Episode $i',
              type: WorkType.tvEpisode,
              releaseDate: DateTime(2022, 1, 1 + (i % 28)),
              seasonNumber: 1,
              episodeNumber: 1 + (i % 10),
              roles: [createRole(role: 'Director')],
            ),
            createWork(
              tmdbId: 4000 + i,
              title: 'Show Name - S02E05 - Episode $i',
              type: WorkType.tvEpisode,
              releaseDate: DateTime(2023, 6, 1 + (i % 28)),
              seasonNumber: 2,
              episodeNumber: 5 + (i % 5),
              roles: [createRole(role: 'Director', department: 'Directing')],
            ),
            // Non-TV works (should be ignored)
            createWork(
              tmdbId: 5000 + i,
              title: 'Movie $i',
              type: WorkType.movie,
              releaseDate: DateTime(2024),
              roles: [createRole(role: 'Director')],
            ),
          ];

          final result = TvShowDisplayLogic.separateTvShowCredits(works);
          final shows = result['shows'] ?? [];
          final episodes = result['episodes'] ?? [];

          // Verify shows are separated correctly
          expect(shows.length, equals(2),
            reason: 'Should have exactly 2 creator shows');
          expect(shows.every((w) => w.type == WorkType.tvShow),
            equals(true),
            reason: 'All shows should be TV shows');
          expect(shows.every((w) => w.contributorRoles.any((r) => 
            r.role.toLowerCase() == 'creator' || r.department?.toLowerCase() == 'creator')),
            equals(true),
            reason: 'All shows should have creator role');

          // Verify episodes are separated correctly
          expect(episodes.length, equals(2),
            reason: 'Should have exactly 2 directed episodes');
          expect(episodes.every((w) => w.type == WorkType.tvEpisode),
            equals(true),
            reason: 'All episodes should be TV episodes');
          expect(episodes.every((w) => w.contributorRoles.any((r) =>
            r.role.toLowerCase() == 'director' || r.department?.toLowerCase() == 'directing')),
            equals(true),
            reason: 'All episodes should have director role');

          // Verify movies are not included
          expect(shows.any((w) => w.type == WorkType.movie),
            equals(false),
            reason: 'Shows should not include movies');
          expect(episodes.any((w) => w.type == WorkType.movie),
            equals(false),
            reason: 'Episodes should not include movies');
        }
      });

      test('Returns empty lists when no TV works exist', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            type: WorkType.movie,
            roles: [createRole(role: 'Director')],
          ),
        ];

        final result = TvShowDisplayLogic.separateTvShowCredits(works);

        expect(result['shows'], isEmpty);
        expect(result['episodes'], isEmpty);
      });

      test('Handles mixed roles correctly', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Show 1',
            type: WorkType.tvShow,
            roles: [
              createRole(role: 'Creator'),
              createRole(role: 'Writer'),
            ],
          ),
          createWork(
            tmdbId: 2,
            title: 'Show 2 - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
            roles: [
              createRole(role: 'Director'),
              createRole(role: 'Writer'),
            ],
          ),
        ];

        final result = TvShowDisplayLogic.separateTvShowCredits(works);

        expect(result['shows']!.length, equals(1));
        expect(result['episodes']!.length, equals(1));
      });
    });

    group('groupEpisodesByShow', () {
      test('Groups episodes by show title correctly', () {
        final episodes = [
          createWork(
            tmdbId: 1,
            title: 'Breaking Bad - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
          ),
          createWork(
            tmdbId: 2,
            title: 'Breaking Bad - S01E02',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 2,
          ),
          createWork(
            tmdbId: 3,
            title: 'Breaking Bad - S02E01',
            type: WorkType.tvEpisode,
            seasonNumber: 2,
            episodeNumber: 1,
          ),
          createWork(
            tmdbId: 4,
            title: 'The Office - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ];

        final grouped = TvShowDisplayLogic.groupEpisodesByShow(episodes);

        // Should have 2 shows: Breaking Bad and The Office
        expect(grouped.length, equals(2));
        expect(grouped['Breaking Bad']?.length, equals(3));
        expect(grouped['The Office']?.length, equals(1));
      });

      test('Sorts episodes within each show by season and episode number', () {
        final episodes = [
          createWork(
            tmdbId: 1,
            title: 'Show - S02E05',
            type: WorkType.tvEpisode,
            seasonNumber: 2,
            episodeNumber: 5,
          ),
          createWork(
            tmdbId: 2,
            title: 'Show - S01E10',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 10,
          ),
          createWork(
            tmdbId: 3,
            title: 'Show - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
          ),
          createWork(
            tmdbId: 4,
            title: 'Show - S02E01',
            type: WorkType.tvEpisode,
            seasonNumber: 2,
            episodeNumber: 1,
          ),
        ];

        final grouped = TvShowDisplayLogic.groupEpisodesByShow(episodes);
        final showEpisodes = grouped['Show']!;

        expect(showEpisodes[0].seasonNumber, equals(1));
        expect(showEpisodes[0].episodeNumber, equals(1));
        expect(showEpisodes[1].seasonNumber, equals(1));
        expect(showEpisodes[1].episodeNumber, equals(10));
        expect(showEpisodes[2].seasonNumber, equals(2));
        expect(showEpisodes[2].episodeNumber, equals(1));
        expect(showEpisodes[3].seasonNumber, equals(2));
        expect(showEpisodes[3].episodeNumber, equals(5));
      });
    });

    group('formatEpisodeInfo', () {
      test('Formats episode info correctly with episode name', () {
        final episode = createWork(
          tmdbId: 1,
          title: 'Breaking Bad - S01E01 - Pilot',
          type: WorkType.tvEpisode,
          seasonNumber: 1,
          episodeNumber: 1,
        );

        final formatted = TvShowDisplayLogic.formatEpisodeInfo(episode);

        expect(formatted, equals('S01E01 - Pilot'));
      });

      test('Formats episode info with zero-padded season and episode numbers', () {
        final episode = createWork(
          tmdbId: 1,
          title: 'Show - S05E09',
          type: WorkType.tvEpisode,
          seasonNumber: 5,
          episodeNumber: 9,
        );

        final formatted = TvShowDisplayLogic.formatEpisodeInfo(episode);

        expect(formatted, equals('S05E09'));
      });

      test('Handles null season and episode numbers', () {
        final episode = createWork(
          tmdbId: 1,
          title: 'Show - Episode',
          type: WorkType.tvEpisode,
          seasonNumber: null,
          episodeNumber: null,
        );

        final formatted = TvShowDisplayLogic.formatEpisodeInfo(episode);

        // When season/episode are null, they're treated as 0, and episode name is extracted
        expect(formatted, startsWith('S00E00'));
      });
    });

    group('hasMultipleTvRoles', () {
      test('Returns true when contributor has both creator and director roles', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Show 1',
            type: WorkType.tvShow,
            roles: [createRole(role: 'Creator')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Show 2 - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
            roles: [createRole(role: 'Director')],
          ),
        ];

        final hasMultiple = TvShowDisplayLogic.hasMultipleTvRoles(works);

        expect(hasMultiple, equals(true));
      });

      test('Returns false when contributor only has creator role', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Show 1',
            type: WorkType.tvShow,
            roles: [createRole(role: 'Creator')],
          ),
        ];

        final hasMultiple = TvShowDisplayLogic.hasMultipleTvRoles(works);

        expect(hasMultiple, equals(false));
      });

      test('Returns false when contributor only has director role', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Show - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
            roles: [createRole(role: 'Director')],
          ),
        ];

        final hasMultiple = TvShowDisplayLogic.hasMultipleTvRoles(works);

        expect(hasMultiple, equals(false));
      });

      test('Returns false when no TV works exist', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            type: WorkType.movie,
            roles: [createRole(role: 'Director')],
          ),
        ];

        final hasMultiple = TvShowDisplayLogic.hasMultipleTvRoles(works);

        expect(hasMultiple, equals(false));
      });
    });

    group('sortShowsByReleaseDate', () {
      test('Sorts shows by release date (most recent first)', () {
        final shows = [
          createWork(
            tmdbId: 1,
            title: 'Show 1',
            type: WorkType.tvShow,
            releaseDate: DateTime(2020),
          ),
          createWork(
            tmdbId: 2,
            title: 'Show 2',
            type: WorkType.tvShow,
            releaseDate: DateTime(2023),
          ),
          createWork(
            tmdbId: 3,
            title: 'Show 3',
            type: WorkType.tvShow,
            releaseDate: DateTime(2021),
          ),
        ];

        final sorted = TvShowDisplayLogic.sortShowsByReleaseDate(shows);

        expect(sorted[0].releaseDate, equals(DateTime(2023)));
        expect(sorted[1].releaseDate, equals(DateTime(2021)));
        expect(sorted[2].releaseDate, equals(DateTime(2020)));
      });

      test('Handles null release dates (puts them last)', () {
        final shows = [
          createWork(
            tmdbId: 1,
            title: 'Show 1',
            type: WorkType.tvShow,
            releaseDate: DateTime(2020),
          ),
          createWork(
            tmdbId: 2,
            title: 'Show 2',
            type: WorkType.tvShow,
            releaseDate: null,
          ),
          createWork(
            tmdbId: 3,
            title: 'Show 3',
            type: WorkType.tvShow,
            releaseDate: DateTime(2023),
          ),
        ];

        final sorted = TvShowDisplayLogic.sortShowsByReleaseDate(shows);

        expect(sorted[0].releaseDate, equals(DateTime(2023)));
        expect(sorted[1].releaseDate, equals(DateTime(2020)));
        expect(sorted[2].releaseDate, isNull);
      });
    });

    group('sortEpisodesByAirDate', () {
      test('Sorts episodes by season and episode number (most recent first)', () {
        final episodes = [
          createWork(
            tmdbId: 1,
            title: 'Show - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
          ),
          createWork(
            tmdbId: 2,
            title: 'Show - S03E05',
            type: WorkType.tvEpisode,
            seasonNumber: 3,
            episodeNumber: 5,
          ),
          createWork(
            tmdbId: 3,
            title: 'Show - S02E10',
            type: WorkType.tvEpisode,
            seasonNumber: 2,
            episodeNumber: 10,
          ),
        ];

        final sorted = TvShowDisplayLogic.sortEpisodesByAirDate(episodes);

        expect(sorted[0].seasonNumber, equals(3));
        expect(sorted[0].episodeNumber, equals(5));
        expect(sorted[1].seasonNumber, equals(2));
        expect(sorted[1].episodeNumber, equals(10));
        expect(sorted[2].seasonNumber, equals(1));
        expect(sorted[2].episodeNumber, equals(1));
      });

      test('Handles null season and episode numbers', () {
        final episodes = [
          createWork(
            tmdbId: 1,
            title: 'Show - S01E01',
            type: WorkType.tvEpisode,
            seasonNumber: 1,
            episodeNumber: 1,
          ),
          createWork(
            tmdbId: 2,
            title: 'Show - Unknown',
            type: WorkType.tvEpisode,
            seasonNumber: null,
            episodeNumber: null,
          ),
          createWork(
            tmdbId: 3,
            title: 'Show - S02E05',
            type: WorkType.tvEpisode,
            seasonNumber: 2,
            episodeNumber: 5,
          ),
        ];

        final sorted = TvShowDisplayLogic.sortEpisodesByAirDate(episodes);

        // Null values are treated as 0, so they come first (most recent first means highest numbers first)
        expect(sorted[0].seasonNumber, equals(2));
        expect(sorted[1].seasonNumber, equals(1));
        expect(sorted[2].seasonNumber, isNull);
      });
    });
  });
}
