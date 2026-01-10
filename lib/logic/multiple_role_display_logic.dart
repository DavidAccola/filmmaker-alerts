import '../data/models/contributor_detail.dart';
import '../data/models/movie_detail.dart';

/// Logic for handling display of multiple roles for contributors in works
/// Ensures all roles are displayed clearly and completely
class MultipleRoleDisplayLogic {
  /// Extracts all roles for a specific contributor in a work
  /// Returns a list of role strings for the contributor
  /// **Validates: Requirements 8.4, 9.2**
  static List<String> getContributorRolesInWork(
    Work work,
    int contributorId,
  ) {
    final roles = <String>[];
    
    for (final role in work.contributorRoles) {
      if (role.contributorId == contributorId) {
        roles.add(role.role);
      }
    }
    
    return roles;
  }

  /// Formats multiple roles for display in a single string
  /// Joins roles with commas and "and" for the last role
  /// Example: "Director, Writer, and Producer"
  static String formatRolesForDisplay(List<String> roles) {
    if (roles.isEmpty) {
      return '';
    }
    
    if (roles.length == 1) {
      return roles[0];
    }
    
    if (roles.length == 2) {
      return '${roles[0]} and ${roles[1]}';
    }
    
    // For 3+ roles: "Role1, Role2, and Role3"
    final allButLast = roles.sublist(0, roles.length - 1).join(', ');
    return '$allButLast, and ${roles.last}';
  }

  /// Deduplicates roles (removes duplicates while preserving order)
  static List<String> deduplicateRoles(List<String> roles) {
    final seen = <String>{};
    final result = <String>[];
    
    for (final role in roles) {
      if (!seen.contains(role)) {
        seen.add(role);
        result.add(role);
      }
    }
    
    return result;
  }

  /// Normalizes role names for comparison (case-insensitive)
  /// Useful for detecting duplicate roles with different casing
  static String normalizeRoleName(String role) {
    return role.toLowerCase().trim();
  }

  /// Checks if two roles are equivalent (case-insensitive comparison)
  static bool areRolesEquivalent(String role1, String role2) {
    return normalizeRoleName(role1) == normalizeRoleName(role2);
  }

  /// Deduplicates roles using case-insensitive comparison
  /// Preserves the original casing of the first occurrence
  static List<String> deduplicateRolesCaseInsensitive(List<String> roles) {
    final seen = <String>{};
    final result = <String>[];
    
    for (final role in roles) {
      final normalized = normalizeRoleName(role);
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        result.add(role);
      }
    }
    
    return result;
  }

  /// Sorts roles by importance (common roles first)
  /// Useful for displaying most important roles first
  static List<String> sortRolesByImportance(List<String> roles) {
    const importanceOrder = [
      'director',
      'writer',
      'producer',
      'creator',
      'actor',
      'actress',
      'cinematographer',
      'editor',
      'composer',
    ];
    
    final sorted = List<String>.from(roles);
    sorted.sort((a, b) {
      final aIndex = importanceOrder.indexWhere((r) => 
        normalizeRoleName(a).contains(normalizeRoleName(r)) ||
        normalizeRoleName(r).contains(normalizeRoleName(a))
      );
      final bIndex = importanceOrder.indexWhere((r) =>
        normalizeRoleName(b).contains(normalizeRoleName(r)) ||
        normalizeRoleName(r).contains(normalizeRoleName(b))
      );
      
      // If both found in importance order, sort by importance
      if (aIndex >= 0 && bIndex >= 0) {
        return aIndex.compareTo(bIndex);
      }
      
      // If only one found, it comes first
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      
      // Otherwise, maintain original order
      return 0;
    });
    
    return sorted;
  }

  /// Groups cast members by their roles
  /// Returns a map of role to list of cast members with that role
  static Map<String, List<CastMember>> groupCastByRole(List<CastMember> cast) {
    final grouped = <String, List<CastMember>>{};
    
    for (final member in cast) {
      if (!grouped.containsKey(member.character)) {
        grouped[member.character] = [];
      }
      grouped[member.character]!.add(member);
    }
    
    return grouped;
  }

  /// Groups crew members by their job
  /// Returns a map of job to list of crew members with that job
  static Map<String, List<CrewMember>> groupCrewByJob(List<CrewMember> crew) {
    final grouped = <String, List<CrewMember>>{};
    
    for (final member in crew) {
      if (!grouped.containsKey(member.job)) {
        grouped[member.job] = [];
      }
      grouped[member.job]!.add(member);
    }
    
    return grouped;
  }

  /// Extracts all unique roles from a list of works
  /// Useful for understanding all roles a contributor has
  static List<String> extractAllUniqueRoles(List<Work> works) {
    final roles = <String>{};
    
    for (final work in works) {
      for (final role in work.contributorRoles) {
        roles.add(role.role);
      }
    }
    
    return roles.toList();
  }

  /// Counts occurrences of each role across works
  /// Returns a map of role to count
  static Map<String, int> countRoleOccurrences(List<Work> works) {
    final counts = <String, int>{};
    
    for (final work in works) {
      for (final role in work.contributorRoles) {
        counts[role.role] = (counts[role.role] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  /// Finds the most common role across works
  /// Returns the role name or empty string if no roles exist
  static String findMostCommonRole(List<Work> works) {
    final counts = countRoleOccurrences(works);
    
    if (counts.isEmpty) {
      return '';
    }
    
    String mostCommon = '';
    int maxCount = 0;
    
    counts.forEach((role, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = role;
      }
    });
    
    return mostCommon;
  }

  /// Checks if a contributor has multiple distinct roles in a work
  static bool hasMultipleRolesInWork(
    Work work,
    int contributorId,
  ) {
    final roles = getContributorRolesInWork(work, contributorId);
    return roles.length > 1;
  }

  /// Checks if a contributor has multiple distinct roles across all works
  static bool hasMultipleDistinctRoles(List<Work> works) {
    final allRoles = extractAllUniqueRoles(works);
    return allRoles.length > 1;
  }
}
