import '../data/models/notification_history.dart';

class NotificationLogic {
  static String formatTitle(List<String> movieTitles) {
    if (movieTitles.isEmpty) return '';
    if (movieTitles.length == 1) {
      return '🎬 New Release: ${movieTitles.first}';
    }
    return '🎬 ${movieTitles.length} New Releases';
  }

  static String formatBody(List<String> movieTitles, List<NotificationHistoryEntry> entries, {Function(int)? getMoviePosterPath}) {
    if (movieTitles.isEmpty) return '';
    
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
        return '📺';
      default:
        return '🎬';
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
    
    // Don't add release date cell for "+X more" indicator
    
    return releaseDates;
  }
}
