/// Hardcoded franchise definitions backed by TMDB keyword IDs.
///
/// These are the only franchises surfaced in search — no general keyword
/// search is supported. Each franchise maps to a TMDB keyword ID and
/// declares whether it has movie content, TV content, or both.
///
/// IDs verified against TMDB on 2026-08-29.
class FranchiseDefinition {
  final int keywordId;
  final String displayName;

  /// Whether this franchise has movie content and should appear in the Movie tab.
  final bool showInMovie;

  /// Whether this franchise has TV content and should appear in the TV tab.
  final bool showInTv;

  const FranchiseDefinition({
    required this.keywordId,
    required this.displayName,
    required this.showInMovie,
    required this.showInTv,
  });

  /// The URL slug used by TMDB for this keyword.
  String get tmdbMovieUrl => 'https://www.themoviedb.org/keyword/$keywordId/movie';
  String get tmdbTvUrl => 'https://www.themoviedb.org/keyword/$keywordId/tv';
  String get tmdbUrl => 'https://www.themoviedb.org/keyword/$keywordId';
}

/// The hardcoded list of franchises supported by this app.
///
/// Franchises are injected into Movie and/or TV search results when the
/// user's query matches the franchise name. Following a franchise notifies
/// for both movie and TV releases regardless of which tab it was found in.
const List<FranchiseDefinition> kSupportedFranchises = [
  FranchiseDefinition(
    keywordId: 180547,
    displayName: 'Marvel Cinematic Universe (MCU)',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 312528,
    displayName: 'DC Universe (DCU)',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 329136,
    displayName: 'DC Animated Universe (DCAU)',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 229266,
    displayName: 'DC Extended Universe (DCEU)',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 359527,
    displayName: 'DC Animated Movie Universe (DCAMU)',
    showInMovie: true,
    showInTv: false, // Movies only — no TV content tagged with this keyword
  ),
  FranchiseDefinition(
    keywordId: 197065,
    displayName: 'Claymation',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 257384,
    displayName: 'Godzilla',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 353597,
    displayName: 'Avengers',
    showInMovie: true,
    showInTv: false, // No TV shows tagged
  ),
  FranchiseDefinition(
    keywordId: 306278,
    displayName: 'James Bond',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 353970,
    displayName: 'Dune',
    showInMovie: true,
    showInTv: false, // Movies only
  ),
  FranchiseDefinition(
    keywordId: 233512,
    displayName: 'Blade Runner',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 330486,
    displayName: 'Avatar',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 327763,
    displayName: 'Star Trek',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 358400,
    displayName: 'Alien',
    showInMovie: true,
    showInTv: true,
  ),
  FranchiseDefinition(
    keywordId: 185199,
    displayName: 'Matrix',
    showInMovie: true,
    showInTv: false, // Movies only
  ),
  FranchiseDefinition(
    keywordId: 288025,
    displayName: 'Ghostbusters',
    showInMovie: true,
    showInTv: true,
  ),
];

/// Look up a franchise definition by its TMDB keyword ID.
/// Returns null if the ID is not a supported franchise.
FranchiseDefinition? franchiseById(int keywordId) {
  try {
    return kSupportedFranchises.firstWhere((f) => f.keywordId == keywordId);
  } catch (_) {
    return null;
  }
}

/// Returns franchises that should appear in the Movie search tab.
List<FranchiseDefinition> get franchisesForMovieTab =>
    kSupportedFranchises.where((f) => f.showInMovie).toList();

/// Returns franchises that should appear in the TV search tab.
List<FranchiseDefinition> get franchisesForTvTab =>
    kSupportedFranchises.where((f) => f.showInTv).toList();
