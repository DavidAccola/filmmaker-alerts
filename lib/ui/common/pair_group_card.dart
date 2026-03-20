import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/contributor.dart';
import '../../logic/connections_models.dart';
import 'connection_work_card.dart';

/// Role importance rank to short label mapping.
const _roleImportanceLabels = {
  0: 'Director',
  1: 'Creator',
  2: 'Writer',
  3: 'Producer',
  4: 'Lead Cast',
  5: 'Supporting Cast',
  6: 'Composer',
  7: 'Crew',
  8: 'Company',
};

/// An expandable card for a PairGroup in the Discovery section.
/// Collapsed view shows two contributor avatars + names, work count,
/// and highest role importance indicator. Expands to show individual
/// ConnectionWorkCard widgets for each work.
class PairGroupCard extends StatefulWidget {
  final PairGroup pairGroup;

  /// Optional callback for adding a work to the watchlist (Discovery mode).
  /// Passed through to child ConnectionWorkCard widgets.
  final void Function(ConnectionWork work)? onAddToWatchlist;

  const PairGroupCard({
    super.key,
    required this.pairGroup,
    this.onAddToWatchlist,
  });

  @override
  State<PairGroupCard> createState() => _PairGroupCardState();
}

class _PairGroupCardState extends State<PairGroupCard> {
  late bool _expanded;

  PairGroup get pairGroup => widget.pairGroup;

  @override
  void initState() {
    super.initState();
    _expanded = pairGroup.isExpanded;
  }

  @override
  void didUpdateWidget(covariant PairGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-expand when the isExpanded flag changes (e.g. person filter)
    if (widget.pairGroup.isExpanded && !_expanded) {
      _expanded = true;
    }
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
          // Collapsed header — always visible
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Two contributor avatars
                  _buildAvatarPair(theme),
                  const SizedBox(width: 10),
                  // Names + work count + role importance
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
          // Expanded content — individual work cards
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: pairGroup.works
                    .map((work) => ConnectionWorkCard(
                          work: work,
                          onAddToWatchlist: widget.onAddToWatchlist,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Overlapping contributor avatars (supports N contributors).
  Widget _buildAvatarPair(ThemeData theme) {
    final contributors = pairGroup.contributors;
    final count = contributors.length;
    final width = 36.0 + (count - 1) * 16.0;

    return SizedBox(
      width: width,
      height: 36,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * 16.0,
              child: _buildAvatar(theme, contributors[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, MatchedContributor contributor) {
    final isCompany = contributor.contributorType == ContributorType.company;
    final companyBgColor = theme.brightness == Brightness.dark
        ? Colors.grey[300]!
        : Colors.white;
    return CircleAvatar(
      radius: 18,
      backgroundColor: isCompany
          ? companyBgColor
          : theme.colorScheme.surfaceContainerHighest,
      backgroundImage: contributor.profilePath != null && !isCompany
          ? CachedNetworkImageProvider(
              'https://image.tmdb.org/t/p/w45${contributor.profilePath}',
            )
          : null,
      child: contributor.profilePath != null && isCompany
          ? ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CachedNetworkImage(
                  imageUrl:
                      'https://image.tmdb.org/t/p/w45${contributor.profilePath}',
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => Icon(Icons.business,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : contributor.profilePath == null
              ? Icon(
                  isCompany ? Icons.business : Icons.person,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
    );
  }

  /// Names, work count label, and highest role importance indicator.
  Widget _buildInfo(ThemeData theme) {
    final roleLabel =
        _roleImportanceLabels[pairGroup.highestRoleImportance] ?? 'Crew';
    final names = pairGroup.contributors.map((c) => c.name).join(' & ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          names,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              pairGroup.contributors.length >= 3
                  ? '${pairGroup.contributors.length} people · ${pairGroup.works.length} works together'
                  : '${pairGroup.works.length} works together',
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
}
