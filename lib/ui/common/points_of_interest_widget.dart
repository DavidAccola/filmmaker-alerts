import 'package:flutter/material.dart';
import '../../data/models/contributor_detail.dart';
import '../../data/models/contributor.dart';

/// Widget that displays other followed contributors involved in a work
/// Shows connections between followed contributors
class PointsOfInterestWidget extends StatelessWidget {
  /// The work to scan for other followed contributors
  final Work work;

  /// List of all followed contributors to check against
  final List<Contributor> followedContributors;

  /// Callback when a contributor is tapped
  final Function(Contributor)? onContributorTapped;

  const PointsOfInterestWidget({
    super.key,
    required this.work,
    required this.followedContributors,
    this.onContributorTapped,
  });

  /// Finds other followed contributors in the work's cast/crew
  /// Returns a map of contributor to their roles in this work
  Map<Contributor, List<String>> _findFollowedContributorsInWork() {
    final result = <Contributor, List<String>>{};

    // Scan through all contributor roles in the work
    for (final role in work.contributorRoles) {
      // Find if this contributor is in the followed list
      Contributor? followedContributor;
      try {
        followedContributor = followedContributors.firstWhere(
          (c) => c.tmdbId == role.contributorId,
        );
      } catch (_) {
        // Contributor not found in followed list
        followedContributor = null;
      }

      if (followedContributor != null) {
        // Add or append the role
        if (result.containsKey(followedContributor)) {
          result[followedContributor]!.add(role.role);
        } else {
          result[followedContributor] = [role.role];
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final followedInWork = _findFollowedContributorsInWork();

    // Don't show the widget if no followed contributors are in this work
    if (followedInWork.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.people,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Points of Interest',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of followed contributors in this work
        ...followedInWork.entries.map((entry) {
          final contributor = entry.key;
          final roles = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildContributorTile(context, contributor, roles),
          );
        }),
      ],
    );
  }

  /// Builds a tile for a followed contributor showing their roles
  Widget _buildContributorTile(
    BuildContext context,
    Contributor contributor,
    List<String> roles,
  ) {
    // Remove duplicates and join roles
    final uniqueRoles = roles.toSet().toList();
    final rolesText = uniqueRoles.join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onContributorTapped?.call(contributor),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Contributor avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: contributor.profilePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w200${contributor.profilePath}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, size: 20),
                        ),
                      )
                    : const Icon(Icons.person, size: 20),
              ),
              const SizedBox(width: 12),

              // Contributor name and roles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contributor.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rolesText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
