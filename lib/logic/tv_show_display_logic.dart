import '../data/models/contributor_detail.dart';

/// Logic for handling TV show specific display in contributor details
/// Handles creator credits, director episodes, and mixed roles
class TvShowDisplayLogic {
  /// Separates works into TV show creator credits and episode director credits
  /// Returns a map with 'shows' (creator credits) and 'episodes' (directed episodes)
  /// **Validates: Requirements 8.1, 8.2, 8.4**
  static Map<String, List<Work>> separateTvShowCredits(List<Work> works) {
    final shows = <Work>[];
    final episodes = <Work>[];
    
    for (final work in works) {
      if (work.type == WorkType.tvShow) {
        // Check if this is a creator credit
        final isCreator = work.contributorRoles.any((role) => 
          role.role.toLowerCase() == 'creator' ||
          role.department?.toLowerCase() == 'creator' ||
          role.role.toLowerCase() == 'created by'
        );
        
        if (isCreator) {
          shows.add(work);
        }
      } else if (work.type == WorkType.tvEpisode) {
        // Check if this is a director credit
        final isDirector = work.contributorRoles.any((role) =>
          role.role.toLowerCase() == 'director' ||
          role.department?.toLowerCase() == 'directing'
        );
        
        if (isDirector) {
          episodes.add(work);
        }
      }
    }
    
    return {
      'shows': shows,
      'episodes': episodes,
    };
  }

  /// Groups works by department then by title
  static Map<String, List<Work>> groupWorksByDepartment(List<Work> works) {
    final grouped = <String, List<Work>>{};
    
    for (final work in works) {
      for (final role in work.contributorRoles) {
        String dept;
        if (role.department != null && role.department!.isNotEmpty) {
          dept = role.department!;
        } else if (role.character != null && role.character!.isNotEmpty) {
          dept = 'Cast';
        } else {
          // Fallback for roles without department or character
          dept = 'General';
        }
        
        if (dept == 'Creator' && work.type == WorkType.tvEpisode) {
          continue; // Don't show individual episodes in Creator section
        }

        if (!grouped.containsKey(dept)) {
          grouped[dept] = [];
        }
        
        // Avoid duplicate works in the same department
        if (!grouped[dept]!.any((w) => w.tmdbId == work.tmdbId && w.type == work.type)) {
          grouped[dept]!.add(work);
        }
      }
    }

    // Special handling for Production: Collapse excessive episodes into show-level entries
    if (grouped.containsKey('Production')) {
      final productionWorks = grouped['Production']!;
      final Map<String, List<Work>> progGrouped = {};
      final List<Work> keptWorks = [];

      // Group by show title
      for (var w in productionWorks) {
        String showTitle = w.type == WorkType.tvEpisode ? extractShowTitle(w.title) : w.title;
        progGrouped.putIfAbsent(showTitle, () => []).add(w);
      }

      for (var entry in progGrouped.entries) {
        final works = entry.value;
        final showWork = works.firstWhere((w) => w.type == WorkType.tvShow, orElse: () => works.first);
        final hasShowLevel = works.any((w) => w.type == WorkType.tvShow);
        
        // If we have a show-level credit, or lots of episodes (>3), just show the show-level one
        if (hasShowLevel || works.length > 3) {
           keptWorks.add(showWork.type == WorkType.tvShow ? showWork : showWork.copyWith(
             type: WorkType.tvShow, // Synthesize show level if needed
             title: entry.key,
             seasonNumber: null,
             episodeNumber: null,
           )); 
        } else {
           // Otherwise keep the individual episodes
           keptWorks.addAll(works);
        }
      }
      grouped['Production'] = keptWorks;
    }
    
    // Sort departments by priority if needed, or alphabetically
    return grouped;
  }

  /// Separates works into TV and Movie pools
  static Map<String, List<Work>> separateCreditsByMediaType(List<Work> works) {
    return {
      'tv': works.where((w) => w.type == WorkType.tvShow || w.type == WorkType.tvEpisode).toList(),
      'movie': works.where((w) => w.type == WorkType.movie).toList(),
    };
  }

  /// Groups episodes by TV show for display
  /// Returns a map of show title to list of episodes
  static Map<String, List<Work>> groupEpisodesByShow(List<Work> episodes) {
    final grouped = <String, List<Work>>{};
    
    for (final episode in episodes) {
      // Extract show title from episode title (usually "Show Name - S01E01")
      final showTitle = extractShowTitle(episode.title);
      
      if (!grouped.containsKey(showTitle)) {
        grouped[showTitle] = [];
      }
      grouped[showTitle]!.add(episode);
    }
    
    // Sort episodes within each show by season and episode number
    for (final episodes in grouped.values) {
      episodes.sort((a, b) {
        if (a.seasonNumber != b.seasonNumber) {
          return (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        }
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });
    }
    
    return grouped;
  }

  /// Extracts show title from episode title
  /// Handles formats like "Show Name - S01E01" or "Show Name (2020) - S01E01"
  static String extractShowTitle(String episodeTitle) {
    // Try to find the FIRST dash separator for grouping
    // Format: "Show Name - S01E01 - Episode Name" -> "Show Name"
    final dashIndex = episodeTitle.indexOf(' - ');
    if (dashIndex > 0) {
      return episodeTitle.substring(0, dashIndex).trim();
    }
    
    // Fallback: search for season/episode pattern
    final match = RegExp(r'^(.*?) - S\d{2}E\d{2}').firstMatch(episodeTitle);
    if (match != null) {
      return match.group(1)?.trim() ?? episodeTitle;
    }

    return episodeTitle;
  }

  /// Formats episode information for display
  /// Returns formatted string like "S01E05 - Episode Name"
  static String formatEpisodeInfo(Work episode) {
    final season = episode.seasonNumber ?? 0;
    final episodeNum = episode.episodeNumber ?? 0;
    
    final seasonEpisode = 'S${season.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')}';
    
    // Extract episode name from title if available
    final episodeName = _extractEpisodeName(episode.title);
    
    if (episodeName.isNotEmpty) {
      return '$seasonEpisode - $episodeName';
    }
    
    return seasonEpisode;
  }

  /// Extracts episode name from full episode title
  /// Handles formats like "Show Name - S01E01 - Episode Name"
  static String _extractEpisodeName(String fullTitle) {
    // Try to find the last dash (episode name usually comes after S##E##)
    final parts = fullTitle.split(' - ');
    
    if (parts.length >= 3) {
      // Format: "Show Name - S01E01 - Episode Name"
      return parts.last.trim();
    } else if (parts.length == 2) {
      // Check if second part is episode code (S##E##)
      final secondPart = parts[1].trim();
      if (RegExp(r'^S\d{2}E\d{2}').hasMatch(secondPart)) {
        // Format: "Show Name - S01E01"
        return '';
      }
      // Format: "Show Name - Episode Name"
      return secondPart;
    }
    
    return '';
  }

  /// Checks if a contributor has both creator and director roles
  /// Returns true if they have both types of roles
  static bool hasMultipleTvRoles(List<Work> works) {
    bool hasCreator = false;
    bool hasDirector = false;
    
    for (final work in works) {
      if (work.type == WorkType.tvShow) {
        if (work.contributorRoles.any((role) => 
          role.role.toLowerCase() == 'creator' ||
          role.department?.toLowerCase() == 'creator'
        )) {
          hasCreator = true;
        }
      } else if (work.type == WorkType.tvEpisode) {
        if (work.contributorRoles.any((role) =>
          role.role.toLowerCase() == 'director' ||
          role.department?.toLowerCase() == 'directing'
        )) {
          hasDirector = true;
        }
      }
    }
    
    return hasCreator && hasDirector;
  }

  /// Sorts TV shows by release date (most recent first)
  static List<Work> sortShowsByReleaseDate(List<Work> shows) {
    final sorted = List<Work>.from(shows);
    sorted.sort((a, b) {
      if (a.releaseDate == null && b.releaseDate == null) return 0;
      if (a.releaseDate == null) return 1;
      if (b.releaseDate == null) return -1;
      return b.releaseDate!.compareTo(a.releaseDate!);
    });
    return sorted;
  }

  /// Sorts episodes by season and episode number (most recent first)
  static List<Work> sortEpisodesByAirDate(List<Work> episodes) {
    final sorted = List<Work>.from(episodes);
    sorted.sort((a, b) {
      // Sort by season first (descending)
      if (a.seasonNumber != b.seasonNumber) {
        return (b.seasonNumber ?? 0).compareTo(a.seasonNumber ?? 0);
      }
      // Then by episode number (descending)
      return (b.episodeNumber ?? 0).compareTo(a.episodeNumber ?? 0);
    });
    return sorted;
  }
}
