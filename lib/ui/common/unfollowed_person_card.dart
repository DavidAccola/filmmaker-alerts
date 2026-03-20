import 'package:flutter/material.dart';
import '../../data/models/contributor_detail.dart';
import '../../logic/connections_models.dart';

/// Role importance rank to short label mapping.
const _roleImportanceLabels = {
  0: 'Director',
  1: 'Creator',
  2: 'Writer',
  3: 'Producer',
  4: 'Lead Cast',
  5: 'Cast',
  6: 'Composer',
  7: 'Crew',
};

/// An expandable card for an unfollowed person who appears across
/// multiple watchlist works. Similar to PairGroupCard but person-centric.
class UnfollowedPersonCard extends StatefulWidget {
  final UnfollowedPersonGroup personGroup;

  const UnfollowedPersonCard({
    super.key,
    required this.personGroup,
  });

  @override
  State<UnfollowedPersonCard> createState() => _UnfollowedPersonCardState();
}

class _UnfollowedPersonCardState extends State<UnfollowedPersonCard> {
  late bool _expanded;

  UnfollowedPersonGroup get group => widget.personGroup;

  @override
  void initState() {
    super.initState();
    _expanded = group.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Person avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + work count + role badge
                  Expanded(child: _buildInfo(theme)),
                  // Expand/collapse icon
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content — individual work rows
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                children: group.works
                    .map((work) => _buildWorkRow(theme, work))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo(ThemeData theme) {
    final roleLabel =
        _roleImportanceLabels[group.bestRoleImportance] ?? 'Crew';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              '${group.works.length} watchlist works',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkRow(ThemeData theme, UnfollowedPersonWork work) {
    final icon = work.type == WorkType.tvShow ? Icons.tv : Icons.movie;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              work.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            work.role,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
