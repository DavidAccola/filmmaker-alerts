# Design Document

## Overview

The Contributor Details feature provides comprehensive detail screens for followed contributors (people, companies, collections) and movies. The system enables deep exploration of filmographies, cast/crew information, streaming availability, and cross-references between followed contributors.

## Architecture

The feature follows a layered architecture with clear separation between UI, business logic, and data layers:

```
UI Layer (Screens & Widgets)
├── ContributorDetailScreen
├── MovieDetailScreen
├── StreamingOptionsWidget
└── PointsOfInterestWidget

Business Logic Layer
├── ContributorDetailLogic
├── MovieDetailLogic
├── StreamingLogic
└── WatchlistLogic

Data Layer
├── ContributorDetailRepository
├── MovieDetailRepository
├── StreamingRepository (JustWatch)
└── ExternalLinksRepository (TMDB/IMDB)
```

## Components and Interfaces

### ContributorDetailScreen
Primary screen for displaying person/company/collection details.

**Key Components:**
- Header with contributor info and preference toggles
- Upcoming works section with chronological ordering
- Latest releases section with theatrical/streaming indicators
- Biggest hits section with rating/popularity sorting
- Points of interest highlighting for cross-contributor connections

### MovieDetailScreen
Dedicated screen for individual movie exploration.

**Key Components:**
- Movie metadata header with expandable synopsis
- Cast section with followed contributors prioritized
- Crew section with key roles and followed contributors first
- Streaming options integration
- Watchlist and external link actions

### StreamingOptionsWidget
Reusable component for displaying streaming availability.

**Features:**
- JustWatch API integration with proper attribution
- Country-specific provider filtering
- Expandable or modal presentation options
- Provider icons and pricing information

### PointsOfInterestWidget
Shows connections between followed contributors within works.

**Logic:**
- Scans cast/crew for other followed contributors
- Displays contributor names with their specific roles
- Only renders when connections exist
- Provides navigation to related contributor details

## Data Models

### ContributorDetail
```dart
class ContributorDetail {
  final int tmdbId;
  final String name;
  final String? profilePath;
  final String? imdbId;
  final ContributorType type;
  final List<Work> upcomingWorks;
  final List<Work> latestReleases;
  final List<Work> biggestHits;
}
```

### MovieDetail
```dart
class MovieDetail {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;
  final int? runtime;
  final String synopsis;
  final double? tmdbRating;
  final double? popularity;
  final List<CastMember> cast;
  final List<CrewMember> crew;
  final String? imdbId;
}
```

### StreamingOption
```dart
class StreamingOption {
  final String providerId;
  final String providerName;
  final String? logoPath;
  final StreamingType type; // rent, buy, subscription
  final String? price;
  final String deepLink;
}
```

### Work
```dart
class Work {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;
  final WorkType type; // movie, tvShow, tvEpisode
  final double? tmdbRating;
  final double? popularity;
  final ReleaseType? releaseType; // theatrical, streaming
  final List<ContributorRole> contributorRoles;
  final List<StreamingOption> streamingOptions;
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Navigation Consistency
*For any* followed contributor or movie, clicking on it should navigate to the appropriate detail screen (contributor detail for people/companies/collections, movie detail for movies)
**Validates: Requirements 1.1, 12.1**

### Property 2: Chronological Ordering
*For any* contributor's upcoming works, they should be displayed in chronological order by release date, with unknown dates appearing last
**Validates: Requirements 2.1, 2.2**

### Property 3: Latest Releases Ordering
*For any* contributor's released works, the latest releases section should show the 10 most recent works in reverse chronological order
**Validates: Requirements 3.1**

### Property 4: Biggest Hits Ranking
*For any* contributor's works, the biggest hits section should display the top 10 works ranked by a combination of highest rating and popularity
**Validates: Requirements 4.1**

### Property 5: Watchlist Integration
*For any* work displayed in any section (upcoming, latest releases, biggest hits, movie details), users should be able to add it to their watchlist
**Validates: Requirements 2.4, 3.5, 4.3, 12.10**

### Property 6: Display Preference Consistency
*For any* detail screen, when popularity or rating hiding preferences are enabled, those elements should be hidden consistently across all sections and screen types
**Validates: Requirements 5.2, 5.3, 12.12**

### Property 7: Preference Persistence
*For any* navigation between contributor detail screens, display preferences should persist across all screens
**Validates: Requirements 5.4**

### Property 8: External Navigation
*For any* work or contributor, clicking external link buttons should open the correct TMDB or IMDB pages using the same preference logic as the notifications system
**Validates: Requirements 6.1, 6.2, 6.3, 8.3, 11.4, 12.11**

### Property 9: JustWatch Integration
*For any* work, streaming options should be provided via JustWatch API with proper attribution (branded link and logo) and country-specific filtering
**Validates: Requirements 6.5, 6.6, 10.2, 10.3, 12.9**

### Property 10: Points of Interest Detection
*For any* work, if other followed contributors are involved, a Points of Interest section should appear showing their names and roles; if none exist, the section should be hidden
**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

### Property 11: TV Show Role Handling
*For any* TV show contributor, the system should correctly display show-level credits (creator) and episode-level credits (director) with appropriate navigation
**Validates: Requirements 8.1, 8.2, 8.4**

### Property 12: Multiple Role Display
*For any* contributor with multiple roles in a work, all roles should be displayed clearly and completely
**Validates: Requirements 8.4, 9.2**

### Property 13: Movie Cast/Crew Prioritization
*For any* movie detail screen, followed contributors should appear first in both cast and crew sections with special highlighting
**Validates: Requirements 12.7, 12.8**

### Property 14: Required UI Elements
*For any* detail screen, all required UI elements should be present (header info, preference toggles, section organization, external link buttons)
**Validates: Requirements 1.2, 1.3, 1.4, 5.1, 11.1, 11.2**

### Property 15: Data Caching Consistency
*For any* contributor detail data, caching should work consistently to avoid redundant API calls while maintaining data freshness
**Validates: Requirements 13.2**

### Property 16: IMDB ID Collection
*For any* person during release checking, IMDB IDs should be retrieved and stored for later use in detail screens
**Validates: Requirements 11.3, 13.4**

## Error Handling

The system handles various error conditions gracefully:

- **API Failures**: When TMDB, IMDB, or JustWatch APIs are unavailable, the system displays cached data or appropriate error messages
- **Missing Data**: When contributor data is incomplete (no poster, unknown release dates), the system provides sensible defaults
- **Network Issues**: Offline functionality maintains basic navigation and cached content
- **Invalid Contributors**: Non-existent or deleted contributors show appropriate error screens

## Testing Strategy

The feature uses a dual testing approach combining unit tests and property-based tests:

**Unit Tests:**
- Specific examples of contributor detail screens with known data
- Edge cases like contributors with no works or missing metadata
- Integration points between screens and external services
- Error conditions and fallback behaviors

**Property-Based Tests:**
- Universal properties across all contributor types and works
- Comprehensive input coverage through randomized contributor data
- Minimum 100 iterations per property test
- Each test tagged with format: **Feature: contributor-details, Property {number}: {property_text}**

**Testing Framework:** Uses Flutter's built-in testing framework with mockito for API mocking and property-based testing via the `test` package's property testing capabilities.

The testing strategy ensures both specific functionality works correctly and universal properties hold across all possible inputs and contributor types.
