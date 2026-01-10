import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/movie_detail.dart';
import 'package:filmmaker_alerts/logic/multiple_role_display_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultipleRoleDisplayLogic', () {
    // Helper function to create test roles
    ContributorRole createRole({
      required int contributorId,
      required String role,
      String? department,
    }) {
      return ContributorRole(
        contributorId: contributorId,
        contributorName: 'Test Person',
        role: role,
        department: department,
      );
    }

    // Helper function to create test works
    Work createWork({
      required int tmdbId,
      required String title,
      required WorkType type,
      List<ContributorRole>? roles,
    }) {
      return Work(
        tmdbId: tmdbId,
        title: title,
        type: type,
        contributorRoles: roles ?? [],
      );
    }

    group('getContributorRolesInWork', () {
      test('Property 12: Multiple Role Display - Returns all roles for a contributor in a work', () {
        // **Property 12: Multiple Role Display**
        // **Validates: Requirements 8.4, 9.2**
        
        // Property test with 100 iterations covering different role combinations
        for (int i = 0; i < 100; i++) {
          final contributorId = 1;
          final roles = <ContributorRole>[
            createRole(contributorId: contributorId, role: 'Director'),
            createRole(contributorId: contributorId, role: 'Writer'),
            createRole(contributorId: contributorId, role: 'Producer'),
            createRole(contributorId: 2, role: 'Actor'), // Different contributor
            createRole(contributorId: contributorId, role: 'Editor'),
          ];
          
          final work = createWork(
            tmdbId: 100 + i,
            title: 'Test Work $i',
            type: WorkType.movie,
            roles: roles,
          );

          final result = MultipleRoleDisplayLogic.getContributorRolesInWork(work, contributorId);

          // Should return exactly 4 roles for contributor 1
          expect(result.length, equals(4),
            reason: 'Should return all 4 roles for contributor 1');
          
          // Should contain all expected roles
          expect(result.contains('Director'), equals(true),
            reason: 'Should contain Director role');
          expect(result.contains('Writer'), equals(true),
            reason: 'Should contain Writer role');
          expect(result.contains('Producer'), equals(true),
            reason: 'Should contain Producer role');
          expect(result.contains('Editor'), equals(true),
            reason: 'Should contain Editor role');
          
          // Should not contain roles from other contributors
          expect(result.contains('Actor'), equals(false),
            reason: 'Should not contain Actor role from different contributor');
        }
      });

      test('Returns empty list when contributor has no roles in work', () {
        final work = createWork(
          tmdbId: 1,
          title: 'Test Work',
          type: WorkType.movie,
          roles: [
            createRole(contributorId: 2, role: 'Director'),
          ],
        );

        final result = MultipleRoleDisplayLogic.getContributorRolesInWork(work, 1);

        expect(result, isEmpty);
      });

      test('Returns single role when contributor has one role', () {
        final work = createWork(
          tmdbId: 1,
          title: 'Test Work',
          type: WorkType.movie,
          roles: [
            createRole(contributorId: 1, role: 'Director'),
          ],
        );

        final result = MultipleRoleDisplayLogic.getContributorRolesInWork(work, 1);

        expect(result.length, equals(1));
        expect(result[0], equals('Director'));
      });
    });

    group('formatRolesForDisplay', () {
      test('Formats single role correctly', () {
        final formatted = MultipleRoleDisplayLogic.formatRolesForDisplay(['Director']);
        expect(formatted, equals('Director'));
      });

      test('Formats two roles with "and"', () {
        final formatted = MultipleRoleDisplayLogic.formatRolesForDisplay(['Director', 'Writer']);
        expect(formatted, equals('Director and Writer'));
      });

      test('Formats three roles with commas and "and"', () {
        final formatted = MultipleRoleDisplayLogic.formatRolesForDisplay(['Director', 'Writer', 'Producer']);
        expect(formatted, equals('Director, Writer, and Producer'));
      });

      test('Formats four roles correctly', () {
        final formatted = MultipleRoleDisplayLogic.formatRolesForDisplay(['Director', 'Writer', 'Producer', 'Editor']);
        expect(formatted, equals('Director, Writer, Producer, and Editor'));
      });

      test('Returns empty string for empty list', () {
        final formatted = MultipleRoleDisplayLogic.formatRolesForDisplay([]);
        expect(formatted, equals(''));
      });
    });

    group('deduplicateRoles', () {
      test('Removes duplicate roles while preserving order', () {
        final roles = ['Director', 'Writer', 'Director', 'Producer', 'Writer'];
        final result = MultipleRoleDisplayLogic.deduplicateRoles(roles);
        
        expect(result.length, equals(3));
        expect(result, equals(['Director', 'Writer', 'Producer']));
      });

      test('Returns same list when no duplicates', () {
        final roles = ['Director', 'Writer', 'Producer'];
        final result = MultipleRoleDisplayLogic.deduplicateRoles(roles);
        
        expect(result, equals(roles));
      });

      test('Handles empty list', () {
        final result = MultipleRoleDisplayLogic.deduplicateRoles([]);
        expect(result, isEmpty);
      });
    });

    group('normalizeRoleName', () {
      test('Converts to lowercase', () {
        expect(MultipleRoleDisplayLogic.normalizeRoleName('DIRECTOR'), equals('director'));
      });

      test('Trims whitespace', () {
        expect(MultipleRoleDisplayLogic.normalizeRoleName('  Director  '), equals('director'));
      });

      test('Handles mixed case', () {
        expect(MultipleRoleDisplayLogic.normalizeRoleName('DiReCtOr'), equals('director'));
      });
    });

    group('areRolesEquivalent', () {
      test('Returns true for same role with different casing', () {
        expect(
          MultipleRoleDisplayLogic.areRolesEquivalent('Director', 'DIRECTOR'),
          equals(true),
        );
      });

      test('Returns true for same role with whitespace', () {
        expect(
          MultipleRoleDisplayLogic.areRolesEquivalent('  Director  ', 'director'),
          equals(true),
        );
      });

      test('Returns false for different roles', () {
        expect(
          MultipleRoleDisplayLogic.areRolesEquivalent('Director', 'Writer'),
          equals(false),
        );
      });
    });

    group('deduplicateRolesCaseInsensitive', () {
      test('Removes case-insensitive duplicates', () {
        final roles = ['Director', 'DIRECTOR', 'Writer', 'writer', 'Producer'];
        final result = MultipleRoleDisplayLogic.deduplicateRolesCaseInsensitive(roles);
        
        expect(result.length, equals(3));
        expect(result[0], equals('Director')); // Preserves first occurrence casing
        expect(result[1], equals('Writer'));
        expect(result[2], equals('Producer'));
      });

      test('Preserves original casing of first occurrence', () {
        final roles = ['DIRECTOR', 'director', 'Director'];
        final result = MultipleRoleDisplayLogic.deduplicateRolesCaseInsensitive(roles);
        
        expect(result.length, equals(1));
        expect(result[0], equals('DIRECTOR'));
      });
    });

    group('sortRolesByImportance', () {
      test('Sorts roles by importance order', () {
        final roles = ['Actor', 'Director', 'Writer', 'Producer'];
        final result = MultipleRoleDisplayLogic.sortRolesByImportance(roles);
        
        expect(result[0], equals('Director'));
        expect(result[1], equals('Writer'));
        expect(result[2], equals('Producer'));
        expect(result[3], equals('Actor'));
      });

      test('Handles unknown roles', () {
        final roles = ['Director', 'UnknownRole', 'Writer'];
        final result = MultipleRoleDisplayLogic.sortRolesByImportance(roles);
        
        // Director and Writer should be sorted by importance
        expect(result[0], equals('Director'));
        expect(result[1], equals('Writer'));
        // UnknownRole should be at the end
        expect(result[2], equals('UnknownRole'));
      });

      test('Handles case-insensitive matching', () {
        final roles = ['DIRECTOR', 'writer', 'Producer'];
        final result = MultipleRoleDisplayLogic.sortRolesByImportance(roles);
        
        expect(result[0], equals('DIRECTOR'));
        expect(result[1], equals('writer'));
        expect(result[2], equals('Producer'));
      });
    });

    group('groupCastByRole', () {
      test('Groups cast members by character role', () {
        final cast = [
          CastMember(tmdbId: 1, name: 'Actor 1', character: 'Hero', order: 0),
          CastMember(tmdbId: 2, name: 'Actor 2', character: 'Villain', order: 1),
          CastMember(tmdbId: 3, name: 'Actor 3', character: 'Hero', order: 2),
        ];

        final grouped = MultipleRoleDisplayLogic.groupCastByRole(cast);

        expect(grouped.length, equals(2));
        expect(grouped['Hero']?.length, equals(2));
        expect(grouped['Villain']?.length, equals(1));
      });

      test('Handles empty cast list', () {
        final grouped = MultipleRoleDisplayLogic.groupCastByRole([]);
        expect(grouped, isEmpty);
      });
    });

    group('groupCrewByJob', () {
      test('Groups crew members by job', () {
        final crew = [
          CrewMember(tmdbId: 1, name: 'Person 1', job: 'Director', department: 'Directing'),
          CrewMember(tmdbId: 2, name: 'Person 2', job: 'Writer', department: 'Writing'),
          CrewMember(tmdbId: 3, name: 'Person 3', job: 'Director', department: 'Directing'),
        ];

        final grouped = MultipleRoleDisplayLogic.groupCrewByJob(crew);

        expect(grouped.length, equals(2));
        expect(grouped['Director']?.length, equals(2));
        expect(grouped['Writer']?.length, equals(1));
      });

      test('Handles empty crew list', () {
        final grouped = MultipleRoleDisplayLogic.groupCrewByJob([]);
        expect(grouped, isEmpty);
      });
    });

    group('extractAllUniqueRoles', () {
      test('Extracts all unique roles from works', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Work 1',
            type: WorkType.movie,
            roles: [
              createRole(contributorId: 1, role: 'Director'),
              createRole(contributorId: 1, role: 'Writer'),
            ],
          ),
          createWork(
            tmdbId: 2,
            title: 'Work 2',
            type: WorkType.movie,
            roles: [
              createRole(contributorId: 1, role: 'Producer'),
              createRole(contributorId: 1, role: 'Director'),
            ],
          ),
        ];

        final roles = MultipleRoleDisplayLogic.extractAllUniqueRoles(works);

        expect(roles.length, equals(3));
        expect(roles.contains('Director'), equals(true));
        expect(roles.contains('Writer'), equals(true));
        expect(roles.contains('Producer'), equals(true));
      });

      test('Returns empty list when no works', () {
        final roles = MultipleRoleDisplayLogic.extractAllUniqueRoles([]);
        expect(roles, isEmpty);
      });
    });

    group('countRoleOccurrences', () {
      test('Counts role occurrences across works', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Work 1',
            type: WorkType.movie,
            roles: [
              createRole(contributorId: 1, role: 'Director'),
              createRole(contributorId: 1, role: 'Writer'),
            ],
          ),
          createWork(
            tmdbId: 2,
            title: 'Work 2',
            type: WorkType.movie,
            roles: [
              createRole(contributorId: 1, role: 'Producer'),
              createRole(contributorId: 1, role: 'Director'),
            ],
          ),
        ];

        final counts = MultipleRoleDisplayLogic.countRoleOccurrences(works);

        expect(counts['Director'], equals(2));
        expect(counts['Writer'], equals(1));
        expect(counts['Producer'], equals(1));
      });
    });

    group('findMostCommonRole', () {
      test('Finds most common role across works', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Work 1',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Director')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Work 2',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Director')],
          ),
          createWork(
            tmdbId: 3,
            title: 'Work 3',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Writer')],
          ),
        ];

        final mostCommon = MultipleRoleDisplayLogic.findMostCommonRole(works);

        expect(mostCommon, equals('Director'));
      });

      test('Returns empty string when no roles', () {
        final mostCommon = MultipleRoleDisplayLogic.findMostCommonRole([]);
        expect(mostCommon, equals(''));
      });
    });

    group('hasMultipleRolesInWork', () {
      test('Returns true when contributor has multiple roles in work', () {
        final work = createWork(
          tmdbId: 1,
          title: 'Test Work',
          type: WorkType.movie,
          roles: [
            createRole(contributorId: 1, role: 'Director'),
            createRole(contributorId: 1, role: 'Writer'),
          ],
        );

        final result = MultipleRoleDisplayLogic.hasMultipleRolesInWork(work, 1);

        expect(result, equals(true));
      });

      test('Returns false when contributor has single role in work', () {
        final work = createWork(
          tmdbId: 1,
          title: 'Test Work',
          type: WorkType.movie,
          roles: [
            createRole(contributorId: 1, role: 'Director'),
          ],
        );

        final result = MultipleRoleDisplayLogic.hasMultipleRolesInWork(work, 1);

        expect(result, equals(false));
      });

      test('Returns false when contributor has no roles in work', () {
        final work = createWork(
          tmdbId: 1,
          title: 'Test Work',
          type: WorkType.movie,
          roles: [
            createRole(contributorId: 2, role: 'Director'),
          ],
        );

        final result = MultipleRoleDisplayLogic.hasMultipleRolesInWork(work, 1);

        expect(result, equals(false));
      });
    });

    group('hasMultipleDistinctRoles', () {
      test('Returns true when contributor has multiple distinct roles across works', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Work 1',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Director')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Work 2',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Writer')],
          ),
        ];

        final result = MultipleRoleDisplayLogic.hasMultipleDistinctRoles(works);

        expect(result, equals(true));
      });

      test('Returns false when contributor has only one distinct role', () {
        final works = [
          createWork(
            tmdbId: 1,
            title: 'Work 1',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Director')],
          ),
          createWork(
            tmdbId: 2,
            title: 'Work 2',
            type: WorkType.movie,
            roles: [createRole(contributorId: 1, role: 'Director')],
          ),
        ];

        final result = MultipleRoleDisplayLogic.hasMultipleDistinctRoles(works);

        expect(result, equals(false));
      });

      test('Returns false when no works', () {
        final result = MultipleRoleDisplayLogic.hasMultipleDistinctRoles([]);
        expect(result, equals(false));
      });
    });
  });
}
