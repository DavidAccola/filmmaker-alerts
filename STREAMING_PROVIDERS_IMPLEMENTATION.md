# Streaming Providers Implementation Guide

## Overview

This document describes the modern, beautiful implementation of streaming provider information using TMDB's native watch/providers API endpoints. The implementation replaces the previous JustWatch-only approach with a more reliable, official data source.

## Architecture

### Key Components

#### 1. **StreamingService** (`lib/data/services/streaming_service.dart`)
- **Purpose**: Fetches streaming provider data from TMDB's native watch/providers endpoints
- **Key Methods**:
  - `getMovieStreamingOptions(tmdbId, regionCode)` - Fetches movie streaming options
  - `getTvStreamingOptions(tmdbId, regionCode)` - Fetches TV show streaming options
  - `getAvailableRegions()` - Gets list of supported regions/countries
  - `getCachedProviderLogo(providerId)` - Retrieves cached provider logos
  - `clearLogoCache()` - Clears the logo cache

**Features**:
- Uses TMDB's official `/movie/{id}/watch/providers` and `/tv/{id}/watch/providers` endpoints
- Parses provider data organized by type (subscription, free, rent, buy)
- Graceful fallback to US region if requested region unavailable
- Built-in logo caching for performance
- Comprehensive error handling with debug logging

#### 2. **TmdbService Enhancements** (`lib/data/services/tmdb_service.dart`)
Added three new methods:
- `getMovieWatchProviders(id)` - Calls `/movie/{id}/watch/providers`
- `getTvWatchProviders(id)` - Calls `/tv/{id}/watch/providers`
- `getWatchProviderRegions()` - Calls `/watch/providers/regions`

#### 3. **WorkLogic Updates** (`lib/logic/work_logic.dart`)
- Updated `fetchAndCacheMovieDetail()` to use `StreamingService` instead of `JustWatchService`
- Updated `fetchAndCacheTvShowDetail()` to use `StreamingService` instead of `JustWatchService`
- Changed parameter from `countryCode` to `regionCode` for clarity
- Maintains parallel fetching for efficiency (details, credits, streaming options)

#### 4. **Enhanced StreamingOptionsWidget** (`lib/ui/common/streaming_options_widget.dart`)
**Modern UI Features**:
- Smooth expand/collapse animation with `SizeTransition`
- Gradient header with primary/secondary colors
- Icon-based type indicators (subscriptions, free, rent, buy)
- Beautiful provider cards with shadows and hover effects
- Responsive layout with proper spacing
- TMDB attribution instead of JustWatch
- Improved visual hierarchy and typography

**UX Improvements**:
- Animated rotation of expand/collapse icon
- Smooth height transitions when expanding
- Better visual feedback on interactions
- Cleaner, more modern design language
- Proper Material Design principles

### Data Flow

```
Detail Screen (Movie/TV)
    ↓
Provider checks cache
    ↓
If not cached/stale:
    ↓
WorkLogic.fetchAndCacheMovieDetail/TvShowDetail()
    ↓
Parallel Future.wait():
  - TmdbService.getMovieDetails/getTvDetails()
  - TmdbService.getMovieCredits/getTvCredits()
  - StreamingService.getMovieStreamingOptions/getTvStreamingOptions()
    ↓
StreamingService parses TMDB watch/providers response
    ↓
Returns List<StreamingOption> grouped by type
    ↓
Cache via MovieDetailRepository/TvDetailRepository
    ↓
UI displays via StreamingOptionsWidget
```

## TMDB Watch Providers API Response Format

The TMDB API returns data in this structure:

```json
{
  "results": {
    "US": {
      "link": "https://www.themoviedb.org/movie/550/watch",
      "flatrate": [
        {
          "logo_path": "/path/to/logo.png",
          "provider_id": 8,
          "provider_name": "Netflix",
          "display_priority": 0
        }
      ],
      "rent": [...],
      "buy": [...],
      "free": [...]
    },
    "GB": { ... },
    "CA": { ... }
  }
}
```

**Provider Types**:
- `flatrate` → `StreamingType.subscription`
- `free` → `StreamingType.free`
- `rent` → `StreamingType.rent`
- `buy` → `StreamingType.buy`

## Key Improvements Over Previous Implementation

### 1. **Official Data Source**
- ✅ Uses TMDB's native endpoints (official, reliable)
- ❌ Previous: JustWatch API (third-party, less reliable)

### 2. **Better Error Handling**
- ✅ Graceful fallback to US region if requested region unavailable
- ✅ Comprehensive try-catch with debug logging
- ❌ Previous: Limited error recovery

### 3. **Performance**
- ✅ Logo caching reduces repeated downloads
- ✅ Parallel fetching of details, credits, and streaming options
- ✅ Efficient parsing with early returns

### 4. **UI/UX**
- ✅ Smooth animations and transitions
- ✅ Modern Material Design with gradients
- ✅ Better visual hierarchy and typography
- ✅ Responsive layout
- ❌ Previous: Static, less polished UI

### 5. **Maintainability**
- ✅ Clear separation of concerns (Service → Logic → UI)
- ✅ Well-documented code with comprehensive comments
- ✅ Consistent naming conventions
- ✅ Easy to extend for future features

## Usage Examples

### Fetching Movie Streaming Options

```dart
final streamingService = ref.watch(streamingServiceProvider);
final options = await streamingService.getMovieStreamingOptions(
  tmdbId: 550,
  regionCode: 'US',
);
```

### Fetching TV Show Streaming Options

```dart
final options = await streamingService.getTvStreamingOptions(
  tmdbId: 1399,
  regionCode: 'GB',
);
```

### Getting Available Regions

```dart
final regions = await streamingService.getAvailableRegions();
// Returns: {'US': 'United States', 'GB': 'United Kingdom', ...}
```

## Integration Points

### Detail Screens
- **MovieDetailScreen**: Displays streaming options after synopsis
- **TvShowDetailScreen**: Displays streaming options after synopsis
- **TvEpisodeDetailScreen**: Can be extended to show episode-level streaming (future enhancement)

### Providers
- `streamingServiceProvider`: Provides StreamingService instance
- `workLogicProvider`: Updated to use StreamingService

## Future Enhancements

1. **User Region Preferences**
   - Store user's preferred region in preferences
   - Auto-fetch streaming options for user's region
   - Allow region switching in settings

2. **Episode-Level Streaming**
   - Extend TvEpisodeDetail to include streaming options
   - Fetch episode-specific providers

3. **Deep Linking**
   - Implement URL launching to streaming services
   - Direct links to watch on specific platforms

4. **Notifications**
   - Notify users when content becomes available on their preferred services
   - Track price changes for rental/purchase options

5. **Search Filtering**
   - Filter search results by available streaming services
   - "Where to watch" search feature

## Testing

### Unit Tests
The existing `justwatch_service_test.dart` tests the data model. New tests should cover:
- StreamingService parsing logic
- Region fallback behavior
- Error handling scenarios
- Logo caching functionality

### Integration Tests
- Full flow from detail screen to streaming options display
- Region switching and cache invalidation
- Error recovery and graceful degradation

## Troubleshooting

### No Streaming Options Displayed
1. Check if TMDB has data for the title in the requested region
2. Verify region code is valid (ISO 3166-1 format)
3. Check debug logs for parsing errors
4. Ensure TMDB API key is valid and has watch/providers access

### Logo Images Not Loading
1. Verify TMDB image URLs are accessible
2. Check CachedNetworkImage configuration
3. Ensure logo paths are correctly formatted

### Performance Issues
1. Check logo cache size (clear if needed)
2. Verify parallel fetching is working
3. Monitor API rate limiting

## References

- [TMDB Movie Watch Providers](https://developer.themoviedb.org/reference/movie-watch-providers)
- [TMDB TV Series Watch Providers](https://developer.themoviedb.org/reference/tv-series-watch-providers)
- [TMDB Watch Provider Regions](https://developer.themoviedb.org/reference/watch-providers-available-regions)
- [TMDB API Documentation](https://developer.themoviedb.org/docs)
