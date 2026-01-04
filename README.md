# Filmmaker Alerts

An app that sends notifications when new movies and TV shows are released. Special emphasis on following creators: directors, producers, screenwriters, production companies. But you can also follow works from specific actors, movies/shows, or collections.

## Features

- **Follow Filmmakers**: Get notified when directors, producers, writers, and other crew members have new releases
- **Track Companies**: Monitor production companies for their latest projects  
- **Movie & Collection Tracking**: Follow specific movies or entire film collections
- **Get Notified for Specific Release Types**: Get notified specifically for theatrical releases, streaming debuts, TV airings, or physical releases
- **Smart Notifications**: On Windows, persistent Windows notifications with movie posters and detailed release information
- **Notification History**: Review all past notifications with links to TMDB and IMDb
- **Flexible Scheduling**: Configure when to check for new releases

## Screenshots

*Coming soon*

## Installation

### Prerequisites

- Windows 10/11 (primary platform)
- Flutter SDK (for development)
- TMDB API key (free registration required)

### Setup

1. Clone this repository
2. Get a free API key from [The Movie Database (TMDB)](https://www.themoviedb.org/settings/api)
3. Create a `.env` file in the project root:
   ```
   TMDB_API_KEY=your_api_key_here
   ```
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Run the application:
   ```bash
   flutter run -d windows
   ```

## Usage

1. **Add Contributors**: Search for and follow directors, actors, writers, producers, and other film industry professionals
2. **Set Preferences**: Choose which types of releases to be notified about (theatrical, streaming, TV, etc.)
3. **Receive Notifications**: Get persistent Windows notifications with movie posters when new content is available

## Data Sources & Attribution

This application uses [The Movie Database (TMDB) API](https://www.themoviedb.org/) for all movie and TV show information. 

This product uses the TMDB API but is not endorsed or certified by TMDB. All movie data, images, and metadata are provided by TMDB under their terms of service.

### IMDb Integration

- IMDb links are provided where available through TMDB's external ID mappings
- IMDb is a trademark of Amazon.com, Inc. or its affiliates

## Legal

This is an independent, non-commercial application created for personal use. It is not affiliated with, endorsed by, or connected to:
- The Movie Database (TMDB)
- IMDb / Amazon
- Any film studios or production companies

All movie data and images are the property of their respective owners and are used under fair use for informational purposes.

## Development

### Built With
- [Flutter](https://flutter.dev/) - Cross-platform UI framework
- [Riverpod](https://riverpod.dev/) - State management
- [Hive](https://hivedb.dev/) - Local database

### Contributing

This is currently a personal project, but suggestions and bug reports are welcome through GitHub issues.

## Disclaimer

This application is provided "as is" without warranty of any kind. The accuracy of movie release dates and information depends on TMDB data quality. Users should verify important release information through official sources.