import 'package:flutter_test/flutter_test.dart';
import 'package:filmmaker_alerts/logic/work_filtering_logic.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';

void main() {
  group('WorkFilteringLogic', () {
    // Helper function to create a test contributor
    Contributor createContributor({
      required int tmdbId,
      required List<String> followedRoles,
      bool allRolesSelected = false,
    }) {
      return Contributor(
        tmdbId: tmdbId,
        name: 'Test Contributor',
        type: ContributorType.person,
        profilePath: null,
        imdbId: null,
        knownFor: 'Actor',
        notifyForDepartments: followedRoles,
        availableDepartments: followedRoles,
        allRolesSelected: allRolesSelected,
      );
    }

    // Helper function to create a test work
    Work createWork({
      required int tmdbId,
      required String title,
      required List<ContributorRole> roles,
      WorkType type = WorkType.movie,
    }) {
      return Work(
        tmdbId: tmdbId,
        title: title,
        type: type,
        contributorRoles: roles,
      );
    }

    // Helper function to create a contributor role
    ContributorRole createRole({
      required String role,
      String? department,
    }) {
      return ContributorRole(
        contributorId: 1,
        contributorName: 'Test',
        role: role,
        department: department,
      );
    }

    group('filterWorksByFollowedRoles', () {
      test('returns all works when following all roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
          allRolesSelected: true,
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Movie 2',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 2);
      });

      test('returns empty list when no followed roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: [],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 0);
      });

      test('filters works by single followed role', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Movie 2',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 1);
        expect(filtered[0].title, 'Movie 1');
      });

      test('filters works by multiple followed roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor', 'Director'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Movie 2',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
          createWork(
            tmdbId: 3,
            title: 'Movie 3',
            roles: [createRole(role: 'Producer', department: 'Production')],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 2);
        expect(filtered.map((w) => w.title).toList(), ['Movie 1', 'Movie 2']);
      });

      test('includes work with multiple roles if any match', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Director'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [
              createRole(role: 'Actor', department: 'Acting'),
              createRole(role: 'Director', department: 'Directing'),
            ],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 1);
      });

      test('handles works with no contributor roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 0);
      });

      test('handles empty works list', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles([], contributor);
        expect(filtered.length, 0);
      });

      test('handles mixed work types consistently', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            type: WorkType.movie,
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Show 1',
            type: WorkType.tvShow,
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
          createWork(
            tmdbId: 3,
            title: 'Episode 1',
            type: WorkType.tvEpisode,
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        final filtered = WorkFilteringLogic.filterWorksByFollowedRoles(works, contributor);
        expect(filtered.length, 3);
      });
    });

    group('workMatchesFollowedRoles', () {
      test('returns true when work matches followed role', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final work = createWork(
          tmdbId: 1,
          title: 'Movie 1',
          roles: [createRole(role: 'Actor', department: 'Acting')],
        );

        expect(WorkFilteringLogic.workMatchesFollowedRoles(work, contributor), true);
      });

      test('returns false when work does not match followed role', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final work = createWork(
          tmdbId: 1,
          title: 'Movie 1',
          roles: [createRole(role: 'Director', department: 'Directing')],
        );

        expect(WorkFilteringLogic.workMatchesFollowedRoles(work, contributor), false);
      });

      test('returns true when following all roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
          allRolesSelected: true,
        );

        final work = createWork(
          tmdbId: 1,
          title: 'Movie 1',
          roles: [createRole(role: 'Director', department: 'Directing')],
        );

        expect(WorkFilteringLogic.workMatchesFollowedRoles(work, contributor), true);
      });

      test('returns false when work has no roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final work = createWork(
          tmdbId: 1,
          title: 'Movie 1',
          roles: [],
        );

        expect(WorkFilteringLogic.workMatchesFollowedRoles(work, contributor), false);
      });
    });

    group('shouldApplyFiltering', () {
      test('returns false when following all roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
          allRolesSelected: true,
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        expect(WorkFilteringLogic.shouldApplyFiltering(works, contributor), false);
      });

      test('returns false when no followed roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: [],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        expect(WorkFilteringLogic.shouldApplyFiltering(works, contributor), false);
      });

      test('returns false when no works', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        expect(WorkFilteringLogic.shouldApplyFiltering([], contributor), false);
      });

      test('returns false when filtering would result in empty list', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
        ];

        expect(WorkFilteringLogic.shouldApplyFiltering(works, contributor), false);
      });

      test('returns true when filtering would produce results', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        expect(WorkFilteringLogic.shouldApplyFiltering(works, contributor), true);
      });
    });

    group('getFilterDisabledReason', () {
      test('returns null when filtering is applicable', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        expect(WorkFilteringLogic.getFilterDisabledReason(works, contributor), null);
      });

      test('returns reason when filtering would result in empty list', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
        ];

        final reason = WorkFilteringLogic.getFilterDisabledReason(works, contributor);
        expect(reason, isNotNull);
        expect(reason, contains('No works found for followed roles'));
        expect(reason, contains('Actor'));
      });

      test('includes all followed roles in reason message', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor', 'Director', 'Producer'],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Cinematographer', department: 'Camera')],
          ),
        ];

        final reason = WorkFilteringLogic.getFilterDisabledReason(works, contributor);
        expect(reason, contains('Actor, Director, Producer'));
      });

      test('returns null when following all roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
          allRolesSelected: true,
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Director', department: 'Directing')],
          ),
        ];

        expect(WorkFilteringLogic.getFilterDisabledReason(works, contributor), null);
      });

      test('returns null when no followed roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: [],
        );

        final works = [
          createWork(
            tmdbId: 1,
            title: 'Movie 1',
            roles: [createRole(role: 'Actor', department: 'Acting')],
          ),
        ];

        expect(WorkFilteringLogic.getFilterDisabledReason(works, contributor), null);
      });

      test('returns null when no works', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        expect(WorkFilteringLogic.getFilterDisabledReason([], contributor), null);
      });
    });

    group('getFollowedRolesString', () {
      test('returns "All Roles" when following all roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
          allRolesSelected: true,
        );

        expect(WorkFilteringLogic.getFollowedRolesString(contributor), 'All Roles');
      });

      test('returns "No roles selected" when no followed roles', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: [],
        );

        expect(WorkFilteringLogic.getFollowedRolesString(contributor), 'No roles selected');
      });

      test('returns single role as string', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor'],
        );

        expect(WorkFilteringLogic.getFollowedRolesString(contributor), 'Actor');
      });

      test('returns multiple roles joined by comma', () {
        final contributor = createContributor(
          tmdbId: 1,
          followedRoles: ['Actor', 'Director', 'Producer'],
        );

        expect(
          WorkFilteringLogic.getFollowedRolesString(contributor),
          'Actor, Director, Producer',
        );
      });
    });
  });
}
