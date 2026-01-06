import '../data/models/notification_history.dart';

class NotificationLogic {
  static String formatTitle(List<String> movieTitles, {List<NotificationHistoryEntry>? entries}) {
    if (movieTitles.isEmpty) return '';
    
    // Check if this is mixed content or pure TV content
    if (entries != null && entries.isNotEmpty) {
      final tvCount = entries.where((e) => e.mediaType == 'tv').length;
      final movieCount = entries.length - tvCount;
      
      // Mixed content - use generic "New Releases" format
      if (tvCount > 0 && movieCount > 0) {
        if (entries.length == 1) {
          return '🎬 New Release: ${movieTitles.first}';
        }
        return '🎬 ${entries.length} New Releases';
      }
      
      // Pure TV content - use TV-specific format
      if (tvCount > 0 && movieCount == 0) {
        return formatTvTitle(movieTitles, entries);
      }
    }
    
    // Original movie logic (pure movies or fallback)
    if (movieTitles.length == 1) {
      return '🎬 New Release: ${movieTitles.first}';
    }
    return '🎬 ${movieTitles.length} New Releases';
  }

  static String formatBody(List<String> movieTitles, List<NotificationHistoryEntry> entries, {Function(int)? getMoviePosterPath}) {
    if (movieTitles.isEmpty) return '';
    
    // Check if this is mixed content or pure TV content
    final tvCount = entries.where((e) => e.mediaType == 'tv').length;
    final movieCount = entries.length - tvCount;
    
    // Mixed content - use generic format with TV emoji prefix for TV dates
    if (tvCount > 0 && movieCount > 0) {
      return formatMixedBody(movieTitles, entries);
    }
    
    // Pure TV content - use TV-specific format
    if (tvCount > 0 && movieCount == 0) {
      return formatTvBody(movieTitles, entries);
    }
    
    // Original movie logic (pure movies)
    if (movieTitles.length == 1) {
      final entry = entries.first;
      final List<String> lines = [];
      
      // Add release date first if available
      final releaseDate = entry.notificationEvents.first.releaseDate;
      if (releaseDate.isNotEmpty) {
        // Format date as MM/DD/YYYY with emoji prefix and existing text
        final formattedDate = _formatDateForNotification(releaseDate);
        final releaseType = entry.notificationEvents.first.releaseType;
        final emoji = _getReleaseTypeEmoji(releaseType);
        final typePrefix = _getReleaseTypePrefix(releaseType);
        lines.add('$emoji $typePrefix $formattedDate');
        
        // Add small spacing if we have contributors coming next
        if (entry.reasons.isNotEmpty) {
          lines.add(''); // Empty line for spacing
        }
      }
      
      // Add contributor info only for people, not movies/companies/collections
      final Set<String> contributorinfo = {};
      
      // Group jobs by contributor name
      final Map<String, List<String>> grouped = {};
      for (var reason in entry.reasons) {
        if (!grouped.containsKey(reason.contributorName)) {
          grouped[reason.contributorName] = [];
        }
        if (reason.job != null && !grouped[reason.contributorName]!.contains(reason.job!)) {
          grouped[reason.contributorName]!.add(reason.job!);
        }
      }

      // Only add contributor lines for people (not for movies/companies/collections)
      bool hasPersonContributors = false;
      
      // Group people by identical role sets for combining
      final Map<String, List<String>> roleGroups = {}; // roles -> [names]
      
      grouped.forEach((name, jobs) {
        // Check if this is a person contributor (has jobs like Director, Writer, etc.)
        if (jobs.any((job) => ['Director', 'Writer', 'Producer', 'Actor', 'Actress', 'Creator'].contains(job))) {
          hasPersonContributors = true;
          final rolesKey = jobs.join(', ');
          roleGroups.putIfAbsent(rolesKey, () => []).add(name);
        }
      });
      
      // Format grouped contributors
      roleGroups.forEach((roles, names) {
        String namesList;
        if (names.length == 1) {
          namesList = names.first;
        } else if (names.length == 2) {
          namesList = '${names[0]} & ${names[1]}';
        } else {
          namesList = names.join(', ');
        }
        
        // Estimate if text would be too long (rough character limit for notifications)
        final fullText = '$namesList - $roles';
        if (fullText.length > 60) {
          // Too long, put each person on separate line
          for (final name in names) {
            lines.add('$name - $roles');
          }
        } else {
          lines.add('$namesList - $roles');
        }
      });

      // Add collection/company info for non-person contributors
      if (!hasPersonContributors) {
        grouped.forEach((name, jobs) {
          // Collection or company contributor
          if (jobs.contains('Collection')) {
            lines.add('${movieTitles.first} is in the $name collection');
          } else if (jobs.contains('Company')) {
            lines.add('A $name film.');
          }
        });
      }

      return lines.join('\n');
    } else if (movieTitles.length <= 3) {
      // For 2-3 movies, show compact movie list only (release dates shown in grid)
      return movieTitles.join(' • ');
    } else {
      // Multiple movies logic (4+) - prioritize movies with posters
      // Show first 3 movies that have posters, then "+X more"
      final moviesWithPosters = <String>[];
      final moviesWithoutPosters = <String>[];
      
      // Separate movies based on poster availability
      for (int i = 0; i < movieTitles.length && i < entries.length; i++) {
        final entry = entries[i];
        final posterPath = getMoviePosterPath?.call(entry.tmdbId);
        final hasValidPoster = posterPath != null && posterPath.isNotEmpty;
        
        if (hasValidPoster) {
          moviesWithPosters.add(movieTitles[i]);
        } else {
          moviesWithoutPosters.add(movieTitles[i]);
        }
      }
      
      // Build the display list: prioritize movies with posters
      final displayMovies = <String>[];
      
      // Add movies with posters first (up to 3)
      for (int i = 0; i < moviesWithPosters.length && displayMovies.length < 3; i++) {
        displayMovies.add(moviesWithPosters[i]);
      }
      
      // If we still have space, add movies without posters
      for (int i = 0; i < moviesWithoutPosters.length && displayMovies.length < 3; i++) {
        displayMovies.add(moviesWithoutPosters[i]);
      }
      
      // Calculate remaining count
      final remainingCount = movieTitles.length - displayMovies.length;
      
      if (remainingCount > 0) {
        return '${displayMovies.join(' • ')} • +$remainingCount more';
      } else {
        return displayMovies.join(' • ');
      }
    }
  }

  static String _formatDateForNotification(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  static String _getReleaseTypePrefix(String releaseType) {
    switch (releaseType.toLowerCase()) {
      case 'streaming':
      case 'digital':
        return 'Streaming';
      case 'theatrical':
        return 'In theatres';
      case 'theatrical (limited)':
      case 'premiere':
        return 'Theatrical premiere';
      case 'tv':
        return 'Airing';
      default:
        return 'Release Date:';
    }
  }

  static String _createAcronym(String title) {
    // If title has 2 or fewer words, return as-is
    final words = title.split(' ');
    if (words.length <= 2) {
      return title;
    }
    
    String acronym = '';
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      // Handle special cases
      if (word.toLowerCase() == 'and') {
        acronym += '&';
      } else if (word == '-' || word == ':') {
        acronym += word;
      } else if (word.contains('-') && word != '-') {
        // Handle hyphenated words like "Spider-Man"
        final parts = word.split('-');
        for (int j = 0; j < parts.length; j++) {
          if (parts[j].isNotEmpty) {
            acronym += parts[j][0];
          }
          if (j < parts.length - 1) {
            acronym += '-';
          }
        }
      } else if (word.contains(':') && word != ':') {
        // Handle words with colons
        final parts = word.split(':');
        for (int j = 0; j < parts.length; j++) {
          if (parts[j].isNotEmpty) {
            acronym += parts[j][0];
          }
          if (j < parts.length - 1) {
            acronym += ':';
          }
        }
      } else if (word.isNotEmpty) {
        // Regular word - take first letter, preserve capitalization
        acronym += word[0];
      }
    }
    
    return acronym;
  }

  static String _getReleaseTypeEmoji(String releaseType) {
    switch (releaseType.toLowerCase()) {
      case 'streaming':
      case 'digital':
        return '💻';
      case 'theatrical':
        return '🍿';
      case 'theatrical (limited)':
      case 'premiere':
        return '🤵🏻';
      case 'tv':
      case 'broadcast':
      case 'air':
        return '📺';
      default:
        return '🎬';
    }
  }

  /// Format mixed TV and movie notification body
  static String formatMixedBody(List<String> titles, List<NotificationHistoryEntry> entries) {
    if (titles.isEmpty) return '';
    
    if (titles.length == 1) {
      final entry = entries.first;
      final List<String> lines = [];
      
      // Add release date with appropriate emoji
      if (entry.notificationEvents.isNotEmpty) {
        String releaseDate;
        String emoji;
        
        if (entry.mediaType == 'tv') {
          // For TV shows, get earliest date and use TV emoji
          final sortedEvents = List<NotificationEvent>.from(entry.notificationEvents);
          sortedEvents.sort((a, b) {
            final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime.now();
            final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime.now();
            return dateA.compareTo(dateB);
          });
          releaseDate = _formatDateForNotification(sortedEvents.first.releaseDate);
          emoji = '📺';
        } else {
          // For movies, use standard logic
          releaseDate = _formatDateForNotification(entry.notificationEvents.first.releaseDate);
          final releaseType = entry.notificationEvents.first.releaseType;
          emoji = _getReleaseTypeEmoji(releaseType);
          final typePrefix = _getReleaseTypePrefix(releaseType);
          lines.add('$emoji $typePrefix $releaseDate');
          return lines.join('\n');
        }
        
        lines.add('$emoji $releaseDate');
      }
      
      return lines.join('\n');
    } else if (titles.length <= 3) {
      // For 2-3 items, show compact list
      return titles.join(' • ');
    } else {
      // Multiple items logic (4+)
      final displayTitles = titles.take(3).toList();
      final remainingCount = titles.length - displayTitles.length;
      
      if (remainingCount > 0) {
        return '${displayTitles.join(' • ')} • +$remainingCount more';
      } else {
        return displayTitles.join(' • ');
      }
    }
  }

  /// Format TV show notification title
  static String formatTvTitle(List<String> showTitles, List<NotificationHistoryEntry> entries) {
    if (showTitles.isEmpty) return '';
    
    if (showTitles.length == 1) {
      final entry = entries.first;
      final showTitle = showTitles.first;
      
      // Count total episodes across all notification events
      int totalEpisodes = 0;
      if (entry.tvNotificationType == 'grouped_episodes' && entry.notificationEvents.length > 1) {
        // Multiple events = multiple episodes
        totalEpisodes = entry.notificationEvents.length;
      } else if (entry.episodeNumber != null && entry.episodeNumber! > 1) {
        // Single event but episodeNumber indicates multiple episodes
        totalEpisodes = entry.episodeNumber!;
      } else {
        // Single episode
        totalEpisodes = 1;
      }
      
      // Format: "New Release/Releases" + show name + episode count
      if (totalEpisodes == 1) {
        return '🎬 New Release: $showTitle (1 episode)';
      } else {
        return '🎬 New Releases: $showTitle ($totalEpisodes episodes)';
      }
    }
    
    // Multiple shows - count total episodes
    int totalEpisodes = 0;
    for (final entry in entries) {
      if (entry.tvNotificationType == 'grouped_episodes' && entry.notificationEvents.length > 1) {
        totalEpisodes += entry.notificationEvents.length;
      } else if (entry.episodeNumber != null && entry.episodeNumber! > 1) {
        totalEpisodes += entry.episodeNumber!;
      } else {
        totalEpisodes += 1;
      }
    }
    
    return '🎬 $totalEpisodes New TV Episodes';
  }

  /// Format TV show notification body
  static String formatTvBody(List<String> showTitles, List<NotificationHistoryEntry> entries) {
    if (showTitles.isEmpty) return '';
    
    if (showTitles.length == 1) {
      final entry = entries.first;
      final List<String> lines = [];
      
      // Get the earliest air date from all notification events
      String earliestDate = '';
      if (entry.notificationEvents.isNotEmpty) {
        final sortedEvents = List<NotificationEvent>.from(entry.notificationEvents);
        sortedEvents.sort((a, b) {
          final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime.now();
          final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        earliestDate = _formatDateForNotification(sortedEvents.first.releaseDate);
      }
      
      // Add TV emoji and date
      if (earliestDate.isNotEmpty) {
        lines.add('📺 $earliestDate');
      }
      
      // Only add contributor info for people (creators, directors), not for "Followed Show"
      final personReasons = entry.reasons.where((reason) => 
        reason.job != null && 
        reason.job != 'Followed Show' &&
        ['Creator', 'Director', 'Writer', 'Producer', 'Actor', 'Actress'].contains(reason.job)
      ).toList();
      
      if (personReasons.isNotEmpty) {
        lines.add(''); // Empty line for spacing
        
        final Map<String, List<String>> grouped = {};
        for (var reason in personReasons) {
          if (!grouped.containsKey(reason.contributorName)) {
            grouped[reason.contributorName] = [];
          }
          if (reason.job != null && !grouped[reason.contributorName]!.contains(reason.job!)) {
            grouped[reason.contributorName]!.add(reason.job!);
          }
        }
        
        // Group people by identical role sets for combining
        final Map<String, List<String>> roleGroups = {}; // roles -> [names]
        
        grouped.forEach((name, jobs) {
          final rolesKey = jobs.join(', ');
          roleGroups.putIfAbsent(rolesKey, () => []).add(name);
        });
        
        // Format grouped contributors
        roleGroups.forEach((roles, names) {
          String namesList;
          if (names.length == 1) {
            namesList = names.first;
          } else if (names.length == 2) {
            namesList = '${names[0]} & ${names[1]}';
          } else {
            namesList = names.join(', ');
          }
          
          // Estimate if text would be too long
          final fullText = '$namesList - $roles';
          if (fullText.length > 60) {
            // Too long, put each person on separate line
            for (final name in names) {
              lines.add('$name - $roles');
            }
          } else {
            lines.add('$namesList - $roles');
          }
        });
      }
      
      return lines.join('\n');
    } else if (showTitles.length <= 3) {
      // For 2-3 shows, show compact show list
      return showTitles.join(' • ');
    } else {
      // Multiple shows logic (4+)
      final displayShows = showTitles.take(3).toList();
      final remainingCount = showTitles.length - displayShows.length;
      
      if (remainingCount > 0) {
        return '${displayShows.join(' • ')} • +$remainingCount more';
      } else {
        return displayShows.join(' • ');
      }
    }
  }

  /// Get TV-specific release type prefix
  static String _getTvReleaseTypePrefix(String releaseType) {
    switch (releaseType.toLowerCase()) {
      case 'streaming':
      case 'digital':
        return 'Streaming';
      case 'tv':
      case 'broadcast':
      case 'air':
        return 'Airing';
      default:
        return 'Air Date:';
    }
  }

  /// Get release dates for each movie column in multi-movie notifications
  /// Each entry corresponds to one movie poster column
  static List<String> getPriorityReleaseDates(List<String> movieTitles, List<NotificationHistoryEntry> entries) {
    final List<String> releaseDates = [];
    
    // Build release dates for each movie (up to 4 movies shown as posters)
    for (int i = 0; i < movieTitles.length && i < entries.length && i < 4; i++) {
      final entry = entries[i];
      
      if (entry.notificationEvents.isEmpty) {
        releaseDates.add('');
        continue;
      }
      
      // Handle TV shows vs movies differently
      if (entry.mediaType == 'tv') {
        // For TV shows, get earliest date and use TV emoji
        final sortedEvents = List<NotificationEvent>.from(entry.notificationEvents);
        sortedEvents.sort((a, b) {
          final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime.now();
          final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        
        final date = _formatDateForNotification(sortedEvents.first.releaseDate);
        releaseDates.add('📺 $date');
      } else {
        // For movies, use existing logic
        // Get all events for this movie, sorted by date
        final events = List<NotificationEvent>.from(entry.notificationEvents);
        events.sort((a, b) {
          final dateA = DateTime.tryParse(a.releaseDate) ?? DateTime.now();
          final dateB = DateTime.tryParse(b.releaseDate) ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
        
        // Filter out duplicate dates and handle premiere/theatrical conflicts
        final Map<String, NotificationEvent> uniqueEvents = {};
        final Set<String> seenDates = {};
        
        for (final event in events) {
          final dateKey = event.releaseDate;
          
          // If we've seen this date before, check for premiere vs theatrical conflict
          if (seenDates.contains(dateKey)) {
            final existingEvent = uniqueEvents[dateKey];
            if (existingEvent != null) {
              // If one is premiere and another is theatrical with same date, keep the non-premiere
              if (existingEvent.releaseType.toLowerCase().contains('premiere') && 
                  !event.releaseType.toLowerCase().contains('premiere')) {
                uniqueEvents[dateKey] = event; // Replace premiere with theatrical
              }
              // Otherwise keep the existing one
            }
          } else {
            uniqueEvents[dateKey] = event;
            seenDates.add(dateKey);
          }
        }
        
        // Build the release date text for this movie column
        final List<String> movieReleaseDates = [];
        for (final event in uniqueEvents.values) {
          final emoji = _getReleaseTypeEmoji(event.releaseType);
          final date = _formatDateForNotification(event.releaseDate);
          movieReleaseDates.add('$emoji $date');
        }
        
        // Join multiple dates with newlines for this movie
        releaseDates.add(movieReleaseDates.join('\n'));
      }
    }
    
    return releaseDates;
  }
}
