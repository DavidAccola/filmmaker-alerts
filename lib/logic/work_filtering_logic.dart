import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../core/tmdb_mapping.dart';

/// Logic for filtering works based on followed roles
/// Ensures works are displayed only when they match the user's followed roles
class WorkFilteringLogic {
  /// Filters works to show only those matching followed roles
  /// Returns filtered list or empty list if no matches
  /// 
  /// **Validates: Requirements 1.1, 1.2, 5.1, 5.2, 5.3**
  static List<Work> filterWorksByFollowedRoles(
    List<Work> works,
    Contributor contributor,
  ) {
    // If following all roles, return all works
    if (contributor.allRolesSelected ?? false) {
      return works;
    }

    // If no followed roles, return empty list
    if (contributor.notifyForDepartments.isEmpty) {
      return [];
    }

    // Filter works to only those matching followed roles
    return works.where((work) {
      return workMatchesFollowedRoles(work, contributor);
    }).toList();
  }

  /// Checks if a work matches any of the followed roles
  /// Returns true if the contributor has at least one role in the work
  /// that matches a followed role
  /// 
  /// **Validates: Requirements 5.2, 7.1, 7.2, 7.3**
  static bool workMatchesFollowedRoles(
    Work work,
    Contributor contributor,
  ) {
    // If following all roles, all works match
    if (contributor.allRolesSelected ?? false) {
      return true;
    }

    final followedRoles = contributor.notifyForDepartments;

    // Check if any contributor role in the work matches a followed role
    for (final role in work.contributorRoles) {
      final mappedRole = TmdbMapping.mapTmdbDeptToRole(
        role.department ?? '',
        job: role.role,
      );
      
      if (followedRoles.contains(mappedRole)) {
        return true;
      }
    }

    return false;
  }

  /// Determines if filtering should be applied
  /// Returns false if filtering would result in empty list
  /// 
  /// **Validates: Requirements 2.1, 2.2, 3.1**
  static bool shouldApplyFiltering(
    List<Work> works,
    Contributor contributor,
  ) {
    // If following all roles, filtering is not applicable
    if (contributor.allRolesSelected ?? false) {
      return false;
    }

    // If no followed roles, filtering is not applicable
    if (contributor.notifyForDepartments.isEmpty) {
      return false;
    }

    // If no works, filtering is not applicable
    if (works.isEmpty) {
      return false;
    }

    // Check if filtering would result in any works
    final filtered = filterWorksByFollowedRoles(works, contributor);
    return filtered.isNotEmpty;
  }

  /// Gets the reason why filtering is disabled (if applicable)
  /// Returns null if filtering is applicable
  /// 
  /// **Validates: Requirement 2.4**
  static String? getFilterDisabledReason(
    List<Work> works,
    Contributor contributor,
  ) {
    // If following all roles, filtering is not applicable
    if (contributor.allRolesSelected ?? false) {
      return null;
    }

    // If no followed roles, filtering is not applicable
    if (contributor.notifyForDepartments.isEmpty) {
      return null;
    }

    // If no works, filtering is not applicable
    if (works.isEmpty) {
      return null;
    }

    // Check if filtering would result in any works
    final filtered = filterWorksByFollowedRoles(works, contributor);
    if (filtered.isEmpty) {
      // Build role list string
      final roleList = contributor.notifyForDepartments.join(', ');
      return 'No works found for followed roles ($roleList). Showing all works.';
    }

    return null;
  }

  /// Gets the list of followed roles as a formatted string
  /// Example: "Actor, Director, Producer"
  /// 
  /// **Validates: Requirement 4.5**
  static String getFollowedRolesString(Contributor contributor) {
    if (contributor.allRolesSelected ?? false) {
      return 'All Roles';
    }

    if (contributor.notifyForDepartments.isEmpty) {
      return 'No roles selected';
    }

    return contributor.notifyForDepartments.join(', ');
  }
}
