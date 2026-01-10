# Implementation Plan: Contributor Details

## Overview

This implementation creates comprehensive detail screens for contributors (people, companies, collections) and movies, with streaming integration, watchlist functionality, and cross-contributor connections. The approach prioritizes incremental development with early validation through testing.

## Tasks

- [x] 1. Set up core data models and interfaces
  - Create ContributorDetail, MovieDetail, Work, and StreamingOption models
  - Define repository interfaces for data access
  - Set up basic navigation structure between screens
  - _Requirements: 1.1, 12.1_

- [x] 1.1 Write property test for navigation consistency
  - **Property 1: Navigation Consistency**
  - **Validates: Requirements 1.1, 12.1**

- [x] 2. Implement ContributorDetailScreen UI structure
  - Create basic screen layout with header, preference toggles, and three main sections
  - Implement contributor info display (name, profile image)
  - Add placeholder sections for Upcoming, Latest Releases, and Biggest Hits
  - _Requirements: 1.2, 1.3, 1.4_

- [x] 2.1 Write property test for required UI elements
  - **Property 14: Required UI Elements**
  - **Validates: Requirements 1.2, 1.3, 1.4, 5.1, 11.1, 11.2**

- [x] 3. Implement work display and sorting logic
  - Create Work widget for displaying movie/TV show information
  - Implement chronological sorting for upcoming works (unknown dates last)
  - Implement reverse chronological sorting for latest releases (limit 10 - can press to show 10 more, etc.)
  - Implement ranking algorithm for biggest hits (rating + popularity combination)
  - _Requirements: 2.1, 2.2, 3.1, 4.1_

- [x]* 3.1 Write property test for chronological ordering
  - **Property 2: Chronological Ordering**
  - **Validates: Requirements 2.1, 2.2**

- [ ]* 3.2 Write property test for latest releases ordering
  - **Property 3: Latest Releases Ordering**
  - **Validates: Requirements 3.1**

- [ ]* 3.3 Write property test for biggest hits ranking
  - **Property 4: Biggest Hits Ranking**
  - **Validates: Requirements 4.1**

- [x] 4. Implement display preferences system
  - Create preference toggles for hiding popularity and ratings
  - Implement preference persistence across screens
  - Apply preferences consistently across all sections and screen types
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ]* 4.1 Write property test for display preference consistency
  - **Property 6: Display Preference Consistency**
  - **Validates: Requirements 5.2, 5.3, 12.12**

- [ ]* 4.2 Write property test for preference persistence
  - **Property 7: Preference Persistence**
  - **Validates: Requirements 5.4**

- [ ]* 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 6. Implement watchlist integration
  - Add watchlist buttons to all work displays
  - Implement add-to-watchlist functionality for all work types
  - Handle watchlist state updates and UI feedback
  - _Requirements: 2.4, 3.5, 4.3, 12.10_

- [ ]* 6.1 Write property test for watchlist integration

  - **Property 5: Watchlist Integration**
  - **Validates: Requirements 2.4, 3.5, 4.3, 12.10**

- [x] 7. Implement external navigation system
  - Create external link buttons for TMDB and IMDB
  - Implement navigation logic using existing notification system preferences
  - Handle IMDB ID retrieval and storage during release checking
  - _Requirements: 6.1, 6.2, 6.3, 11.3, 11.4, 13.4_

- [ ]* 7.1 Write property test for external navigation
  - **Property 8: External Navigation**
  - **Validates: Requirements 6.1, 6.2, 6.3, 8.3, 11.4, 12.11**

- [ ]* 7.2 Write property test for IMDB ID collection
  - **Property 16: IMDB ID Collection**
  - **Validates: Requirements 11.3, 13.4**

- [x] 8. Implement JustWatch streaming integration
  - Create StreamingOptionsWidget with expandable/modal presentation
  - Integrate JustWatch API with country preference support
  - Add proper JustWatch attribution (branded link and logo)
  - Implement country preference in global settings
  - _Requirements: 6.4, 6.5, 6.6, 10.1, 10.2, 10.3_

- [ ]* 8.1 Write property test for JustWatch integration
  - **Property 9: JustWatch Integration**
  - **Validates: Requirements 6.5, 6.6, 10.2, 10.3, 12.9**

- [x] 9. Implement Points of Interest system
  - Create PointsOfInterestWidget for showing followed contributor connections
  - Implement logic to scan cast/crew for other followed contributors
  - Show/hide Points of Interest section based on data availability
  - Display contributor names with their specific roles
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ]* 9.1 Write property test for Points of Interest detection
  - **Property 10: Points of Interest Detection**
  - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

- [x] 10. Implement TV show specific handling
  - Add logic for TV show creator credits display
  - Implement "Episodes Directed" section for TV directors
  - Handle contributors with both creator and director roles
  - Add episode navigation to TMDB
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ]* 10.1 Write property test for TV show role handling
  - **Property 11: TV Show Role Handling**
  - **Validates: Requirements 8.1, 8.2, 8.4**

- [ ]* 11. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Implement MovieDetailScreen
  - Create movie detail screen layout with metadata header
  - Implement expandable synopsis section to avoid spoilers
  - Add cast and crew sections with profile images and roles
  - Prioritize followed contributors in cast/crew lists with special highlighting
  - _Requirements: 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8_

- [ ]* 12.1 Write property test for movie cast/crew prioritization
  - **Property 13: Movie Cast/Crew Prioritization**
  - **Validates: Requirements 12.7, 12.8**

- [x] 13. Implement multiple role display logic
  - Handle contributors with multiple roles in movies
  - Handle contributors with multiple roles in TV shows
  - Ensure all roles are displayed clearly and completely
  - _Requirements: 8.4, 9.1, 9.2_

- [x]* 13.1 Write property test for multiple role display
  - **Property 12: Multiple Role Display**
  - **Validates: Requirements 8.4, 9.2**

- [x] 14. Implement data caching and API efficiency
  - Create ContributorDetailRepository with caching logic
  - Create MovieDetailRepository with caching logic
  - Implement efficient data retrieval leveraging existing API calls
  - Optimize API call patterns to minimize redundancy
  - _Requirements: 13.1, 13.2, 13.3_

- [ ]* 14.1 Write property test for data caching consistency
  - **Property 15: Data Caching Consistency**
  - **Validates: Requirements 13.2**

- [x] 15. Integration and wiring
  - Connect all screens with proper navigation flow
  - Wire up all repositories with dependency injection
  - Integrate with existing notification system preferences
  - _Requirements: All requirements integration_

- [ ]* 15.1 Write integration tests
  - Test end-to-end navigation flows
  - Test cross-screen preference consistency
  - Test external service integrations

- [ ] 16. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests ensure all components work together seamlessly