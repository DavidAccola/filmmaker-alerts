# Requirements Document

## Introduction

The Contributor Details feature provides comprehensive information screens for followed people, companies, and collections. When users click on any followed contributor from the main screen, they can view detailed information including upcoming works, latest releases, biggest hits, streaming options, and related contributors.

## Glossary

- **Contributor**: A person, company, or collection that users can follow
- **Work**: A movie, TV show, or TV episode
- **Streaming_Provider**: A service that offers content for streaming (Netflix, Hulu, etc.)
- **JustWatch_API**: Third-party service providing streaming availability data
- **TMDB**: The Movie Database - primary data source
- **IMDB**: Internet Movie Database - secondary data source
- **Points_of_Interest**: Section showing other followed contributors involved in a work
- **Watchlist**: User's personal list of works they want to watch

## Requirements

### Requirement 1: Contributor Detail Screen Navigation

**User Story:** As a user, I want to click on any followed contributor to view their detailed information, so that I can explore their work comprehensively.

#### Acceptance Criteria

1. WHEN a user clicks on a followed person, company, or collection THEN the System SHALL navigate to the contributor detail screen
2. THE Detail_Screen SHALL display the contributor's name and profile image in the header
3. THE Detail_Screen SHALL show preference toggles for hiding popularity and ratings at the top
4. THE Detail_Screen SHALL organize content into three main sections: Upcoming, Latest Releases, and Biggest Hits

### Requirement 2: Upcoming Works Section

**User Story:** As a user, I want to see all upcoming works for a contributor ordered by release date, so that I can anticipate their future projects.

#### Acceptance Criteria

1. THE System SHALL display all future works in chronological order by release date
2. WHEN works have unknown release dates THEN the System SHALL display them after dated works
3. FOR ALL upcoming works THE System SHALL show title, poster, and release date
4. THE System SHALL allow users to add any upcoming work to their watchlist

### Requirement 3: Latest Releases Section

**User Story:** As a user, I want to see the contributor's recent works with detailed information, so that I can discover their latest projects.

#### Acceptance Criteria

1. THE System SHALL display the last 10 released works in reverse chronological order
2. FOR ALL latest releases THE System SHALL indicate theatrical versus streaming release
3. FOR ALL latest releases THE System SHALL display poster, popularity score, and TMDB rating
4. THE System SHALL provide a "See more on TMDB" link that opens the contributor's TMDB page
5. THE System SHALL allow users to add any latest release to their watchlist

### Requirement 4: Biggest Hits Section

**User Story:** As a user, I want to see the contributor's most successful works, so that I can explore their best-known projects.

#### Acceptance Criteria

1. THE System SHALL display top 10 works based on combination of highest rating and popularity
2. FOR ALL biggest hits THE System SHALL show title, poster, rating, and popularity
3. THE System SHALL allow users to add any biggest hit to their watchlist

### Requirement 5: Display Preferences

**User Story:** As a user, I want to control the visibility of popularity and rating information, so that I can customize my viewing experience.

#### Acceptance Criteria

1. THE System SHALL provide toggle controls at the top of the detail screen
2. WHEN "hide popularity" is enabled THEN the System SHALL hide popularity scores across all sections
3. WHEN "hide ratings" is enabled THEN the System SHALL hide TMDB ratings across all sections
4. THE System SHALL persist these preferences across all contributor detail screens

### Requirement 6: Work Interaction and External Links

**User Story:** As a user, I want to open works in external databases and see streaming options, so that I can get more information and watch content.

#### Acceptance Criteria

1. WHEN a user clicks on any work THEN the System SHALL open the work's TMDB page
2. THE System SHALL provide a button to open the work's IMDB page
3. THE System SHALL use the same TMDB/IMDB preference logic as the notifications system
4. THE System SHALL provide streaming options for each work via expandable section or separate screen
5. THE System SHALL call the JustWatch providers API for streaming availability
6. THE System SHALL display proper JustWatch attribution with branded link and logo

### Requirement 7: Points of Interest

**User Story:** As a user, I want to see other followed contributors involved in each work, so that I can discover connections between my followed people.

#### Acceptance Criteria

1. FOR ALL works THE System SHALL check for other followed contributors involved
2. WHEN other followed contributors exist THEN the System SHALL display a "Points of Interest" section
3. THE Points_of_Interest SHALL show the contributor name and their role in the work
4. WHEN no other followed contributors exist THEN the System SHALL hide the Points of Interest section

### Requirement 8: TV Show Specific Display

**User Story:** As a user viewing a TV show contributor, I want to see show-level and episode-level information, so that I can understand their specific involvement.

#### Acceptance Criteria

1. WHEN the contributor is a TV show creator THEN the System SHALL display the show and creator credit
2. WHEN the contributor is a TV director THEN the System SHALL show specific episodes under "Episodes Directed"
3. WHEN a user clicks on an episode THEN the System SHALL open that episode's TMDB page
4. THE System SHALL handle contributors who are both creators and directors appropriately

### Requirement 9: Movie Specific Display

**User Story:** As a user viewing a movie contributor, I want to see their role clearly displayed, so that I understand their involvement.

#### Acceptance Criteria

1. FOR ALL movie works THE System SHALL display the movie title and the contributor's role(s)
2. WHEN a contributor has multiple roles THEN the System SHALL display all roles clearly

### Requirement 10: Country Preference for Streaming

**User Story:** As a user, I want streaming options relevant to my location, so that I can find content available in my region.

#### Acceptance Criteria

1. THE System SHALL provide a country preference in global settings
2. THE System SHALL use the country preference for JustWatch API calls
3. THE System SHALL display streaming providers available in the selected country

### Requirement 11: External Credits Access

**User Story:** As a user, I want quick access to complete filmographies, so that I can explore beyond the curated selections.

#### Acceptance Criteria

1. THE System SHALL provide a "See all credits on TMDB" button at the bottom of the screen
2. THE System SHALL provide a "See all credits on IMDB" button at the bottom of the screen
3. THE System SHALL retrieve and store IMDB IDs during release checking for people
4. THE System SHALL open the appropriate external pages when buttons are clicked

### Requirement 12: Movie Detail Screen

**User Story:** As a user, I want to click on any movie to view its detailed information, so that I can explore cast, crew, streaming options, and related information.

#### Acceptance Criteria

1. WHEN a user clicks on any movie THEN the System SHALL navigate to the movie detail screen
2. THE Movie_Detail_Screen SHALL display movie title, poster, release date, runtime
3. THE Movie_Detail_Screen SHALL show TMDB rating, popularity, and user rating if available
4. THE Movie_Detail_Screen SHALL provide an expandable synopsis section to avoid spoilers
5. THE Movie_Detail_Screen SHALL display cast members with profile images and character names
6. THE Movie_Detail_Screen SHALL display key crew members (director, writer, producer) with their roles
7. THE Movie_Detail_Screen SHALL show followed contributors first in both cast and crew sections
8. THE Movie_Detail_Screen SHALL highlight followed contributors with special styling
9. THE Movie_Detail_Screen SHALL provide streaming options via JustWatch integration
10. THE Movie_Detail_Screen SHALL allow adding the movie to watchlist
11. THE Movie_Detail_Screen SHALL provide buttons to open movie on TMDB and IMDB
12. THE Movie_Detail_Screen SHALL respect the same display preferences for hiding popularity/ratings

### Requirement 13: API Efficiency Integration

**User Story:** As a system administrator, I want contributor detail data to be gathered efficiently, so that the app performs well and minimizes API calls.

#### Acceptance Criteria

1. THE System SHALL leverage existing API calls made during release checking
2. THE System SHALL cache contributor detail data appropriately
3. THE System SHALL minimize redundant API calls when displaying contributor details
4. THE System SHALL gather IMDB IDs for people during the release checking process