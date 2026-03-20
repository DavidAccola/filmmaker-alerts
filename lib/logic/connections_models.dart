import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';

/// A followed contributor matched to a specific work with role metadata.
class MatchedContributor {
  final int contributorId;
  final String name;
  final String? profilePath;
  final ContributorType contributorType;
  final String role;
  final int roleImportance;

  const MatchedContributor({
    required this.contributorId,
    required this.name,
    this.profilePath,
    required this.contributorType,
    required this.role,
    required this.roleImportance,
  });
}

/// An episode in the drill-down breakdown, showing ALL contributors
/// (both show-level and episode-specific).
class EpisodeBreakdownEntry {
  final int tmdbId;
  final int? showId;
  final String? showName;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final List<MatchedContributor> allContributors;
  final int connectionCount;
  final bool isPeakEpisode;

  const EpisodeBreakdownEntry({
    required this.tmdbId,
    this.showId,
    this.showName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.allContributors,
    required this.connectionCount,
    required this.isPeakEpisode,
  });
}

/// A work (movie or TV show) with connection metadata.
class ConnectionWork {
  final int tmdbId;
  final WorkType type;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;
  final double? tmdbRating;
  final int? voteCount;
  final List<StreamingOption> streamingOptions;
  final int connectionCount;
  final int highestRoleImportance;
  final List<MatchedContributor> matchedContributors;
  final bool hasImportantRoles;
  final bool isWatched;
  final String? status;
  final DateTime? endDate;
  final int? collectionId;
  final int? episodeConnectionCount;
  final int? peakEpisodeSeasonNumber;
  final int? peakEpisodeEpisodeNumber;
  final List<EpisodeBreakdownEntry> episodeBreakdown;

  const ConnectionWork({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.tmdbRating,
    this.voteCount,
    this.streamingOptions = const [],
    required this.connectionCount,
    required this.highestRoleImportance,
    required this.matchedContributors,
    required this.hasImportantRoles,
    this.isWatched = false,
    this.status,
    this.endDate,
    this.collectionId,
    this.episodeConnectionCount,
    this.peakEpisodeSeasonNumber,
    this.peakEpisodeEpisodeNumber,
    this.episodeBreakdown = const [],
  });
}

/// A group of contributors who have collaborated on multiple works.
class PairGroup {
  final List<MatchedContributor> contributors;
  final List<ConnectionWork> works;
  final int highestRoleImportance;
  final DateTime? mostRecentReleaseDate;
  bool isExpanded;

  PairGroup({
    required this.contributors,
    required this.works,
    required this.highestRoleImportance,
    this.mostRecentReleaseDate,
    this.isExpanded = false,
  });

  /// Convenience getters for backward compatibility.
  MatchedContributor get contributor1 => contributors.first;
  MatchedContributor get contributor2 =>
      contributors.length > 1 ? contributors[1] : contributors.first;
}

/// Sealed class representing either a standalone work or a pair group in Discovery.
sealed class DiscoveryItem {}

class StandaloneDiscoveryWork extends DiscoveryItem {
  final ConnectionWork work;

  StandaloneDiscoveryWork({required this.work});
}

class PairGroupDiscoveryItem extends DiscoveryItem {
  final PairGroup pairGroup;

  PairGroupDiscoveryItem({required this.pairGroup});
}

/// Summary stats for the Connections screen.
class ConnectionsStats {
  final int watchlistCount;
  final int discoveryCount;
  final int peopleCount;
  final int pendingCount;

  const ConnectionsStats({
    required this.watchlistCount,
    required this.discoveryCount,
    required this.peopleCount,
    required this.pendingCount,
  });
}

/// A contributor summary for the person filter chip bar.
class ContributorSummary {
  final int contributorId;
  final String name;
  final String? profilePath;
  final ContributorType contributorType;
  final int appearanceCount;

  const ContributorSummary({
    required this.contributorId,
    required this.name,
    this.profilePath,
    required this.contributorType,
    required this.appearanceCount,
  });
}

/// The computed result of all connection data.
class ConnectionsData {
  final List<ConnectionWork> watchlistConnections;
  final List<DiscoveryItem> discoveryItems;
  /// Watchlist works grouped by contributor set (2+ works with same people).
  final List<DiscoveryItem> watchlistItems;
  final List<ContributorSummary> chipBarContributors;
  final ConnectionsStats stats;

  const ConnectionsData({
    required this.watchlistConnections,
    required this.discoveryItems,
    required this.watchlistItems,
    required this.chipBarContributors,
    required this.stats,
  });
}

/// Release status groups for date-based sorting, matching the Watchlist pattern.
enum ReleaseStatusGroup {
  tbd,              // 0 - No release date
  upcoming,         // 1 - Release date in the future
  recentlyReleased, // 2 - Release date within the past 6 months
  ongoing,          // 3 - TV shows with "Returning Series" or "In Production"
  released,         // 4 - Movies with past release date (>6 months)
  ended,            // 5 - TV shows with "Ended" or "Canceled"
}

/// The result of sorting and grouping connection data.
class SortedConnectionsData {
  final List<DiscoveryItem> watchlistItems;
  final List<DiscoveryItem> discoveryItems;
  /// Collaborations: contributor groups with 2+ works by the same set of people.
  final List<DiscoveryItem> collaborations;
  /// Spotlight: standalone works not part of any collaboration group.
  final List<DiscoveryItem> spotlightItems;
  /// When grouping by release status, maps group → items in that group.
  /// Null when not grouping.
  final Map<ReleaseStatusGroup, List<DiscoveryItem>>? watchlistGroups;
  final Map<ReleaseStatusGroup, List<DiscoveryItem>>? discoveryGroups;

  const SortedConnectionsData({
    required this.watchlistItems,
    required this.discoveryItems,
    this.collaborations = const [],
    this.spotlightItems = const [],
    this.watchlistGroups,
    this.discoveryGroups,
  });
}

/// An unfollowed person who appears across multiple watchlist works.
/// Used in the "All Connections" mode to surface people worth following.
class UnfollowedPersonGroup {
  final int contributorId;
  final String name;
  final String? profilePath;
  /// The watchlist works this person appears in, with their role in each.
  final List<UnfollowedPersonWork> works;
  /// Best (lowest) role importance across all works.
  final int bestRoleImportance;
  bool isExpanded;

  UnfollowedPersonGroup({
    required this.contributorId,
    required this.name,
    this.profilePath,
    required this.works,
    required this.bestRoleImportance,
    this.isExpanded = false,
  });
}

/// A single watchlist work that an unfollowed person appears in.
class UnfollowedPersonWork {
  final int tmdbId;
  final WorkType type;
  final String title;
  final String? posterPath;
  final String role;
  final int roleImportance;

  const UnfollowedPersonWork({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.posterPath,
    required this.role,
    required this.roleImportance,
  });
}
